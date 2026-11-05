enum AccountRole { customer, admin, staff, blocked }

class StaffAccess {
  const StaffAccess({
    required this.employeeId,
    required this.salonId,
    required this.name,
    required this.active,
  });

  final String employeeId;
  final String salonId;
  final String name;
  final bool active;

  static AccountRole resolve({
    required bool isAdmin,
    required String uid,
    required Map<String, dynamic>? account,
    required Map<String, dynamic>? employee,
    required String? linkedUid,
  }) {
    if (isAdmin) return AccountRole.admin;
    if (account == null) return AccountRole.customer;
    final employeeId = account['employeeId'];
    if (account['active'] != true ||
        employeeId is! String ||
        employeeId.isEmpty ||
        employeeId.contains('/') ||
        linkedUid != uid ||
        employee == null ||
        (employee.containsKey('isActive') && employee['isActive'] != true) ||
        !const [
          'salon_01',
          'salon_02',
          'salon_03',
        ].contains(employee['salonId'])) {
      return AccountRole.blocked;
    }
    return AccountRole.staff;
  }
}
