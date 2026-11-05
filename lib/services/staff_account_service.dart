import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Phase-one mutations are intentionally restricted to local emulators.
/// No Firebase Auth account is created by these operations.
class StaffAccountService {
  static const emulatorEnabled = bool.fromEnvironment('FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  Future<void> link(String uid, String employeeId) =>
      _call('linkStaffAccount', {'uid': uid.trim(), 'employeeId': employeeId});

  Future<void> setActive(String uid, bool active) =>
      _call('setStaffAccountActive', {'uid': uid, 'active': active});

  Future<void> _call(String function, Map<String, dynamic> data) async {
    if (!emulatorEnabled) {
      throw StateError('Giai đoạn 1 chỉ cho phép liên kết trên Emulator.');
    }
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Vui lòng đăng nhập.');
    final response = await http
        .post(
          Uri.parse(
            'http://$emulatorHost:5001/demo-men-hair-booking/asia-southeast1/$function',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || result.containsKey('error')) {
      final error = result['error'];
      throw StateError(
        error is Map ? '${error['message']}' : 'Không thể cập nhật liên kết.',
      );
    }
  }
}
