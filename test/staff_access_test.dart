import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/models/staff_access.dart';

void main() {
  AccountRole role({
    bool admin = false,
    Map<String, dynamic>? account = const {
      'employeeId': 'employee-a',
      'active': true,
    },
    Map<String, dynamic>? employee = const {
      'name': 'A',
      'salonId': 'salon_01',
      'isActive': true,
    },
    String? linkedUid = 'staff-a',
  }) => StaffAccess.resolve(
    isAdmin: admin,
    uid: 'staff-a',
    account: account,
    employee: employee,
    linkedUid: linkedUid,
  );

  test('role routing keeps admin, customer, active staff distinct', () {
    expect(role(admin: true), AccountRole.admin);
    expect(role(account: null), AccountRole.customer);
    expect(role(), AccountRole.staff);
  });
  test(
    'inactive accounts, missing profiles and inconsistent links fail closed',
    () {
      expect(
        role(account: {'employeeId': 'employee-a', 'active': false}),
        AccountRole.blocked,
      );
      expect(role(employee: null), AccountRole.blocked);
      expect(
        role(employee: {'salonId': 'salon_01', 'isActive': false}),
        AccountRole.blocked,
      );
      expect(
        role(employee: {'salonId': 'salon_01', 'isActive': 'true'}),
        AccountRole.blocked,
      );
      expect(role(employee: {'salonId': 'unknown'}), AccountRole.blocked);
      expect(role(linkedUid: 'different'), AccountRole.blocked);
      expect(role(linkedUid: null), AccountRole.blocked);
    },
  );
  test('existing active legacy profile without isActive remains supported', () {
    expect(role(employee: {'salonId': 'salon_01'}), AccountRole.staff);
  });
}
