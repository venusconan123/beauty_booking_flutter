import 'package:flutter/material.dart';
import '../services/scheduling_service.dart';

class RosterEmployee {
  const RosterEmployee(this.id, this.name, this.salonId, {this.active = true});
  final String id, name, salonId;
  final bool active;
}

class RosterEntry {
  RosterEntry(this.id, Map<String, dynamic> data)
    : employeeId = data['employeeId'] as String,
      salonId = data['salonId'] as String,
      dateKey = data['dateKey'] as String,
      status = data['status'] as String,
      revision = data['revision'] as int? ?? 1,
      start = data['startMinute'] as int?,
      end = data['endMinute'] as int?,
      savedCode = data['shiftCode'] as String?;
  final String id, employeeId, salonId, dateKey, status;
  final int revision;
  final int? start, end;
  final String? savedCode;
  bool get active => status == 'scheduled' || status == 'off';
  String get code => status == 'off'
      ? 'OFF'
      : rosterShifts
                .where(
                  (s) => s.start == start && s.end == end && s.code != 'OFF',
                )
                .firstOrNull
                ?.code ??
            'T';
  String get hours => status == 'off'
      ? 'Đã xếp nghỉ'
      : '${rosterClock(start!)}–${rosterClock(end!)}';
  Map<String, dynamic> get version => {'id': id, 'revision': revision};
}

class RosterShift {
  const RosterShift(this.code, this.label, this.start, this.end, this.color);
  final String code, label;
  final int? start, end;
  final Color color;
  Map<String, dynamic> payload({int? customStart, int? customEnd}) =>
      code == 'OFF'
      ? {'kind': 'off'}
      : {
          'kind': 'work',
          'code': code,
          'startMinute': customStart ?? start,
          'endMinute': customEnd ?? end,
        };
}

const rosterShifts = [
  RosterShift('S', 'Sáng', 420, 900, Color(0xff00796b)),
  RosterShift('C', 'Chiều', 840, 1320, Color(0xff3949ab)),
  RosterShift('F', 'Cả ngày', 420, 1320, Color(0xffad5700)),
  RosterShift('HC', 'Hành chính', 540, 1020, Color(0xff1565c0)),
  RosterShift('T', 'Tùy chỉnh', null, null, Color(0xff7b1fa2)),
  RosterShift('OFF', 'Đã xếp nghỉ', null, null, Color(0xff616161)),
];
String rosterClock(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
String rosterDayName(int weekday) => weekday == 7 ? 'CN' : 'T${weekday + 1}';
String rosterCellKey(String employeeId, String date) => '$employeeId|$date';
List<DateTime> rosterDays(DateTime month) => List.generate(
  DateTime(month.year, month.month + 1, 0).day,
  (i) => DateTime(month.year, month.month, i + 1),
);
List<Map<String, dynamic>> rosterCells(
  Set<String> keys,
  List<RosterEntry> entries,
) => [
  for (final key in keys.toList()..sort())
    {
      'employeeId': key.split('|')[0],
      'dateKey': key.split('|')[1],
      'expected':
          entries
              .where(
                (e) =>
                    e.active && rosterCellKey(e.employeeId, e.dateKey) == key,
              )
              .map((e) => e.version)
              .toList()
            ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
    },
];
Set<String> rosterRepeat(
  Set<String> selected,
  DateTime month,
  Set<int> weekdays,
  String today,
) => {
  for (final employee in selected.map((k) => k.split('|')[0]).toSet())
    for (final date in SchedulingService.recurringDates(month, weekdays))
      if (date.compareTo(today) >= 0) rosterCellKey(employee, date),
};
