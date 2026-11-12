import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:men_hair_booking/screens/admin_booking_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/widgets/admin_payment_button.dart';
import 'package:men_hair_booking/services/scheduling_service.dart';

void main() {
  testWidgets(
    'admin timer rebuild retains the payment confirmation and its state',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      var watches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminBookingScreen(
            watchBookings: () {
              watches++;
              return controller.stream;
            },
          ),
        ),
      );
      controller.add(_BookingsSnapshot());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn thành (1)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ghi nhận thanh toán'));
      final before = tester.state(find.byType(AdminPaymentButton));
      await tester.tap(find.text('Ghi nhận thanh toán'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(watches, 1);
      expect(tester.state(find.byType(AdminPaymentButton)), same(before));
      expect(find.text('Xác nhận đã nhận tiền'), findsOneWidget);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(controller.close());
      await tester.pump();
    },
  );
  testWidgets(
    'admin confirms exact amount and payment method before recording',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPaymentButton(
              bookingId: 'completed-a',
              amount: 125000,
              onRecord: (data) async {
                sent = data;
                return {'alreadyPaid': false};
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ghi nhận thanh toán'));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(find.text('Số tiền: 125.000đ'), findsOneWidget);
      await tester.tap(find.text('Tiền mặt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuyển khoản').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận đã nhận tiền'));
      await tester.pumpAndSettle();
      expect(sent!['bookingId'], 'completed-a');
      expect(sent!['expectedAmount'], 125000);
      expect(sent!['method'], 'bank_transfer');
      expect(sent!['requestId'], isNotEmpty);
    },
  );
  testWidgets(
    'retry after lost response retains request ID, method and amount',
    (tester) async {
      final seen = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPaymentButton(
              bookingId: 'completed-b',
              amount: 80000,
              onRecord: (data) async {
                seen.add(Map.of(data));
                if (seen.length == 1) {
                  throw const SchedulingTimeoutException('lost', 'http');
                }
                return {'alreadyPaid': true};
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ghi nhận thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận đã nhận tiền'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại ghi nhận'));
      await tester.pumpAndSettle();
      expect(seen, hasLength(2));
      expect(seen[1], seen[0]);
      expect(
        find.text('Lịch đã thanh toán trước đó; không ghi nhận thêm.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('cancel payment confirmation makes no request', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPaymentButton(
            bookingId: 'completed-c',
            amount: 80000,
            onRecord: (_) async {
              calls++;
              return {};
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ghi nhận thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}

class _BookingsSnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    _BookingDocument(),
  ];
}

// SDK snapshot fixture for this widget test only.
// ignore: subtype_of_sealed_class
class _BookingDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'payment-confirmation-test';
  @override
  Map<String, dynamic> data() => {
    'salonId': 'salon_01',
    'status': 'completed',
    'userName': 'Khách test',
    'barberId': 'employee-a',
    'barberName': 'Nhân viên A',
    'totalPrice': 80000,
    'totalDurationMinutes': 30,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 10)),
    'services': [
      {'name': 'Cắt tóc'},
    ],
    'payment': {'choice': 'pay_later', 'status': 'unpaid'},
  };
}
