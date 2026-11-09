// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:men_hair_booking/workspace/workspace_store.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError('FAILED: $message');
  print('PASS: $message');
}

void rejects(void Function() action, String message) {
  var blocked = false;
  try {
    action();
  } on StateError {
    blocked = true;
  }
  check(blocked, message);
}

WorkspaceStore fresh() {
  final s = WorkspaceStore(today: DateTime(2026, 11, 9), restore: false);
  s.switchRole(WorkspaceRole.admin);
  return s;
}

String shiftId(WorkspaceStore s, String employee, String day) =>
    s.activeShifts(employee, day).first['id'] as String;
void main() {
  // The screenshot: Nam HC on 10 Jan and Bao C on 8 Jan; both other cells occupied.
  final s = fresh();
  final a = shiftId(s, 'staff-1', '2027-01-10');
  final b = shiftId(s, 'staff-2', '2027-01-08');
  rejects(
    () => s.previewSwap(a, b),
    'screenshot: strict two-shift exchange still rejects existing F shift',
  );
  final before = s.exportJson();
  final plan = s.previewSwap(a, b, wholeDays: true);
  check(
    plan.length == 4 && before == s.exportJson(),
    'four-cell preview is read-only and includes the two unselected cells',
  );
  s.swapEmployeeDays(a, b, expected: jsonEncode(plan));
  check(
    s.activeShifts('staff-1', '2027-01-10').single['code'] == 'F' &&
        s.activeShifts('staff-2', '2027-01-10').single['code'] == 'HC' &&
        s.activeShifts('staff-1', '2027-01-08').single['code'] == 'C' &&
        s.activeShifts('staff-2', '2027-01-08').single['code'] == 'S',
    'screenshot: four schedules exchanged without retaining conflicting assignments',
  );
  check(s.audit.length == 1, 'whole exchange writes one audit event');
  final restored = WorkspaceStore(today: s.today, snapshot: s.exportJson());
  check(
    restored.activeShifts('staff-2', '2027-01-10').single['code'] == 'HC',
    'four-cell result survives serialization/reload',
  );

  for (final employee in ['staff-1', 'staff-2']) {
    for (final day in ['2027-01-08', '2027-01-10']) {
      final blocked = fresh();
      final x = shiftId(blocked, 'staff-1', '2027-01-10'),
          y = shiftId(blocked, 'staff-2', '2027-01-08');
      blocked.bookings.add({
        'id': 'blocking',
        'employeeId': employee,
        'day': day,
        'salonId': 'salon_03',
        'start': 540,
        'end': 600,
        'status': 'confirmed',
      });
      final original = blocked.exportJson();
      rejects(
        () => blocked.swapEmployeeDays(x, y, expected: 'old-plan'),
        'booking check: $employee on $day, including another branch',
      );
      check(
        blocked.exportJson() == original,
        'rejected exchange leaves all four cells and audit unchanged',
      );
    }
  }
  final off = fresh();
  final x = shiftId(off, 'staff-1', '2027-01-10'),
      y = shiftId(off, 'staff-2', '2027-01-12');
  final offPlan = off.previewSwap(x, y, wholeDays: true);
  check(
    offPlan.any((r) => r['status'] == 'off'),
    'whole-day preview explicitly includes a companion OFF',
  );
  off.swapEmployeeDays(x, y, expected: jsonEncode(offPlan));
  check(
    off.activeShifts('staff-2', '2027-01-12').single['status'] == 'off',
    'OFF follows the exchanged daily schedule',
  );

  final multiple = fresh();
  final mA = shiftId(multiple, 'staff-1', '2027-01-10'),
      mB = shiftId(multiple, 'staff-2', '2027-01-08');
  multiple.shifts.add({
    'id': 'extra',
    'employeeId': 'staff-1',
    'day': '2027-01-08',
    'salonId': 'salon_02',
    'code': 'T',
    'start': 1020,
    'end': 1200,
    'status': 'scheduled',
  });
  final multiPlan = multiple.previewSwap(mA, mB, wholeDays: true);
  check(
    multiPlan.length == 5 && multiPlan.any((r) => r['salonId'] == 'salon_02'),
    'preview includes all extra shifts across branches',
  );
  multiple.swapEmployeeDays(mA, mB, expected: jsonEncode(multiPlan));
  check(
    multiple.activeShifts('staff-2', '2027-01-08').length == 2,
    'cross-branch nonoverlapping schedule exchanged together',
  );

  final stale = fresh();
  final stA = shiftId(stale, 'staff-1', '2027-01-10'),
      stB = shiftId(stale, 'staff-2', '2027-01-08');
  final old = jsonEncode(stale.previewSwap(stA, stB, wholeDays: true));
  stale.shifts.firstWhere((r) => r['id'] == stA)['start'] = 600;
  final state = stale.exportJson();
  rejects(
    () => stale.swapEmployeeDays(stA, stB, expected: old),
    'stale preview cannot apply silently',
  );
  check(state == stale.exportJson(), 'stale-preview rejection is atomic');
  final disabled = fresh();
  final dA = shiftId(disabled, 'staff-1', '2027-01-10'),
      dB = shiftId(disabled, 'staff-2', '2027-01-08');
  final expected = jsonEncode(disabled.previewSwap(dA, dB, wholeDays: true));
  disabled.person('staff-2')['active'] = false;
  rejects(
    () => disabled.swapEmployeeDays(dA, dB, expected: expected),
    'deactivated employee blocked between preview and save',
  );
  disabled.switchRole(WorkspaceRole.staff, employee: 'staff-1');
  rejects(
    () => disabled.previewSwap(dA, dB, wholeDays: true),
    'staff cannot request admin swap preview',
  );
  print('All two-day roster exchange checks passed.');
}
