import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_booking_app/main.dart';

void main() {
  testWidgets(
    'Hiển thị màn hình trang chủ',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MenHairBookingApp(),
      );

      expect(
        find.text('Men Hair Booking'),
        findsOneWidget,
      );

      expect(
        find.text('Xin chào!'),
        findsOneWidget,
      );
    },
  );
}