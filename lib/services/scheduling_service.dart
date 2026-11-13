import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
       _emulatorEnabled = StaffAccountService.emulatorEnabled,
       _projectId = null,
       _apiBase = const String.fromEnvironment(
         'SCHEDULING_API_BASE',
         defaultValue:
             'https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling',
       );
  @visibleForTesting
  SchedulingService.testing({
    required http.Client Function() clientFactory,
    required Future<String?> Function() tokenProvider,
    this.requestTimeout = const Duration(seconds: 45),
    bool emulatorEnabled = true,
    String projectId = 'demo-men-hair-booking',
    String apiBase =
        'https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling',
  }) : _clientFactory = clientFactory,
       _tokenProvider = tokenProvider,
       _emulatorEnabled = emulatorEnabled,
       _projectId = projectId,
       _apiBase = apiBase;
  final bool _emulatorEnabled;
  final String? _projectId;
  final String _apiBase;
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
    if (!const {
      'linkStaffAccount',
      'createStaffAccount',
      'setStaffAccountActive',
      'saveRoster',
      'saveShifts',
      'cancelShift',
      'swapShifts',
      'createBooking',
      'updateBookingServices',
      'changeBookingStatus',
      'recordBookingPayment',
      'getAvailability',
      'listBookableStaff',
      'getBarberRatings',
      'askSalonAssistant',
      'releaseStaleSlots',
    }.contains(name)) {
      throw ArgumentError.value(name, 'name', 'Callable không hợp lệ.');
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
      final project = _projectId ?? Firebase.app().options.projectId;
      if (!_emulatorEnabled &&
          (project.startsWith('demo-') ||
              !RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(project))) {
        throw StateError('Firebase project không hợp lệ cho HTTPS production.');
      }
      final base = Uri.parse(_apiBase);
      if (!_emulatorEnabled &&
          (base.scheme != 'https' ||
              base.host.isEmpty ||
              base.userInfo.isNotEmpty ||
              base.hasQuery ||
              base.hasFragment)) {
        throw StateError('Backend online phải sử dụng địa chỉ HTTPS hợp lệ.');
      }
      final endpoint = _emulatorEnabled
          ? Uri.parse(
              'http://${StaffAccountService.emulatorHost}:$port/demo-men-hair-booking/asia-southeast1/$name',
            )
          : Uri.parse('${_apiBase.replaceFirst(RegExp(r'/+$'), '')}/$name');
      final response = await client.post(
        endpoint,
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
        if ([400, 401, 403, 404, 409, 412].contains(response.statusCode)) {
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
    } on http.ClientException {
      throw StateError(
        'Chưa kết nối được máy chủ xử lý. Kiểm tra Internet và thử lại cùng yêu cầu.',
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
