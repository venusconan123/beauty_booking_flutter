import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/screens/account_role_gate.dart';
import 'package:men_hair_booking/screens/staff_portal_screen.dart';
import 'package:men_hair_booking/models/staff_access.dart';

void main() {
  testWidgets(
    'staff starts with assigned appointments and can visit all four tabs',
    (tester) async {
      var signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StaffWorkspace(
            access: const StaffAccess(
              employeeId: 'employee-a',
              salonId: 'salon_01',
              name: 'Nhân viên A',
              active: true,
            ),
            email: 'staff@example.test',
            onSignOut: () => signedOut = true,
            bookings: const Text('Lịch được giao cho A'),
          ),
        ),
      );
      expect(find.text('Lịch được giao cho A'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      await tester.tap(find.text('Lịch làm'));
      await tester.pumpAndSettle();
      expect(
        find.text('Lịch làm sẽ có trong phiên bản tiếp theo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Thống kê'));
      await tester.pumpAndSettle();
      expect(
        find.text('Thống kê sẽ có trong phiên bản tiếp theo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('staff@example.test'), findsOneWidget);
      expect(find.text('employee-a'), findsOneWidget);
      await tester.tap(find.text('Đăng xuất'));
      expect(signedOut, isTrue);
    },
  );
  testWidgets('assigned booking renders service names and Vietnam time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffBookingList(
            bookings: [
              {
                'userName': 'Khách A',
                'appointmentAt': Timestamp.fromDate(
                  DateTime.utc(2026, 11, 5, 2),
                ),
                'status': 'confirmed',
                'salonName': 'Chi nhánh 1',
                'services': [
                  {'name': 'Cắt tóc'},
                  {'name': 'Gội đầu'},
                ],
              },
            ],
          ),
        ),
      ),
    );
    expect(find.text('Khách A'), findsOneWidget);
    expect(find.text('05/11/2026 09:00 (giờ Việt Nam)'), findsOneWidget);
    expect(find.text('Cắt tóc, Gội đầu'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);
    expect(find.text('Bắt đầu phục vụ'), findsNothing);
  });
  testWidgets('blocked access offers logout and no booking controls', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StaffAccessBlocked(
          message: 'Tài khoản đã ngừng hoạt động',
          onSignOut: () => signedOut = true,
        ),
      ),
    );
    expect(find.text('Tài khoản đã ngừng hoạt động'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất'));
    expect(signedOut, isTrue);
    expect(find.byType(StaffBookingList), findsNothing);
  });
}
