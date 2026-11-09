// Run with dart --enable-asserts tools/check_workspace_store.dart.
// Pure Dart: no Flutter engine, Firebase, Emulator or account required.
import 'dart:convert';
// ignore_for_file: avoid_print
import 'package:men_hair_booking/workspace/workspace_store.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError('FAILED: $message');
  print('PASS: $message');
}

void rejects(void Function() action, String message) {
  var denied = false;
  try {
    action();
  } on StateError {
    denied = true;
  }
  check(denied, message);
}

WorkspaceStore fresh() =>
    WorkspaceStore(today: DateTime(2026, 11, 9), restore: false);
void main() {
  final s = fresh();
  final day = dayKey(s.today.add(const Duration(days: 1)));
  final before = s.bookings.length;
  final slot = s.availableSlots('staff-1', 'salon_01', day, 60).first;
  final id = s.createBooking(
    requestId: 'unique',
    employee: 'staff-1',
    branch: 'salon_01',
    day: day,
    start: slot,
    serviceIds: {'service_combo_10'},
    voucher: 'welcome10',
  );
  final b = s.bookings.firstWhere((b) => b['id'] == id);
  check(
    b['discount'] == 15000 && s.bookings.length == before + 1,
    'booking applies authoritative local catalog and voucher',
  );
  check(
    s.createBooking(
              requestId: 'unique',
              employee: 'staff-1',
              branch: 'salon_01',
              day: day,
              start: slot,
              serviceIds: {'service_combo_10'},
              voucher: 'welcome10',
            ) ==
            id &&
        s.bookings.length == before + 1,
    'same request returns same booking, voucher consumed once',
  );
  rejects(
    () => s.createBooking(
      requestId: 'other',
      employee: 'staff-1',
      branch: 'salon_01',
      day: day,
      start: slot,
      serviceIds: {'service_combo_10'},
    ),
    'overlapping booking rejected',
  );
  s.cancelBooking(id);
  check(
    s.availableSlots('staff-1', 'salon_01', day, 60).contains(slot) &&
        s.vouchers.first['used'] == 1,
    'cancellation releases slot without restoring consumed voucher',
  );
  rejects(
    () => s.assignRoster(
      branch: 'salon_01',
      cells: {'staff-1|$day'},
      code: 'OFF',
    ),
    'customer cannot assign roster',
  );
  s.switchRole(WorkspaceRole.staff, employee: 'staff-2');
  rejects(
    () => s.startBooking('MHB-1100'),
    'staff cannot start another employee booking',
  );
  s.switchRole(WorkspaceRole.staff, employee: 'staff-1');
  s.startBooking('MHB-1100');
  s.completeBooking('MHB-1100');
  s.completeBooking('MHB-1100');
  check(
    s.completions.where((c) => c['bookingId'] == 'MHB-1100').length == 1,
    'completion is idempotent',
  );
  final report = s.reportRows(ReportPeriod.day, s.today);
  check(
    report.length == 1 && report.single['items'].length == 2,
    'one completed appointment yields two service visits',
  );
  s.switchRole(WorkspaceRole.admin);
  s.receivePayment('MHB-1100', 50000, 'receipt-unique');
  s.receivePayment('MHB-1100', 50000, 'receipt-unique');
  check(s.paidFor('MHB-1100') == 50000, 'payment retry never doubles receipts');
  rejects(
    () => s.receivePayment('MHB-1100', 1000000, 'too-large'),
    'payment cannot exceed outstanding balance',
  );
  final snap = s.completions.firstWhere((c) => c['bookingId'] == 'MHB-1100');
  s.saveService({...s.services[1], 'price': 999999});
  check(
    snap['due'] == 110000 && (snap['items'] as List).first['price'] == 80000,
    'catalog changes preserve completion snapshot',
  );
  final today = dayKey(s.today),
      shift = s.activeShifts('staff-2', today).single;
  final originalShifts = s.shifts.length;
  rejects(
    () => s.assignRoster(
      branch: 'salon_01',
      cells: {'staff-1|$day', 'staff-2|$today'},
      code: 'OFF',
    ),
    'bulk assignment rejected when any cell contains a live booking',
  );
  check(
    s.shifts.length == originalShifts && shift['status'] == 'scheduled',
    'bulk rejection is atomic',
  );
  rejects(
    () =>
        s.assignRoster(branch: 'salon_02', cells: {'staff-1|$day'}, code: 'F'),
    'cross-branch overlap rejected',
  );
  s.assignRoster(branch: 'salon_01', cells: {'staff-1|$day'}, code: 'OFF');
  check(
    s.activeShifts('staff-1', day).single['status'] == 'off' &&
        s.availableSlots('staff-1', 'salon_01', day, 30).isEmpty,
    'OFF blocks availability and preserves old shift history',
  );
  final aDay = dayKey(s.today.add(const Duration(days: 3))),
      bDay = dayKey(s.today.add(const Duration(days: 5)));
  final a = s.activeShifts('staff-1', aDay).single,
      otherAtA = s.activeShifts('staff-2', aDay).single;
  final bShift = s.activeShifts('staff-2', bDay).single,
      otherAtB = s.activeShifts('staff-1', bDay).single;
  final companions = jsonEncode([otherAtA, otherAtB]);
  a['code'] = 'S';
  a['start'] = 420;
  a['end'] = 900;
  bShift['code'] = 'C';
  bShift['start'] = 840;
  bShift['end'] = 1320;
  s.swapShifts(a['id'] as String, bShift['id'] as String);
  check(
    companions == jsonEncode([otherAtA, otherAtB]),
    'swap preserves both unselected companion cells',
  );
  check(
    a['employeeId'] == 'staff-1' &&
        bShift['employeeId'] == 'staff-2' &&
        a['code'] == 'C' &&
        bShift['code'] == 'S',
    'two-cell swap changes hours/codes and keeps employee/date positions',
  );
  s.savePerson({...s.person('staff-1'), 'active': false});
  s.switchRole(WorkspaceRole.staff, employee: 'staff-1');
  rejects(
    () => s.startBooking('MHB-1100'),
    'deactivated staff blocked in an already-open session',
  );
  check(
    s.reportRows(ReportPeriod.month, s.today, employee: 'staff-2').isEmpty,
    'deactivated staff cannot read reports',
  );
  final weekStore = fresh();
  final oldCompletion = weekStore.completions.first;
  oldCompletion['day'] = '2026-11-08';
  check(
    !weekStore
        .reportRows(ReportPeriod.week, DateTime(2026, 11, 9))
        .contains(oldCompletion),
    'Monday-start week excludes preceding Sunday',
  );
  check(
    weekStore
        .reportRows(ReportPeriod.week, DateTime(2026, 11, 8))
        .contains(oldCompletion),
    'Sunday belongs to preceding week',
  );
  final dump = jsonDecode(s.exportJson()) as Map;
  check(
    dump['version'] == 1 &&
        dump['receipts'].length == s.receipts.length &&
        !dump.containsKey('password'),
    'JSON export includes review state and never passwords',
  );
  final restored = WorkspaceStore(today: s.today, snapshot: s.exportJson());
  check(
    restored.bookings.length == s.bookings.length &&
        restored.paidFor('MHB-1100') == 50000,
    'serialized UI state restores bookings and receipts',
  );
  final personal = fresh();
  personal.switchRole(WorkspaceRole.staff, employee: 'staff-1');
  check(
    personal
        .reportRows(ReportPeriod.month, personal.today, employee: 'staff-2')
        .every((r) => r['employeeId'] == 'staff-1'),
    'staff reports cannot be switched to another employee',
  );
  print('All UI domain checks passed.');
}
