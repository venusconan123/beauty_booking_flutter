import 'package:flutter/material.dart';
import '../models/monthly_roster.dart';
import '../services/scheduling_service.dart';

/// Two synchronized vertical panes keep names frozen; only the day pane scrolls
/// horizontally. Header rows are outside both vertical lists.
class MonthlyRosterGrid extends StatefulWidget {
  const MonthlyRosterGrid({
    super.key,
    required this.month,
    required this.employees,
    required this.entries,
    required this.selected,
    required this.readOnly,
    required this.selecting,
    required this.onSelect,
    required this.onDetails,
    required this.today,
    this.enabled = true,
  });
  final DateTime month;
  final List<RosterEmployee> employees;
  final List<RosterEntry> entries;
  final Set<String> selected;
  final bool readOnly, selecting, enabled;
  final String today;
  final void Function(String) onSelect;
  final void Function(RosterEmployee, String, List<RosterEntry>) onDetails;
  @override
  State<MonthlyRosterGrid> createState() => _MonthlyRosterGridState();
}

class _MonthlyRosterGridState extends State<MonthlyRosterGrid> {
  final _names = ScrollController(),
      _days = ScrollController(),
      _horizontal = ScrollController();
  bool _syncing = false;
  @override
  void initState() {
    super.initState();
    _names.addListener(() => _sync(_names, _days));
    _days.addListener(() => _sync(_days, _names));
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients) return;
    _syncing = true;
    to.jumpTo(
      from.offset.clamp(
        to.position.minScrollExtent,
        to.position.maxScrollExtent,
      ),
    );
    _syncing = false;
  }

  @override
  void dispose() {
    _names.dispose();
    _days.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dates = rosterDays(widget.month);
    final indexed = <String, List<RosterEntry>>{};
    for (final entry in widget.entries.where((e) => e.active)) {
      indexed
          .putIfAbsent(rosterCellKey(entry.employeeId, entry.dateKey), () => [])
          .add(entry);
    }
    if (widget.employees.isEmpty) {
      return const Center(child: Text('Chưa có nhân viên tại chi nhánh này.'));
    }
    return LayoutBuilder(
      builder: (context, size) {
        final nameWidth = size.maxWidth < 500 ? 132.0 : 190.0;
        const dayWidth = 68.0, rowHeight = 76.0, headerHeight = 50.0;
        Widget header(String label, {bool weekend = false}) => Container(
          alignment: Alignment.center,
          height: headerHeight,
          decoration: BoxDecoration(
            color: weekend ? const Color(0xffffeee6) : const Color(0xffe8edf5),
            border: Border.all(color: const Color(0xffd4dbe5), width: .5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: nameWidth,
              child: Column(
                children: [
                  header('Nhân viên'),
                  Expanded(
                    child: ListView.builder(
                      key: const ValueKey('roster-names'),
                      controller: _names,
                      itemExtent: rowHeight,
                      itemCount: widget.employees.length,
                      itemBuilder: (context, i) {
                        final person = widget.employees[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xfff5f7fb),
                            border: Border.all(
                              color: const Color(0xffd4dbe5),
                              width: .5,
                            ),
                          ),
                          child: Tooltip(
                            message: person.name,
                            child: Text(
                              '${person.name}${person.active ? '' : ' (ngừng hoạt động)'}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  key: const ValueKey('roster-horizontal'),
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: dates.length * dayWidth,
                    height: size.maxHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final day in dates)
                              SizedBox(
                                width: dayWidth,
                                child: header(
                                  '${day.day.toString().padLeft(2, '0')}\n${rosterDayName(day.weekday)}',
                                  weekend: day.weekday >= 6,
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
                            key: const ValueKey('roster-days'),
                            controller: _days,
                            itemExtent: rowHeight,
                            itemCount: widget.employees.length,
                            itemBuilder: (context, i) {
                              final person = widget.employees[i];
                              return Row(
                                children: [
                                  for (final day in dates)
                                    Builder(
                                      builder: (context) {
                                        final date = SchedulingService.dateKey(
                                              day,
                                            ),
                                            key = rosterCellKey(
                                              person.id,
                                              SchedulingService.dateKey(day),
                                            );
                                        final rows = indexed[key] ?? [];
                                        final selected = widget.selected
                                            .contains(key);
                                        final editable =
                                            !widget.readOnly &&
                                            widget.enabled &&
                                            person.active &&
                                            date.compareTo(widget.today) >= 0;
                                        return Semantics(
                                          label:
                                              '${person.name}, $date, ${rows.isEmpty ? 'Chưa xếp' : rows.map((e) => '${e.code} ${e.hours}').join(', ')}',
                                          selected: selected,
                                          button: true,
                                          child: SizedBox(
                                            width: dayWidth,
                                            height: rowHeight,
                                            child: Material(
                                              color: selected
                                                  ? const Color(0xffdbeafe)
                                                  : (day.weekday >= 6
                                                        ? const Color(
                                                            0xfffff8f4,
                                                          )
                                                        : (i.isEven
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xfff5f7fb,
                                                                ))),
                                              child: InkWell(
                                                key: ValueKey('cell-$key'),
                                                onTap: !widget.enabled
                                                    ? null
                                                    : () {
                                                        if (editable &&
                                                            (widget.selecting ||
                                                                rows.isEmpty)) {
                                                          widget.onSelect(key);
                                                        } else {
                                                          widget.onDetails(
                                                            person,
                                                            date,
                                                            rows,
                                                          );
                                                        }
                                                      },
                                                onLongPress: editable
                                                    ? () => widget.onSelect(key)
                                                    : null,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: selected
                                                          ? const Color(
                                                              0xff2563eb,
                                                            )
                                                          : const Color(
                                                              0xffd4dbe5,
                                                            ),
                                                      width: selected ? 2 : .5,
                                                    ),
                                                  ),
                                                  child: rows.isEmpty
                                                      ? Center(
                                                          child: selected
                                                              ? const Icon(
                                                                  Icons.check,
                                                                  size: 18,
                                                                )
                                                              : null,
                                                        )
                                                      : Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            for (final row
                                                                in rows.take(2))
                                                              Tooltip(
                                                                message:
                                                                    '${row.code} • ${row.hours}',
                                                                child: Container(
                                                                  margin:
                                                                      const EdgeInsets.symmetric(
                                                                        vertical:
                                                                            1,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            4,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: rosterShifts
                                                                        .firstWhere(
                                                                          (s) =>
                                                                              s.code ==
                                                                              row.code,
                                                                        )
                                                                        .color,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    row.code,
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            if (rows.length > 2)
                                                              Text(
                                                                '+${rows.length - 2}',
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                    ),
                                                              ),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
