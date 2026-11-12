import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/models/dashboard_stats.dart';
import 'package:men_hair_booking/models/staff_activity.dart';

void main() {
  for (final method in ['cash', 'bank_transfer']) {
    final file = File('build/demo-validation/$method.json');
    test(
      'real emulator chain $method agrees with admin and staff statistics',
      () {
        final report = jsonDecode(file.readAsStringSync()) as Map;
        expect(report['project'], 'demo-men-hair-booking');
        final rows = <String, Map<String, dynamic>>{};
        for (final state in ['booked', 'completed', 'collected']) {
          rows[state] = Map<String, dynamic>.from(report[state] as Map);
          rows[state]!['appointmentAt'] = Timestamp.fromDate(
            DateTime.parse(rows[state]!['appointmentAt'] as String),
          );
        }
        expect(rows['booked']!['id'], rows['collected']!['id']);
        final before = DashboardStats.fromBookings([rows['completed']!]);
        final after = DashboardStats.fromBookings([rows['collected']!]);
        expect(before.completedValue, 99000);
        expect(before.revenue, 0);
        expect(before.outstanding, 99000);
        expect(after.completedValue, 99000);
        expect(after.revenue, 99000);
        expect(after.outstanding, 0);
        final staffBefore = StaffActivityStats([rows['completed']!]);
        final staffAfter = StaffActivityStats([rows['collected']!]);
        expect(staffBefore.paidValue, 0);
        expect(staffAfter.paidValue, after.revenue);
        expect(staffAfter.services.values.reduce((a, b) => a + b), 2);
        expect(
          StaffDateRange(
            StaffPeriod.day,
            DateTime.utc(2030, 1, 2),
          ).contains(rows['collected']!),
          isTrue,
        );
      },
      skip: file.existsSync()
          ? false
          : 'Run Firebase Emulator suite first to generate actual flow snapshots.',
    );
  }
}
