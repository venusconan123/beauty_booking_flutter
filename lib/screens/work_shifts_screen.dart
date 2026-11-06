import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/sample_salons.dart';
import '../models/staff_access.dart';
import '../models/monthly_roster.dart';
import '../services/scheduling_service.dart';
import '../widgets/monthly_roster_grid.dart';

class WorkShiftsScreen extends StatefulWidget {
  const WorkShiftsScreen({super.key, this.access});
  final StaffAccess? access;
  bool get isAdmin => access == null;
  @override
  State<WorkShiftsScreen> createState() => _WorkShiftsScreenState();
}

class _WorkShiftsScreenState extends State<WorkShiftsScreen> {
  final _service = SchedulingService();
  late final _employees = FirebaseFirestore.instance
      .collection('employees')
      .snapshots();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _shifts;
  late String _salonId;
  late DateTime _month;
  final _selected = <String>{};
  final _swapRows = <String, RosterEntry>{};
  List<RosterEntry> _entries = [];
  Map<String, RosterEmployee> _people = {};
  bool _busy = false, _selecting = false;
  SchedulingMutation? _pending;
  bool get _locked => _busy || _pending != null;
  String get _today => SchedulingService.dateKey(
    DateTime.now().toUtc().add(const Duration(hours: 7)),
  );
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    _month = DateTime(now.year, now.month);
    _salonId = widget.access?.salonId ?? 'salon_01';
    _watch();
  }

  void _watch() {
    _selected.clear();
    _entries = [];
    _shifts = FirebaseFirestore.instance
        .collection('work_shifts')
        .where('salonId', isEqualTo: _salonId)
        .where(
          'dateKey',
          isGreaterThanOrEqualTo: SchedulingService.dateKey(_month),
        )
        .where(
          'dateKey',
          isLessThan: SchedulingService.dateKey(
            DateTime(_month.year, _month.month + 1),
          ),
        )
        .snapshots(includeMetadataChanges: true);
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(
    String name,
    Map<String, dynamic> data, {
    SchedulingMutation? retry,
  }) async {
    if (_busy || (_pending != null && retry == null)) return;
    final mutation = retry ?? SchedulingMutation(name, data);
    setState(() {
      _busy = true;
      _pending = mutation;
    });
    try {
      await _service.call(mutation.name, mutation.data);
      if (mounted) {
        setState(() {
          _pending = null;
          _selected.clear();
          _swapRows.clear();
        });
      }
      _message('Đã lưu bảng phân ca.');
    } catch (error) {
      if (mounted && error is SchedulingRejectedException) {
        setState(() => _pending = null);
      }
      _message('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(Set<String> selected) async {
    if (_locked || !widget.isAdmin || selected.isEmpty) return;
    var code = 'HC';
    var repeat = false;
    var start = 540, end = 1020;
    final weekdays = selected
        .map((k) => DateTime.parse(k.split('|')[1]).weekday)
        .toSet();
    Map<String, dynamic>? preview;
    Map<String, String> before = {};
    String? error;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, change) {
          final shift = rosterShifts.firstWhere((s) => s.code == code);
          final targets = repeat
              ? rosterRepeat(selected, _month, weekdays, _today)
              : selected;
          return AlertDialog(
            title: Text(
              preview == null
                  ? 'Phân ca / xếp nghỉ'
                  : 'Xem trước ${targets.length} ô',
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preview == null) ...[
                      Text(
                        'Tháng ${_month.month}/${_month.year} • ${sampleSalons.firstWhere((s) => s.id == _salonId).name}',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: code,
                        decoration: const InputDecoration(
                          labelText: 'Ca làm / nghỉ',
                        ),
                        items: rosterShifts
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.code,
                                child: Text(
                                  '${s.code} • ${s.label}${s.start == null ? '' : ' ${rosterClock(s.start!)}–${rosterClock(s.end!)}'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => change(() => code = v!),
                      ),
                      if (code == 'T') ...[
                        DropdownButtonFormField<int>(
                          initialValue: start,
                          decoration: const InputDecoration(
                            labelText: 'Bắt đầu',
                          ),
                          items: [
                            for (var m = 420; m < 1320; m += 30)
                              DropdownMenuItem(
                                value: m,
                                child: Text(rosterClock(m)),
                              ),
                          ],
                          onChanged: (v) => change(() => start = v!),
                        ),
                        DropdownButtonFormField<int>(
                          initialValue: end,
                          decoration: const InputDecoration(
                            labelText: 'Kết thúc',
                          ),
                          items: [
                            for (var m = 450; m <= 1320; m += 30)
                              DropdownMenuItem(
                                value: m,
                                child: Text(rosterClock(m)),
                              ),
                          ],
                          onChanged: (v) => change(() => end = v!),
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Lặp theo thứ trong tháng'),
                        subtitle: const Text(
                          'Áp dụng cho nhân viên đã chọn; bỏ qua ngày đã qua.',
                        ),
                        value: repeat,
                        onChanged: (v) => change(() => repeat = v),
                      ),
                      if (repeat)
                        Wrap(
                          spacing: 4,
                          children: [
                            for (var i = 1; i <= 7; i++)
                              FilterChip(
                                label: Text(rosterDayName(i)),
                                selected: weekdays.contains(i),
                                onSelected: (v) => change(() {
                                  v ? weekdays.add(i) : weekdays.remove(i);
                                }),
                              ),
                          ],
                        ),
                      Text('${targets.length} ô • Tối đa 100 ô/lần'),
                      const SizedBox(height: 10),
                      const Text(
                        'Phân lại sẽ thay toàn bộ ca/OFF trong ô tại chi nhánh này và giữ lịch sử cũ. OFF là nghỉ cả ngày, không được có ca hoặc lịch hẹn còn hiệu lực ở chi nhánh khác.',
                      ),
                    ] else ...[
                      Text(
                        '${shift.code} • ${shift.label}${code == 'T' ? ' ${rosterClock(start)}–${rosterClock(end)}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Chỉ lưu khi toàn bộ ô hợp lệ. Backend kiểm tra lại lịch hẹn, ca xuyên chi nhánh và phiên bản dữ liệu.',
                      ),
                      const SizedBox(height: 10),
                      for (final cell
                          in (preview!['cells'] as List)
                              .cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${_people[cell['employeeId']]?.name ?? cell['employeeId']} • ${cell['dateKey']}\n${before[rosterCellKey(cell['employeeId'], cell['dateKey'])]} → $code',
                          ),
                        ),
                    ],
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (preview != null) {
                    change(() => preview = null);
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(preview == null ? 'Quay lại' : 'Chỉnh lựa chọn'),
              ),
              FilledButton(
                onPressed: () {
                  if (preview != null) {
                    Navigator.pop(context, preview);
                    return;
                  }
                  if (targets.isEmpty ||
                      targets.length > 100 ||
                      (code == 'T' && start >= end)) {
                    change(
                      () => error =
                          'Chọn 1–100 ô và giờ kết thúc sau giờ bắt đầu.',
                    );
                    return;
                  }
                  change(() {
                    error = null;
                    before = {
                      for (final key in targets)
                        key: _entries
                            .where(
                              (e) =>
                                  e.active &&
                                  rosterCellKey(e.employeeId, e.dateKey) == key,
                            )
                            .map((e) => '${e.code} ${e.hours}')
                            .join(', '),
                    };
                    before.updateAll((k, v) => v.isEmpty ? 'Chưa xếp' : v);
                    preview = {
                      'salonId': _salonId,
                      'cells': rosterCells(targets, _entries),
                      'shift': shift.payload(
                        customStart: code == 'T' ? start : null,
                        customEnd: code == 'T' ? end : null,
                      ),
                    };
                  });
                },
                child: Text(preview == null ? 'Xem trước' : 'Xác nhận lưu'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) await _run('saveRoster', result);
  }

  Future<void> _details(
    RosterEmployee person,
    String date,
    List<RosterEntry> rows,
  ) async {
    final editable =
        widget.isAdmin &&
        !_locked &&
        person.active &&
        date.compareTo(_today) >= 0;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${person.name} • $date'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rows.isEmpty)
                  const Text(
                    'Ô trống: chưa phân công, không phải ngày nghỉ OFF.',
                  ),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row.code} • ${row.hours}'),
                    subtitle: Text(
                      '${row.salonId} • Phiên bản ${row.revision}',
                    ),
                    trailing: editable
                        ? PopupMenuButton<String>(
                            onSelected: (value) =>
                                Navigator.pop(context, '$value:${row.id}'),
                            itemBuilder: (_) => [
                              if (row.status == 'scheduled')
                                const PopupMenuItem(
                                  value: 'swap',
                                  child: Text('Chọn đổi A/B'),
                                ),
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Text('Hủy phân công này'),
                              ),
                            ],
                          )
                        : null,
                  ),
                if (!editable)
                  const Text('Chỉ xem. Lịch sử ngày đã qua không được sửa.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (editable)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'assign'),
              child: const Text('Phân lại ô này'),
            ),
        ],
      ),
    );
    if (action == 'assign') {
      await _assign({rosterCellKey(person.id, date)});
    } else if (action?.startsWith('swap:') == true) {
      final row = rows.firstWhere((r) => r.id == action!.substring(5));
      setState(() {
        if (_swapRows.containsKey(row.id)) {
          _swapRows.remove(row.id);
        } else if (_swapRows.length < 2) {
          _swapRows[row.id] = row;
        }
      });
      _message(
        'Đã chọn ${_swapRows.length}/2 ca cho đổi A/B. Có thể chuyển chi nhánh để chọn ca thứ hai.',
      );
    } else if (action?.startsWith('cancel:') == true) {
      final row = rows.firstWhere((r) => r.id == action!.substring(7));
      if (await _confirm(
        'Hủy phân công?',
        'Giữ lịch sử. Backend sẽ từ chối nếu làm lịch hẹn còn hiệu lực nằm ngoài ca.',
      )) {
        await _run('cancelShift', {
          'shiftId': row.id,
          'expectedRevision': row.revision,
        });
      }
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _swap() async {
    final rows = _swapRows.values.toList();
    if (rows.length != 2 || _locked) return;
    final a = rows[0], b = rows[1];
    if (await _confirm(
      'Đổi A/B',
      '${_people[a.employeeId]?.name ?? a.employeeId} • ${a.dateKey} • ${a.salonId}\n↔ ${_people[b.employeeId]?.name ?? b.employeeId} • ${b.dateKey} • ${b.salonId}\n\nCả A và B phải không có lịch hẹn khách còn hiệu lực trong cả hai ngày tại mọi chi nhánh. Không được trùng ca hoặc OFF.',
    )) {
      await _run('swapShifts', {
        'shiftAId': a.id,
        'shiftBId': b.id,
        'revisionA': a.revision,
        'revisionB': b.revision,
      });
    }
  }

  Widget _filters() => Padding(
    padding: const EdgeInsets.all(12),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            initialValue: _salonId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Chi nhánh',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: sampleSalons
                .map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: !widget.isAdmin || _locked
                ? null
                : (v) => setState(() {
                    _salonId = v!;
                    _watch();
                  }),
          ),
        ),
        SizedBox(
          width: 108,
          child: DropdownButtonFormField<int>(
            initialValue: _month.month,
            decoration: const InputDecoration(
              labelText: 'Tháng',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text('$m')),
            ],
            onChanged: _locked
                ? null
                : (v) => setState(() {
                    _month = DateTime(_month.year, v!);
                    _watch();
                  }),
          ),
        ),
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<int>(
            initialValue: _month.year,
            decoration: const InputDecoration(
              labelText: 'Năm',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (var y = 1970; y <= DateTime.now().year + 10; y++)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: _locked
                ? null
                : (v) => setState(() {
                    _month = DateTime(v!, _month.month);
                    _watch();
                  }),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.isAdmin
        ? AppBar(title: const Text('Bảng phân ca tháng'))
        : null,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (!_busy && _pending != null)
          MaterialBanner(
            content: const Text(
              'Chưa xác nhận được kết quả. Thử lại dùng đúng mã cũ, không tạo phân công trùng.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    _run(_pending!.name, const {}, retry: _pending),
                child: const Text('Thử lại cùng yêu cầu'),
              ),
            ],
          ),
        _filters(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final shift in rosterShifts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 9, height: 9, color: shift.color),
                    const SizedBox(width: 4),
                    Text(
                      '${shift.code}: ${shift.start == null ? shift.label : '${rosterClock(shift.start!)}–${rosterClock(shift.end!)}'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              const Text('Ô trống: chưa xếp', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Chọn nhiều ô'),
                  selected: _selecting,
                  onSelected: _locked
                      ? null
                      : (v) => setState(() => _selecting = v),
                ),
                FilledButton.tonal(
                  onPressed: _locked || _selected.isEmpty
                      ? null
                      : () => _assign(Set.of(_selected)),
                  child: Text('Phân ca / OFF (${_selected.length})'),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: _locked ? null : () => setState(_selected.clear),
                    child: const Text('Bỏ chọn'),
                  ),
                if (_swapRows.isNotEmpty)
                  OutlinedButton(
                    onPressed: _swapRows.length == 2 && !_locked ? _swap : null,
                    child: Text('Đổi A/B (${_swapRows.length}/2)'),
                  ),
                if (_swapRows.isNotEmpty)
                  TextButton(
                    onPressed: _locked ? null : () => setState(_swapRows.clear),
                    child: const Text('Bỏ A/B'),
                  ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Lịch cùng chi nhánh • Chỉ xem',
              textAlign: TextAlign.center,
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            'Chạm ca để xem chi tiết • Cuộn ngang để xem các ngày còn lại',
            style: TextStyle(fontSize: 11),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _employees,
            builder: (context, employees) {
              if (employees.hasError) {
                return const Center(child: Text('Không thể tải nhân viên.'));
              }
              if (!employees.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              _people = {
                for (final doc in employees.data!.docs.where(
                  (d) => d.id != '_catalog',
                ))
                  doc.id: RosterEmployee(
                    doc.id,
                    doc.data()['name']?.toString() ?? doc.id,
                    doc.data()['salonId']?.toString() ?? '',
                    active: doc.data()['isActive'] != false,
                  ),
              };
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: ValueKey('$_salonId-$_month'),
                stream: _shifts,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Không thể tải bảng tháng.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  _entries = snapshot.data!.docs
                      .map((d) => RosterEntry(d.id, d.data()))
                      .where((e) => e.active)
                      .toList();
                  final assigned = _entries.map((e) => e.employeeId).toSet();
                  final people =
                      _people.values
                          .where(
                            (p) =>
                                p.salonId == _salonId ||
                                assigned.contains(p.id),
                          )
                          .toList()
                        ..sort((a, b) => a.name.compareTo(b.name));
                  return MonthlyRosterGrid(
                    month: _month,
                    employees: people,
                    entries: _entries,
                    selected: _selected,
                    readOnly: !widget.isAdmin,
                    selecting: _selecting,
                    enabled: !_locked,
                    today: _today,
                    onSelect: (key) => setState(() {
                      _selected.contains(key)
                          ? _selected.remove(key)
                          : _selected.add(key);
                    }),
                    onDetails: _details,
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
