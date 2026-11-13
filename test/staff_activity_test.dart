import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/models/staff_activity.dart';

void main() {
  test(
    'custom dates include both whole Vietnam days and reject reversed ranges',
    () {
      final range = StaffDateRange.custom(
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 13),
      );
      expect(
        range.containsInstant(DateTime.parse('2026-11-09T16:59:59Z')),
        isFalse,
      );
      expect(
        range.containsInstant(DateTime.parse('2026-11-09T17:00:00Z')),
        isTrue,
      );
      expect(
        range.containsInstant(DateTime.parse('2026-11-13T16:59:59.999Z')),
        isTrue,
      );
      expect(
        range.containsInstant(DateTime.parse('2026-11-13T17:00:00Z')),
        isFalse,
      );
      expect(range.label, '10/11/2026 – 13/11/2026');
      expect(
        () => StaffDateRange.custom(
          DateTime(2026, 11, 13),
          DateTime(2026, 11, 10),
        ),
        throwsArgumentError,
      );
      final today = StaffDateRange(
        StaffPeriod.today,
        vietnamDay(DateTime.parse('2026-11-12T18:00:00Z')),
      );
      expect(
        today.containsInstant(DateTime.parse('2026-11-12T17:00:00Z')),
        isTrue,
      );
      expect(
        today.containsInstant(DateTime.parse('2026-11-13T17:00:00Z')),
        isFalse,
      );
      expect(
        StaffDateRange.custom(
          DateTime(2026, 11, 13),
          DateTime(2026, 11, 13),
        ).label,
        '13/11/2026 – 13/11/2026',
      );
    },
  );
  test(
    'Vietnam period boundaries use appointment day and Monday-start weeks',
    () {
      Map<String, dynamic> at(String time) => {
        'appointmentAt': Timestamp.fromDate(DateTime.parse(time)),
      };
      final feb = StaffDateRange(StaffPeriod.month, DateTime.utc(2026, 2, 12));
      expect(feb.contains(at('2026-01-31T16:59:59Z')), isFalse);
      expect(feb.contains(at('2026-01-31T17:00:00Z')), isTrue);
      expect(feb.contains(at('2026-02-28T17:00:00Z')), isFalse);
      expect(feb.contains({}), isFalse);
      final week = StaffDateRange(StaffPeriod.week, DateTime.utc(2026, 11, 10));
      expect(week.start, DateTime.utc(2026, 11, 9));
      expect(week.end, DateTime.utc(2026, 11, 16));
    },
  );
  test('stats count completed service value separately from paid value', () {
    final stats = StaffActivityStats([
      {
        'status': 'completed',
        'totalPrice': 80000,
        'payment': {'status': 'unpaid'},
        'services': [
          {'name': 'Cắt tóc'},
        ],
      },
      {
        'status': 'completed',
        'totalPrice': 50000,
        'payment': {'status': 'paid'},
        'services': [
          {'name': 'Cắt tóc'},
          {'name': 'Gội đầu'},
        ],
      },
      {
        'status': 'cancelled',
        'totalPrice': 200000,
        'payment': {'status': 'paid'},
      },
      {'status': 'in_service', 'totalPrice': 90000},
      {
        'status': 'pending',
        'payment': {'choice': 'pay_later'},
      },
    ]);
    expect(stats.total, 5);
    expect(stats.count('confirmed'), 1);
    expect(stats.count('completed'), 2);
    expect(stats.completedValue, 130000);
    expect(stats.paidValue, 50000);
    expect(stats.services, {'Cắt tóc': 2, 'Gội đầu': 1});
    expect(stats.completionRate, .4);
    expect(StaffActivityStats([]).completionRate, 0);
  });
}
