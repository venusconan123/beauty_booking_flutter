import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:men_hair_booking/data/sample_salons.dart';
import 'package:men_hair_booking/models/barber.dart';
import 'package:men_hair_booking/screens/barber_selection_screen.dart';
import 'package:men_hair_booking/screens/date_time_selection_screen.dart';
import 'package:men_hair_booking/services/scheduling_service.dart';

void main() {
  const barber = Barber(
    id: 'test-worker',
    salonId: 'salon_01',
    name: 'Thợ kiểm thử',
    experienceYears: 1,
    rating: 5,
  );
  testWidgets(
    'choosing a barber/rebuilding/idle do not reload; refresh recovers error',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BarberSelectionScreen(
            salon: sampleSalons.first,
            selectedServices: [sampleSalons.first.services.first],
            loadBarbers: (_) {
              calls++;
              return calls == 2
                  ? Stream.error(StateError('offline'))
                  : Stream.value([barber]);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.text('Chọn thợ bất kỳ'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 1);
      await tester.tap(find.byTooltip('Làm mới danh sách thợ'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.text('Không thể kiểm tra lịch làm. Vui lòng thử lại.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Làm mới danh sách thợ'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Đội ngũ tại chi nhánh'), findsOneWidget);
    },
  );

  testWidgets(
    'availability is event-driven and ignores an old response after refresh',
    (tester) async {
      var calls = 0;
      final pending = <Completer<http.Response>>[];
      final service = SchedulingService.testing(
        tokenProvider: () async => 'test-token',
        clientFactory: () => MockClient((request) {
          calls++;
          final done = Completer<http.Response>();
          pending.add(done);
          return done.future;
        }),
      );
      http.Response response(List<String> times) => http.Response(
        jsonEncode({
          'result': {
            'slots': times.map((t) => {'time': t}).toList(),
          },
        }),
        200,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DateTimeSelectionScreen(
            salon: sampleSalons.first,
            selectedServices: [sampleSalons.first.services.first],
            selectedBarber: barber,
            useAnyBarber: false,
            schedulingService: service,
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);
      pending[0].complete(response(['18:00']));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 1);
      await tester.tap(find.byTooltip('Làm mới giờ trống'));
      await tester.pump();
      expect(calls, 2);
      await tester.tap(find.byTooltip('Làm mới giờ trống'));
      await tester.pump();
      expect(calls, 3);
      pending[2].complete(response([]));
      await tester.pumpAndSettle();
      pending[1].complete(response(['18:00']));
      await tester.pumpAndSettle();
      final button = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('18:00'), matching: find.byType(InkWell))
            .first,
      );
      // The stale request must not restore an available slot from the older load.
      expect(button.onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
