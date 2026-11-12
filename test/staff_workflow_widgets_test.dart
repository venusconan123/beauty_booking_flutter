import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/screens/staff_bookings_screen.dart';
import 'package:men_hair_booking/screens/staff_statistics_screen.dart';
import 'package:men_hair_booking/services/scheduling_service.dart';

Map<String, dynamic> booking() => {
  'id': 'assigned-a',
  'userName': 'Khách kiểm tra',
  'userPhone': '0901234567',
  'status': 'confirmed',
  'salonName': 'Chi nhánh 1',
  'totalPrice': 80000,
  'appointmentAt': Timestamp.fromDate(DateTime.utc(2026, 11, 10, 2)),
  'payment': {'choice': 'pay_later', 'status': 'unpaid'},
  'services': [
    {'name': 'Cắt tóc', 'price': 80000},
  ],
};
void main() {
  testWidgets(
    'returning to appointments can retry an uncertain earlier action',
    (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: [
                {...booking(), 'status': 'in_service'},
              ],
              pendingAction: {
                'bookingId': 'assigned-a',
                'status': 'in_service',
              },
              onChangeStatus: (row, next) async =>
                  seen.add('${row['id']}:$next'),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Thử lại thao tác'));
      await tester.tap(find.text('Thử lại thao tác'));
      await tester.pumpAndSettle();
      expect(seen, ['assigned-a:in_service']);
      expect(find.text('Thử lại thao tác'), findsNothing);
    },
  );
  testWidgets(
    'staff confirms start then completes; real-time updates replace actions',
    (tester) async {
      final row = booking();
      final changes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => StaffBookingList(
                bookings: [row],
                now: DateTime.utc(2026, 11, 10, 3),
                onChangeStatus: (b, next) async {
                  changes.add(next);
                  update(() => row['status'] = next);
                },
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Bắt đầu phục vụ'));
      await tester.tap(find.text('Bắt đầu phục vụ'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(changes, ['in_service']);
      await tester.ensureVisible(find.text('Hoàn thành'));
      await tester.tap(find.text('Hoàn thành'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(changes, ['in_service', 'completed']);
      expect((row['payment'] as Map)['status'], 'unpaid');
      expect(find.text('Hoàn thành'), findsNothing);
    },
  );
  testWidgets('phone filters and appointment details fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffBookingList(bookings: [booking()])),
      ),
    );
    await tester.ensureVisible(find.text('Chi tiết'));
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Điện thoại: 0901234567'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rejected action shows reason and does not trap staff in retry state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: [booking()],
              now: DateTime.utc(2026, 11, 10, 3),
              onChangeStatus: (_, _) async =>
                  throw const SchedulingRejectedException('Lịch đã thay đổi'),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Bắt đầu phục vụ'));
      await tester.tap(find.text('Bắt đầu phục vụ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch đã thay đổi'), findsOneWidget);
      expect(find.text('Thử lại thao tác'), findsNothing);
    },
  );
  testWidgets(
    'statistics separates unpaid completed service value from paid value on phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffStatisticsScreen(
              now: DateTime.utc(2026, 11, 10),
              bookings: [
                {...booking(), 'status': 'completed'},
              ],
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('80.000đ'), 200);
      expect(find.text('80.000đ'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('0đ'), 100);
      expect(find.text('0đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
