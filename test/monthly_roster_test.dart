import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/models/monthly_roster.dart';
import 'package:men_hair_booking/widgets/monthly_roster_grid.dart';

void main() {
  testWidgets(
    'short preview scrolls controls while grid header and names stay visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RosterViewport(
              controls: const [SizedBox(height: 300, child: Text('Bộ lọc'))],
              grid: MonthlyRosterGrid(
                month: DateTime(2028, 2),
                employees: const [
                  RosterEmployee('a', 'Nhân viên khung thấp', 'salon_01'),
                ],
                entries: const [],
                selected: const {},
                readOnly: true,
                selecting: false,
                today: '2028-02-01',
                onSelect: (_) {},
                onDetails: (_, date, rows) {},
              ),
            ),
          ),
        ),
      );
      final headerY = tester.getTopLeft(find.text('01\nT3')).dy;
      await tester.dragFrom(const Offset(150, 150), const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('01\nT3')).dy, headerY);
      expect(find.text('Nhân viên khung thấp').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('calendar, legacy codes, OFF and immutable preview versions', () {
    expect(rosterDays(DateTime(2028, 2)).length, 29);
    final work = RosterEntry('old', {
      'employeeId': 'a',
      'salonId': 'salon_01',
      'dateKey': '2028-02-01',
      'status': 'scheduled',
      'startMinute': 540,
      'endMinute': 1020,
      'revision': 3,
    });
    final off = RosterEntry('off', {
      'employeeId': 'b',
      'salonId': 'salon_01',
      'dateKey': '2028-02-01',
      'status': 'off',
      'revision': 1,
    });
    expect(work.code, 'HC');
    expect(off.code, 'OFF');
    expect(off.hours, 'Đã xếp nghỉ');
    expect(rosterCells({'a|2028-02-01', 'b|2028-02-02'}, [work, off]), [
      {
        'employeeId': 'a',
        'dateKey': '2028-02-01',
        'expected': [
          {'id': 'old', 'revision': 3},
        ],
      },
      {'employeeId': 'b', 'dateKey': '2028-02-02', 'expected': []},
    ]);
    final recurrence = rosterRepeat(
      {'a|2028-02-01', 'b|2028-02-01'},
      DateTime(2028, 2),
      {2},
      '2028-02-08',
    );
    expect(recurrence.length, 8);
    expect(recurrence.contains('a|2028-02-29'), isTrue);
    expect(recurrence.contains('a|2028-02-01'), isFalse);
  });

  testWidgets(
    'phone grid keeps names and header fixed, synchronizes vertical panes, and reaches month end',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final people = List.generate(
        20,
        (i) => RosterEmployee('e$i', 'Nhân viên $i', 'salon_01'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: MonthlyRosterGrid(
                month: DateTime(2028, 2),
                employees: people,
                entries: const [],
                selected: const {},
                readOnly: false,
                selecting: true,
                today: '2028-02-01',
                onSelect: (_) {},
                onDetails: (_, date, rows) {},
              ),
            ),
          ),
        ),
      );
      final nameX = tester.getTopLeft(find.text('Nhân viên 0')).dx;
      final headerY = tester.getTopLeft(find.text('01\nT3')).dy;
      await tester.drag(
        find.byKey(const ValueKey('roster-horizontal')),
        const Offset(-1800, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Nhân viên 0')).dx, nameX);
      expect(find.text('29\nT3'), findsOneWidget);
      // The full-width day list's center can be outside the clipped viewport
      // after horizontal scrolling. Drag inside the visible day pane instead.
      await tester.dragFrom(
        tester.getRect(find.byKey(const ValueKey('roster-horizontal'))).center,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final names = tester
          .widget<ListView>(find.byKey(const ValueKey('roster-names')))
          .controller!;
      final days = tester
          .widget<ListView>(find.byKey(const ValueKey('roster-days')))
          .controller!;
      expect(names.offset, closeTo(days.offset, .1));
      expect(days.offset, greaterThan(0));
      expect(tester.getTopLeft(find.text('01\nT3')).dy, headerY);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('staff cells expose details only; work/OFF/blank stay distinct', (
    tester,
  ) async {
    var selections = 0, details = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyRosterGrid(
            month: DateTime(2028, 2),
            employees: const [RosterEmployee('a', 'A', 'salon_01')],
            entries: [
              RosterEntry('off', {
                'employeeId': 'a',
                'salonId': 'salon_01',
                'dateKey': '2028-02-01',
                'status': 'off',
                'revision': 1,
              }),
              RosterEntry('work', {
                'employeeId': 'a',
                'salonId': 'salon_01',
                'dateKey': '2028-02-02',
                'status': 'scheduled',
                'startMinute': 540,
                'endMinute': 1020,
                'revision': 1,
              }),
            ],
            selected: const {},
            readOnly: true,
            selecting: true,
            today: '2028-02-01',
            onSelect: (_) => selections++,
            onDetails: (_, date, rows) => details++,
          ),
        ),
      ),
    );
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('HC'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cell-a|2028-02-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-a|2028-02-03')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('cell-a|2028-02-03')));
    await tester.pumpAndSettle();
    expect(selections, 0);
    expect(details, 3);
    expect(tester.takeException(), isNull);
  });
}
