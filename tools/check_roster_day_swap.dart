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

RowData shift(WorkspaceStore s, String employee, String day) =>
    s.activeShifts(employee, day).single;
String unselected(WorkspaceStore s, String a, String b) =>
    jsonEncode(s.shifts.where((r) => r['id'] != a && r['id'] != b).toList());
void main() {
  final s = fresh();
  final a = shift(s, 'staff-2', '2026-12-04'),
      b = shift(s, 'staff-1', '2026-12-04');
  check(
    a['code'] == 'C' && b['code'] == 'S',
    'reproduce screenshot C/S on same 04 December',
  );
  final untouched = unselected(s, a['id'] as String, b['id'] as String);
  final before = s.exportJson();
  final plan = s.previewSwap(a['id'] as String, b['id'] as String);
  check(
    plan.length == 2 && before == s.exportJson(),
    'preview is read-only and contains exactly selected cells',
  );
  s.swapShifts(
    a['id'] as String,
    b['id'] as String,
    expected: jsonEncode(plan),
  );
  check(
    a['code'] == 'S' &&
        a['start'] == 420 &&
        a['end'] == 900 &&
        b['code'] == 'C' &&
        b['start'] == 840 &&
        b['end'] == 1320,
    'same-day C and S exchange successfully',
  );
  check(
    a['employeeId'] == 'staff-2' &&
        b['employeeId'] == 'staff-1' &&
        a['day'] == '2026-12-04' &&
        b['day'] == '2026-12-04' &&
        a['salonId'] == 'salon_01' &&
        b['salonId'] == 'salon_01',
    'employee, date and branch unchanged',
  );
  check(
    untouched == unselected(s, a['id'] as String, b['id'] as String),
    'all unselected records are byte-for-byte unchanged',
  );
  final restored = WorkspaceStore(today: s.today, snapshot: s.exportJson());
  check(
    shift(restored, 'staff-2', '2026-12-04')['code'] == 'S',
    'same-day result survives reload',
  );

  final same = fresh();
  final x = shift(same, 'staff-1', '2026-12-14'),
      y = shift(same, 'staff-2', '2026-12-13');
  final off = jsonEncode(shift(same, 'staff-1', '2026-12-13'));
  final c = jsonEncode(shift(same, 'staff-2', '2026-12-14'));
  same.swapShifts(x['id'] as String, y['id'] as String);
  check(
    x['code'] == 'S' && y['code'] == 'S',
    'two selected S shifts remain S, with no unexpected C or OFF',
  );
  check(
    off == jsonEncode(shift(same, 'staff-1', '2026-12-13')) &&
        c == jsonEncode(shift(same, 'staff-2', '2026-12-14')),
    'companion C and OFF cells remain unchanged',
  );

  final different = fresh();
  final dA = shift(different, 'staff-1', '2027-01-10'),
      dB = shift(different, 'staff-2', '2027-01-08');
  final others = unselected(different, dA['id'] as String, dB['id'] as String);
  different.swapShifts(dA['id'] as String, dB['id'] as String);
  check(
    dA['code'] == 'C' &&
        dB['code'] == 'HC' &&
        others == unselected(different, dA['id'] as String, dB['id'] as String),
    'different-day swap changes exactly the two cells',
  );

  for (final employee in ['staff-1', 'staff-2']) {
    for (final day in ['2027-01-08', '2027-01-10']) {
      final blocked = fresh();
      final ba = shift(blocked, 'staff-1', '2027-01-10'),
          bb = shift(blocked, 'staff-2', '2027-01-08');
      blocked.bookings.add({
        'id': 'blocking',
        'employeeId': employee,
        'day': day,
        'salonId': 'salon_03',
        'start': 540,
        'end': 600,
        'status': 'confirmed',
      });
      final state = blocked.exportJson();
      rejects(
        () => blocked.swapShifts(ba['id'] as String, bb['id'] as String),
        'booking blocked: $employee on $day at another branch',
      );
      check(state == blocked.exportJson(), 'booking rejection is atomic');
    }
  }
  final overlap = fresh();
  final oa = shift(overlap, 'staff-1', '2026-12-04'),
      ob = shift(overlap, 'staff-2', '2026-12-04');
  // Nam has S until 15:00 plus a nonoverlapping evening shift at another branch.
  overlap.shifts.add({
    'id': 'extra',
    'employeeId': 'staff-1',
    'day': '2026-12-04',
    'salonId': 'salon_02',
    'code': 'T',
    'start': 1020,
    'end': 1200,
    'status': 'scheduled',
  });
  final original = overlap.exportJson();
  rejects(
    () => overlap.swapShifts(oa['id'] as String, ob['id'] as String),
    'new C shift is blocked by another branch evening shift',
  );
  check(
    original == overlap.exportJson(),
    'overlap rejection changes no rows or audit',
  );

  final stale = fresh();
  final sa = shift(stale, 'staff-1', '2026-12-04'),
      sb = shift(stale, 'staff-2', '2026-12-04');
  final expected = jsonEncode(
    stale.previewSwap(sa['id'] as String, sb['id'] as String),
  );
  sa['start'] = 450;
  rejects(
    () => stale.swapShifts(
      sa['id'] as String,
      sb['id'] as String,
      expected: expected,
    ),
    'stale preview must be reviewed again',
  );
  stale.person('staff-2')['active'] = false;
  rejects(
    () => stale.previewSwap(sa['id'] as String, sb['id'] as String),
    'inactive employee blocked',
  );
  stale.switchRole(WorkspaceRole.staff, employee: 'staff-1');
  rejects(
    () => stale.previewSwap(sa['id'] as String, sb['id'] as String),
    'staff cannot swap schedules',
  );
  final invalid = fresh();
  rejects(
    () => invalid.previewSwap(
      shift(invalid, 'staff-1', '2026-12-13')['id'] as String,
      shift(invalid, 'staff-2', '2026-12-14')['id'] as String,
    ),
    'OFF cannot be selected as a work shift',
  );
  print('All two-cell swap checks passed.');
}
