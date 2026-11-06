import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'staff_account_service.dart';

class SchedulingTimeoutException implements Exception {
  const SchedulingTimeoutException(this.requestId, this.stage);
  final String requestId;
  final String stage;
  @override
  String toString() =>
      'Chưa xác nhận được kết quả. Ca có thể đã được lưu. '
      'Hãy thử lại cùng yêu cầu ($requestId).';
}

class SchedulingRejectedException implements Exception {
  const SchedulingRejectedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Keeps the exact payload/id when a response is lost or times out.
class SchedulingMutation {
  SchedulingMutation(this.name, Map<String, dynamic> data)
    : payload = jsonEncode({
        ...data,
        'requestId': SchedulingService.requestId(),
      });
  final String name;
  final String payload;
  Map<String, dynamic> get data => jsonDecode(payload) as Map<String, dynamic>;
}

class SchedulingService {
  SchedulingService({
    http.Client Function()? clientFactory,
    Future<String?> Function()? tokenProvider,
    this.requestTimeout = const Duration(seconds: 45),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _tokenProvider = tokenProvider ?? _currentToken,
       _emulatorEnabled = StaffAccountService.emulatorEnabled;
  @visibleForTesting
  SchedulingService.testing({
    required http.Client Function() clientFactory,
    required Future<String?> Function() tokenProvider,
    this.requestTimeout = const Duration(seconds: 45),
  }) : _clientFactory = clientFactory,
       _tokenProvider = tokenProvider,
       _emulatorEnabled = true;
  final bool _emulatorEnabled;
  final http.Client Function() _clientFactory;
  final Future<String?> Function() _tokenProvider;
  final Duration requestTimeout;
  static Future<String?> _currentToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();
  // Keep the bound below 2^32 to avoid overflow in Web random generation.
  static String requestId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!_emulatorEnabled) {
      throw StateError('Bản xem trước lịch làm chỉ chạy với Emulator.');
    }
    final client = _clientFactory();
    final watch = Stopwatch()..start();
    final requestId = data['requestId'] ?? 'read';
    var stage = 'auth';
    void trace(String event) {
      if (kDebugMode) {
        debugPrint(
          '[scheduling] $name $requestId $event ${watch.elapsedMilliseconds}ms',
        );
      }
    }

    Future<Map<String, dynamic>> send() async {
      trace('auth.start');
      final token = await _tokenProvider();
      // A timeout during token retrieval must never send a later POST.
      if (watch.elapsed >= requestTimeout) {
        throw SchedulingTimeoutException('$requestId', stage);
      }
      if (token == null) {
        throw const SchedulingRejectedException('Vui lòng đăng nhập.');
      }
      stage = 'http';
      trace('http.start');
      const port = int.fromEnvironment(
        'FUNCTIONS_EMULATOR_PORT',
        defaultValue: 5001,
      );
      final response = await client.post(
        Uri.parse(
          'http://${StaffAccountService.emulatorHost}:$port/demo-men-hair-booking/asia-southeast1/$name',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': data}),
      );
      trace('http.response ${response.statusCode}');
      final value = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || value['error'] != null) {
        final error = value['error'];
        final message = error is Map
            ? '${error['message']}'
            : 'Không thể cập nhật lịch.';
        if ([400, 401, 403, 404, 409].contains(response.statusCode)) {
          throw SchedulingRejectedException(message);
        }
        throw StateError(message);
      }
      return Map<String, dynamic>.from(value['result'] as Map);
    }

    try {
      return await send().timeout(
        requestTimeout,
        onTimeout: () {
          trace('timeout.$stage');
          throw SchedulingTimeoutException('$requestId', stage);
        },
      );
    } finally {
      // Future.timeout alone does not cancel fetch/XHR, even during preflight.
      client.close();
      trace('http.closed');
    }
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static List<String> recurringDates(DateTime month, Set<int> weekdays) => [
    for (
      var day = 1;
      day <= DateTime(month.year, month.month + 1, 0).day;
      day++
    )
      if (weekdays.contains(DateTime(month.year, month.month, day).weekday))
        dateKey(DateTime(month.year, month.month, day)),
  ];
}
