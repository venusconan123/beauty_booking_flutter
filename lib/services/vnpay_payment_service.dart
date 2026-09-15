import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class VnpayPaymentException implements Exception {
  final String message;

  const VnpayPaymentException(this.message);

  @override
  String toString() => message;
}

class VnpayPaymentService {
  static const String _defaultApiBaseUrl =
      'https://men-hair-booking-vnpay.venusconan23.workers.dev';

  final String apiBaseUrl;
  final http.Client _client;

  VnpayPaymentService({
    String? apiBaseUrl,
    http.Client? client,
  })  : apiBaseUrl = apiBaseUrl ??
            const String.fromEnvironment(
              'VNPAY_API_BASE_URL',
              defaultValue: _defaultApiBaseUrl,
            ),
        _client = client ?? http.Client();

  Future<Uri> createPaymentUrl({
    required String bookingId,
    required User user,
  }) async {
    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const VnpayPaymentException(
        'Không thể xác thực tài khoản. Vui lòng đăng nhập lại.',
      );
    }

    final http.Response response = await _client.post(
      Uri.parse('$apiBaseUrl/api/payments/create'),
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'bookingId': bookingId}),
    );

    Map<String, dynamic> result = <String, dynamic>{};
    try {
      result = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const VnpayPaymentException(
        'Máy chủ thanh toán trả về dữ liệu không hợp lệ.',
      );
    }

    if (response.statusCode != 200) {
      throw VnpayPaymentException(
        result['message']?.toString() ??
            'Không thể tạo giao dịch VNPAY.',
      );
    }

    final Uri? paymentUri = Uri.tryParse(
      result['paymentUrl']?.toString() ?? '',
    );
    if (paymentUri == null ||
        paymentUri.scheme != 'https' ||
        paymentUri.host != 'sandbox.vnpayment.vn') {
      throw const VnpayPaymentException(
        'Không nhận được đường dẫn thanh toán VNPAY.',
      );
    }

    return paymentUri;
  }
}
