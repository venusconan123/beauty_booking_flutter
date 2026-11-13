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
    'completion payment snapshot updates staff totals without adding twice',
    (tester) async {
      final row = {...booking(), 'status': 'completed'};
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                refresh = update;
                return StaffStatisticsScreen(
                  bookings: [row],
                  now: DateTime.utc(2026, 11, 10),
                );
              },
            ),
          ),
        ),
      );
      expect(
        find.text('Còn chưa thu trong lịch hoàn thành: 80.000đ'),
        findsOneWidget,
      );
      for (var i = 0; i < 2; i++) {
        refresh(
          () => row['payment'] = {'choice': 'pay_later', 'status': 'paid'},
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Còn chưa thu trong lịch hoàn thành: 0đ'),
          findsOneWidget,
        );
        expect(find.text('80.000đ'), findsNWidgets(2));
      }
    },
  );
  testWidgets('early start requires customer arrival confirmation', (
    tester,
  ) async {
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffBookingList(
            bookings: [booking()],
            now: DateTime.utc(2026, 11, 10, 1, 30),
            onChangeStatus: (_, next) async => changes.add(next),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Bắt đầu phục vụ'));
    await tester.tap(find.text('Bắt đầu phục vụ'));
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu phục vụ sớm?'), findsOneWidget);
    expect(find.textContaining('khách đã đến và đồng ý'), findsOneWidget);
    expect(changes, isEmpty);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.text('Bắt đầu phục vụ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(changes, ['in_service']);
  });

  testWidgets('unfinished service blocks start; closed bookings do not', (
    tester,
  ) async {
    for (final previousStatus in ['in_service', 'completed', 'cancelled']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: [
                booking(),
                {...booking(), 'id': 'previous', 'status': previousStatus},
              ],
              now: DateTime.utc(2026, 11, 10, 1, 30),
              onChangeStatus: (_, _) async {},
            ),
          ),
        ),
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Bắt đầu phục vụ'),
      );
      expect(button.onPressed == null, previousStatus == 'in_service');
    }
  });

  testWidgets(
    'other-day start stays disabled and actual time remains distinct',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: [booking()],
              now: DateTime.utc(2026, 11, 9, 2),
              onChangeStatus: (_, _) async {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Bắt đầu phục vụ'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: [
                {
                  ...booking(),
                  'status': 'in_service',
                  'startedEarly': true,
                  'serviceStartedAt': Timestamp.fromDate(
                    DateTime.utc(2026, 11, 10, 1, 30),
                  ),
                },
              ],
              now: DateTime.utc(2026, 11, 10, 1, 35),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Bắt đầu thực tế: 10/11/2026 08:30'),
        findsOneWidget,
      );
      expect(find.textContaining('10/11/2026 09:00'), findsOneWidget);
      expect(find.text('80.000đ'), findsOneWidget);
    },
  );

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
                  update(() {
                    row['status'] = next;
                    if (next == 'completed') {
                      row['payment'] = {
                        'choice': 'pay_later',
                        'status': 'paid',
                      };
                    }
                  });
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
      expect(
        find.textContaining('tự ghi nhận đã thanh toán 80.000đ'),
        findsOneWidget,
      );
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(changes, ['in_service', 'completed']);
      expect((row['payment'] as Map)['status'], 'paid');
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
    await tester.pumpAndSettle();
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
