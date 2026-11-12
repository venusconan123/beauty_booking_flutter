import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/data/sample_salons.dart';
import 'package:men_hair_booking/services/salon_directions.dart';
import 'package:men_hair_booking/widgets/salon_map_information.dart';

void main() {
  test(
    'Directions use the branch name and address instead of approximate coordinates',
    () {
      for (final salon in sampleSalons) {
        final uri = salonDirectionsUri(salon);
        expect(uri.scheme, 'https');
        expect(uri.host, 'www.google.com');
        expect(uri.path, '/maps/dir/');
        expect(uri.queryParameters['api'], '1');
        expect(
          uri.queryParameters['destination'],
          salon.mapsDestination ?? '${salon.name}, ${salon.address}, Việt Nam',
        );
        expect(uri.queryParameters['dir_action'], 'navigate');
        expect(uri.queryParameters.containsKey('origin'), isFalse);
      }
    },
  );

  Future<void> showInformation(
    WidgetTester tester, {
    required Future<bool> Function(Uri) launch,
    required VoidCallback details,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SalonMapInformation(
          salon: sampleSalons.first,
          onDetails: details,
          openDirections: launch,
        ),
      ),
    ),
  );

  testWidgets('Son Tra branch opens directions to its street address', (
    tester,
  ) async {
    var launches = 0;
    Uri? destination;
    var details = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalonMapInformation(
            salon: sampleSalons.singleWhere((salon) => salon.id == 'salon_03'),
            onDetails: () => details++,
            openDirections: (uri) async {
              destination = uri;
              launches++;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('mô phỏng'), findsNothing);
    expect(find.text('30Shine Sơn Trà'), findsOneWidget);
    await tester.tap(find.text('Chỉ đường'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết salon'));
    expect(launches, 1);
    expect(
      destination!.queryParameters['destination'],
      '120 Ngô Quyền, Sơn Trà, Đà Nẵng, Việt Nam',
    );
    expect(details, 1);
  });

  test(
    'Xo Viet Nghe Tinh route retains number 130 and city after URL decoding',
    () {
      final salon = sampleSalons.singleWhere((salon) => salon.id == 'salon_02');
      final destination = Uri.parse(
        salonDirectionsUri(salon).toString(),
      ).queryParameters['destination']!;
      expect(destination, contains('130 Xô Viết Nghệ Tĩnh'));
      expect(destination, contains('Đà Nẵng'));
      expect(destination, isNot(contains('174')));
      expect(destination, isNot(contains('${salon.latitude}')));
      expect(
        sampleSalons.last.copyWith(hotline: 'test').mapsDestination,
        sampleSalons.last.mapsDestination,
      );
    },
  );

  for (final width in [320.0, 900.0]) {
    testWidgets('Branch info and independent actions fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? launched;
      var details = 0;
      await showInformation(
        tester,
        launch: (uri) async {
          launched = uri;
          return true;
        },
        details: () => details++,
      );
      expect(find.text(sampleSalons.first.name), findsOneWidget);
      expect(find.text(sampleSalons.first.address), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('ước tính'), findsNothing);
      await tester.tap(find.text('Chỉ đường'));
      await tester.pumpAndSettle();
      expect(launched, salonDirectionsUri(sampleSalons.first));
      expect(details, 0);
      expect(find.text(sampleSalons.first.name), findsOneWidget);
      await tester.tap(find.text('Xem chi tiết salon'));
      expect(details, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final throwsError in [false, true]) {
    testWidgets('Failed launch allows retry (throws: $throwsError)', (
      tester,
    ) async {
      var attempts = 0;
      await showInformation(
        tester,
        launch: (_) async {
          attempts++;
          if (attempts == 1) {
            if (throwsError) throw StateError('No URL handler');
            return false;
          }
          return true;
        },
        details: () {},
      );
      await tester.tap(find.text('Chỉ đường'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không thể mở Google Maps'), findsOneWidget);
      await tester.tap(find.text('Chỉ đường'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.textContaining('Không thể mở Google Maps'), findsNothing);
    });
  }

  testWidgets(
    'Pending launch disables duplicate taps and safely handles leaving',
    (tester) async {
      final pending = Completer<bool>();
      var attempts = 0;
      await showInformation(
        tester,
        launch: (_) {
          attempts++;
          return pending.future;
        },
        details: () {},
      );
      await tester.tap(find.text('Chỉ đường'));
      await tester.pump();
      await tester.tap(find.text('Đang mở…'));
      expect(attempts, 1);
      await tester.pumpWidget(const SizedBox());
      pending.complete(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
