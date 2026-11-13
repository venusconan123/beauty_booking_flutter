import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/screens/admin_dashboard_screen.dart';
import 'package:men_hair_booking/screens/staff_statistics_screen.dart';
import 'package:men_hair_booking/screens/staff_bookings_screen.dart';

Map<String, dynamic> row(String instant, int amount) => {
  'createdAt': Timestamp.fromDate(DateTime.parse(instant)),
  'appointmentAt': Timestamp.fromDate(DateTime.parse(instant)),
  'status': 'completed',
  'totalPrice': amount,
  'salonId': 'salon_01',
  'payment': {'status': 'paid'},
};

final rows = [
  row('2026-11-09T16:59:59Z', 1000),
  row('2026-11-09T17:00:00Z', 2000),
  row('2026-11-13T16:59:59Z', 4000),
  row('2026-11-13T17:00:00Z', 8000),
];

Future<void> enterRange(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final inputs = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        ['Từ ngày', 'Đến ngày'].contains(widget.decoration?.labelText),
  );
  expect(inputs, findsNWidgets(2));
  await tester.enterText(inputs.at(0), '11/10/2026');
  await tester.enterText(inputs.at(1), '11/13/2026');
  await tester.tap(find.text('Áp dụng'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'staff 7 and 30 days include today and exclude future appointments',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: [
                ...rows,
                row('2026-11-01T03:00:00Z', 16000),
                row('2026-10-01T03:00:00Z', 32000),
              ],
              now: DateTime.utc(2026, 11, 13, 3),
            ),
          ),
        ),
      );
      await tester.tap(find.text('7 ngày'));
      await tester.pumpAndSettle();
      expect(find.text('3 lịch hẹn'), findsOneWidget);
      expect(find.text('Từ 07/11/2026 đến 13/11/2026'), findsOneWidget);
      await tester.tap(find.text('30 ngày'));
      await tester.pumpAndSettle();
      expect(find.text('4 lịch hẹn'), findsOneWidget);
      expect(find.text('Từ 15/10/2026 đến 13/11/2026'), findsOneWidget);
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('1 lịch hẹn'), findsOneWidget);
    },
  );
  testWidgets(
    'staff appointments filter a range then today and clear on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBookingList(
              bookings: rows,
              now: DateTime.utc(2026, 11, 13, 3),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn khoảng ngày'));
      await enterRange(tester);
      expect(find.text('2 lịch hẹn'), findsOneWidget);
      expect(find.text('Từ 10/11/2026 đến 13/11/2026'), findsOneWidget);
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('1 lịch hẹn'), findsOneWidget);
      await tester.tap(find.text('Bỏ lọc ngày'));
      await tester.pumpAndSettle();
      expect(find.text('4 lịch hẹn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'staff today, custom inclusive range and cancelling preserve correct totals',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffStatisticsScreen(
              bookings: rows,
              now: DateTime.utc(2026, 11, 13, 3),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('4.000đ'), findsNWidgets(2));
      await tester.tap(find.text('Chọn khoảng ngày'));
      await enterRange(tester);
      expect(find.text('Từ 10/11/2026 đến 13/11/2026'), findsOneWidget);
      expect(find.text('6.000đ'), findsNWidgets(2));
      await tester.tap(find.text('Chọn khoảng ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('6.000đ'), findsNWidgets(2));
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('4.000đ'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin today and custom range filter created date including final day',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            now: DateTime.utc(2026, 11, 13, 3),
            bookingsStream: Stream.value(_Snapshot(rows)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 ngày').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hôm nay').last);
      await tester.pumpAndSettle();
      expect(find.text('4.000đ'), findsOneWidget);
      await tester.tap(find.text('Hôm nay').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn khoảng ngày').last);
      await enterRange(tester);
      expect(find.text('6.000đ'), findsOneWidget);
      expect(find.text('Từ 10/11/2026 đến 13/11/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Chọn khoảng ngày').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ngày').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '11/10/2026');
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.text('2.000đ'), findsOneWidget);
      expect(find.text('Ngày 10/11/2026'), findsOneWidget);
    },
  );
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      rows.map(_Document.new).toList();
}

// SDK snapshot fixture used only by this widget test.
// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.row);
  final Map<String, dynamic> row;
  @override
  Map<String, dynamic> data() => row;
}
