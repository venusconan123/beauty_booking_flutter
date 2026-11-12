import 'dart:async';

import '../models/barber.dart';

/// A cached directory stream can be listened to again after returning to a tab.
/// Each listener owns fresh subscriptions and cancels them when it leaves.
Stream<List<Barber>> restartableBarberStream(
  Stream<List<Barber>> Function() open,
) => Stream.multi((controller) {
  final subscription = open().listen(
    controller.addSync,
    onError: (Object error, StackTrace stack) =>
        controller.addErrorSync(error, stack),
    onDone: controller.closeSync,
  );
  controller.onPause = subscription.pause;
  controller.onResume = subscription.resume;
  controller.onCancel = subscription.cancel;
}, isBroadcast: true);

/// Refresh derived ratings when profiles or reviews change; discard stale reads.
Stream<List<Barber>> watchBarberRatings({
  required Stream<List<Barber>> profiles,
  required Stream<Object?> reviewChanges,
  required Future<Map<String, ({double average, int count})>> Function(
    List<String>,
  )
  load,
  Duration debounce = const Duration(milliseconds: 100),
}) {
  late StreamController<List<Barber>> controller;
  StreamSubscription<List<Barber>>? profileSubscription;
  StreamSubscription<Object?>? reviewSubscription;
  List<Barber>? latest;
  Timer? timer;
  var generation = 0;
  var cancelled = false;

  void refresh() {
    final current = ++generation;
    timer?.cancel();
    if (latest == null || cancelled) return;
    final rows = List<Barber>.of(latest!);
    timer = Timer(debounce, () async {
      try {
        final stats = rows.isEmpty
            ? <String, ({double average, int count})>{}
            : await load(rows.map((row) => row.id).toList());
        if (cancelled || generation != current) return;
        final result = rows.map((row) {
          final value = stats[row.id];
          if (value == null) {
            throw const FormatException('Thiếu thống kê đánh giá nhân viên.');
          }
          return row.withReviewStats(
            average: value.average,
            count: value.count,
          );
        }).toList();
        controller.add(result);
      } catch (error, stack) {
        if (!cancelled && generation == current) {
          controller.addError(error, stack);
        }
      }
    });
  }

  void sourceError(Object error, StackTrace stack) {
    generation++;
    timer?.cancel();
    if (!cancelled) controller.addError(error, stack);
  }

  controller = StreamController<List<Barber>>(
    onListen: () {
      profileSubscription = profiles.listen((rows) {
        latest = rows;
        refresh();
      }, onError: sourceError);
      reviewSubscription = reviewChanges.listen(
        (_) => refresh(),
        onError: sourceError,
      );
    },
    onPause: () {
      generation++;
      timer?.cancel();
      profileSubscription?.pause();
      reviewSubscription?.pause();
    },
    onResume: () {
      profileSubscription?.resume();
      reviewSubscription?.resume();
      refresh();
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      timer?.cancel();
      await profileSubscription?.cancel();
      await reviewSubscription?.cancel();
    },
  );
  return controller.stream;
}
