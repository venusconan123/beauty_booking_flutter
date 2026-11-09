import 'scheduling_service.dart';

/// Links existing Auth identities only; transport follows the initialized app.
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
    await SchedulingService().call(function, data);
  }
}
