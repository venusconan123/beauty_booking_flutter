import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/models/barber.dart';
import 'package:men_hair_booking/services/barber_ratings_stream.dart';

typedef Stats = Map<String, ({double average, int count})>;
const worker = Barber(
  id: 'worker',
  salonId: 'salon_01',
  name: 'Thợ',
  experienceYears: 3,
  rating: 0,
);
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test(
    'returning to an employee tab starts a fresh subscription on its cached stream',
    () async {
      var starts = 0;
      final directory = restartableBarberStream(() {
        starts++;
        return Stream.value([
          worker.withReviewStats(average: 4, count: starts),
        ]);
      });
      expect((await directory.first).single.reviewCount, 1);
      expect((await directory.first).single.reviewCount, 2);
      expect(starts, 2);
    },
  );

  test(
    'profile documents never supply manual/demo ratings and profile saves omit statistics',
    () {
      final profile = Barber.fromDocument('worker', {
        'salonId': 'salon_01',
        'name': 'Thợ',
        'rating': 4.9,
        'reviewCount': 119,
      });
      expect(profile.rating, 0);
      expect(profile.reviewCount, 0);
      expect(profile.reviewSummary, 'Chưa có đánh giá');
      final rated = profile.withReviewStats(average: 14 / 3, count: 3);
      expect(rated.reviewSummary, '4.7 (3 đánh giá)');
      expect(rated.name, profile.name);
      expect(rated.toMap().containsKey('rating'), isFalse);
      expect(rated.toMap().containsKey('reviewCount'), isFalse);
    },
  );

  test(
    'review edits refresh ratings; a late older response cannot overwrite the latest values',
    () async {
      final profiles = StreamController<List<Barber>>(),
          reviews = StreamController<Object?>();
      final loads = <Completer<Stats>>[];
      final first = Completer<void>(),
          second = Completer<void>(),
          received = Completer<void>();
      final values = <List<Barber>>[];
      final subscription =
          watchBarberRatings(
            profiles: profiles.stream,
            reviewChanges: reviews.stream,
            debounce: Duration.zero,
            load: (ids) {
              expect(ids, ['worker']);
              loads.add(Completer<Stats>());
              if (loads.length == 1) {
                first.complete();
              } else {
                second.complete();
              }
              return loads.last.future;
            },
          ).listen((rows) {
            values.add(rows);
            if (!received.isCompleted) received.complete();
          });
      profiles.add([worker]);
      await first.future;
      reviews.add('review changed');
      await second.future;
      loads[1].complete({'worker': (average: 3.5, count: 2)});
      await received.future;
      loads[0].complete({'worker': (average: 5, count: 1)});
      await tick();
      expect(values, hasLength(1));
      expect(values.single.single.rating, 3.5);
      expect(values.single.single.reviewCount, 2);
      await subscription.cancel();
      await profiles.close();
      await reviews.close();
    },
  );

  test(
    'permission/read errors discard a pending result and recover only after a fresh successful read',
    () async {
      final profiles = StreamController<List<Barber>>(),
          reviews = StreamController<Object?>();
      final pending = Completer<Stats>(),
          started = Completer<void>(),
          failed = Completer<void>(),
          recovered = Completer<void>();
      var calls = 0;
      final values = <List<Barber>>[];
      final subscription =
          watchBarberRatings(
            profiles: profiles.stream,
            reviewChanges: reviews.stream,
            debounce: Duration.zero,
            load: (_) {
              calls++;
              if (calls == 1) {
                started.complete();
                return pending.future;
              }
              return Future.value({'worker': (average: 4.0, count: 1)});
            },
          ).listen(
            (rows) {
              values.add(rows);
              recovered.complete();
            },
            onError: (Object error) {
              expect(error, isA<StateError>());
              failed.complete();
            },
          );
      profiles.add([worker]);
      await started.future;
      reviews.addError(StateError('permission changed'));
      await failed.future;
      pending.complete({'worker': (average: 5, count: 99)});
      await tick();
      expect(values, isEmpty);
      reviews.add('fresh snapshot');
      await recovered.future;
      expect(values.single.single.reviewCount, 1);
      await subscription.cancel();
      await profiles.close();
      await reviews.close();
    },
  );

  test(
    'leaving a screen cancels both subscriptions and ignores an outstanding response',
    () async {
      var profilesCancelled = false, reviewsCancelled = false;
      final profiles = StreamController<List<Barber>>(
        onCancel: () => profilesCancelled = true,
      );
      final reviews = StreamController<Object?>(
        onCancel: () => reviewsCancelled = true,
      );
      final pending = Completer<Stats>(), started = Completer<void>();
      final values = <List<Barber>>[];
      final subscription = watchBarberRatings(
        profiles: profiles.stream,
        reviewChanges: reviews.stream,
        debounce: Duration.zero,
        load: (_) {
          started.complete();
          return pending.future;
        },
      ).listen(values.add);
      profiles.add([worker]);
      await started.future;
      await subscription.cancel();
      pending.complete({'worker': (average: 5, count: 1)});
      await tick();
      expect(values, isEmpty);
      expect(profilesCancelled && reviewsCancelled, isTrue);
      await profiles.close();
      await reviews.close();
    },
  );

  test(
    'empty employee lists need no API call and missing statistics fail instead of displaying fake numbers',
    () async {
      final profiles = StreamController<List<Barber>>(),
          reviews = StreamController<Object?>();
      final empty = Completer<void>(), failed = Completer<void>();
      var calls = 0;
      final subscription =
          watchBarberRatings(
            profiles: profiles.stream,
            reviewChanges: reviews.stream,
            debounce: Duration.zero,
            load: (_) async {
              calls++;
              return {};
            },
          ).listen(
            (rows) {
              expect(rows, isEmpty);
              empty.complete();
            },
            onError: (Object error) {
              expect(error, isA<FormatException>());
              failed.complete();
            },
          );
      profiles.add([]);
      await empty.future;
      expect(calls, 0);
      profiles.add([worker]);
      await failed.future;
      expect(calls, 1);
      await subscription.cancel();
      await profiles.close();
      await reviews.close();
    },
  );
}
