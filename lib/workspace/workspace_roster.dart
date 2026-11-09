part of 'workspace_app.dart';

class _RosterPage extends StatefulWidget {
  const _RosterPage({required this.store});
  final WorkspaceStore store;
  @override
  State<_RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<_RosterPage> {
  WorkspaceStore get s => widget.store;
  late DateTime month;
  late String branch;
  bool selecting = false, showAll = false;
  final selected = <String>{};
  final swap = <String>[];
  @override
  void initState() {
    super.initState();
    month = DateTime(s.today.year, s.today.month);
    branch = s.role == WorkspaceRole.staff ? s.staffBranch : 'salon_01';
  }

  List<RowData> get entries => s.shifts
      .where(
        (v) =>
            v['salonId'] == branch &&
            (v['day'] as String).startsWith(dayKey(month).substring(0, 7)) &&
            v['status'] != 'cancelled',
      )
      .toList();
  List<RowData> get people => s.people
      .where(
        (p) =>
            (s.role == WorkspaceRole.admin && showAll) ||
            p['salonId'] == branch ||
            entries.any((e) => e['employeeId'] == p['id']),
      )
      .toList();
  void _month(int offset) => setState(() {
    month = DateTime(month.year, month.month + offset);
    selected.clear();
  });
  @override
  Widget build(BuildContext context) {
    final admin = s.role == WorkspaceRole.admin;
    final gridEntries = [
      for (final row in entries)
        RosterEntry(row['id'] as String, {
          'employeeId': row['employeeId'],
          'salonId': row['salonId'],
          'dateKey': row['day'],
          'status': row['status'],
          'shiftCode': row['code'],
          'startMinute': row['start'],
          'endMinute': row['end'],
        }),
    ];
    return Padding(
      padding: const EdgeInsets.all(18),
      child: RosterViewport(
        controls: [
          _Heading(
            admin ? 'Bảng phân ca tháng' : 'Lịch làm cùng chi nhánh',
            admin
                ? 'Chọn ô để phân ca • Giữ tên và tiêu đề khi cuộn'
                : 'Chỉ xem • Liên hệ quản trị viên nếu cần điều chỉnh',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 285,
                child: DropdownButtonFormField<String>(
                  initialValue: branch,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chi nhánh'),
                  items: [
                    for (final salon in sampleSalons)
                      DropdownMenuItem(
                        value: salon.id,
                        child: Text(
                          salon.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: !admin
                      ? null
                      : (v) => setState(() {
                          branch = v!;
                          selected.clear();
                        }),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: () => _month(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${month.month.toString().padLeft(2, '0')} / ${month.year}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: () => _month(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() {
                  month = DateTime(s.today.year, s.today.month);
                  selected.clear();
                }),
                child: const Text('Tháng hiện tại'),
              ),
            ],
          ),
          _gap(14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final shift in rosterShifts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: shift.color),
                    const SizedBox(width: 5),
                    Text(
                      '${shift.code}: ${shift.label}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              const Text(
                'Ô trống: chưa xếp',
                style: TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
          _gap(12),
          if (admin)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Chọn nhiều ô'),
                  selected: selecting,
                  onSelected: (v) => setState(() {
                    selecting = v;
                    selected.clear();
                  }),
                ),
                FilledButton.icon(
                  onPressed: selected.isEmpty ? null : _assign,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text('Phân ca / OFF (${selected.length})'),
                ),
                FilterChip(
                  label: const Text('Nhân viên toàn hệ thống'),
                  selected: showAll,
                  onSelected: (v) => setState(() {
                    showAll = v;
                    selected.clear();
                  }),
                ),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => setState(selected.clear),
                  child: const Text('Bỏ chọn'),
                ),
                OutlinedButton.icon(
                  onPressed: selected.length == 2 ? _swapSelected : null,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Đổi A/B'),
                ),
                if (swap.isNotEmpty)
                  ActionChip(
                    label: Text('Đã giữ ${swap.length}/2 ca đổi'),
                    onPressed: () => setState(swap.clear),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              admin
                  ? 'Ô đã xếp: chạm xem chi tiết, giữ để chọn. Muốn đổi xuyên chi nhánh: giữ ca A trong chi tiết rồi chọn ca B.'
                  : 'Chạm ô để xem giờ làm hoặc ngày nghỉ. Cuộn ngang để xem đến cuối tháng.',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        ],
        grid: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: MonthlyRosterGrid(
            month: month,
            employees: [
              for (final p in people)
                RosterEmployee(
                  p['id'] as String,
                  p['name'] as String,
                  p['salonId'] as String,
                  active: p['active'] == true,
                ),
            ],
            entries: gridEntries,
            selected: selected,
            readOnly: !admin,
            selecting: selecting,
            today: dayKey(s.today),
            onSelect: (key) => setState(() {
              selected.contains(key) ? selected.remove(key) : selected.add(key);
            }),
            onDetails: _details,
          ),
        ),
      ),
    );
  }

  Future<void> _assign() async {
    var code = 'HC', repeat = false, start = 540, end = 1020;
    final weekdays = selected
        .map((k) => DateTime.parse(k.split('|')[1]).weekday)
        .toSet();
    final chosen = Set<String>.from(selected);
    String? error;
    final result = await showDialog<(Set<String>, String, int, int)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) {
          final cells = repeat
              ? {
                  for (final id in chosen.map((k) => k.split('|')[0]).toSet())
                    for (final d in rosterDays(month))
                      if (weekdays.contains(d.weekday) &&
                          dayKey(d).compareTo(dayKey(s.today)) >= 0)
                        '$id|${dayKey(d)}',
                }
              : chosen;
          return AlertDialog(
            insetPadding: const EdgeInsets.all(16),
            title: const Text('Phân ca / xếp nghỉ'),
            content: SizedBox(
              width: 490,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.branchName(branch),
                      style: const TextStyle(color: _muted),
                    ),
                    _gap(),
                    DropdownButtonFormField<String>(
                      initialValue: code,
                      decoration: const InputDecoration(
                        labelText: 'Ca làm / nghỉ',
                      ),
                      isExpanded: true,
                      items: [
                        for (final shift in rosterShifts)
                          DropdownMenuItem(
                            value: shift.code,
                            child: Text(
                              '${shift.code} • ${shift.label}${shift.start == null ? '' : ' ${clockText(shift.start!)}–${clockText(shift.end!)}'}',
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() => code = v!),
                    ),
                    if (code == 'T') ...[
                      _gap(),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 165,
                            child: DropdownButtonFormField<int>(
                              initialValue: start,
                              decoration: const InputDecoration(
                                labelText: 'Bắt đầu',
                              ),
                              items: [
                                for (var m = 420; m <= 1290; m += 30)
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(clockText(m)),
                                  ),
                              ],
                              onChanged: (v) => update(() => start = v!),
                            ),
                          ),
                          SizedBox(
                            width: 165,
                            child: DropdownButtonFormField<int>(
                              initialValue: end,
                              decoration: const InputDecoration(
                                labelText: 'Kết thúc',
                              ),
                              items: [
                                for (var m = 450; m <= 1320; m += 30)
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(clockText(m)),
                                  ),
                              ],
                              onChanged: (v) => update(() => end = v!),
                            ),
                          ),
                        ],
                      ),
                    ],
                    _gap(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lặp theo thứ trong tháng'),
                      subtitle: const Text(
                        'Áp dụng cho những nhân viên đang chọn; bỏ qua ngày đã qua.',
                      ),
                      value: repeat,
                      onChanged: (v) => update(() => repeat = v),
                    ),
                    if (repeat)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var d = 1; d <= 7; d++)
                            FilterChip(
                              label: Text(rosterDayName(d)),
                              selected: weekdays.contains(d),
                              onSelected: (v) => update(() {
                                v ? weekdays.add(d) : weekdays.remove(d);
                              }),
                            ),
                        ],
                      ),
                    _gap(),
                    Text(
                      '${cells.length} ô • Tối đa 100 ô/lần',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _gap(),
                    const Text(
                      'Thay ca/OFF hiện tại tại chi nhánh này và giữ lịch sử. OFF là nghỉ cả ngày. Toàn bộ lựa chọn chỉ được lưu nếu không có xung đột.',
                      style: TextStyle(color: _muted),
                    ),
                    if (error != null) ...[
                      _gap(),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () {
                  if (cells.isEmpty ||
                      cells.length > 100 ||
                      (code == 'T' && start >= end)) {
                    update(
                      () => error =
                          'Chọn 1–100 ô và giờ kết thúc sau giờ bắt đầu.',
                    );
                    return;
                  }
                  Navigator.pop(c, (cells, code, start, end));
                },
                child: const Text('Xem trước'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final preview = result.$1.toList()..sort();
    final accepted = await _confirm(
      context,
      'Xác nhận ${preview.length} ô → ${result.$2}',
      [
        for (final k in preview.take(16))
          '${s.person(k.split('|')[0])['name']} • ${shortDate(k.split('|')[1])}',
        if (preview.length > 16) '… và ${preview.length - 16} ô khác',
        '\nToàn bộ ô được kiểm tra trước khi lưu.',
      ].join('\n'),
      button: 'Lưu bảng phân ca',
    );
    if (!accepted || !mounted) return;
    try {
      s.assignRoster(
        branch: branch,
        cells: result.$1,
        code: result.$2,
        customStart: result.$3,
        customEnd: result.$4,
      );
      setState(() => selected.clear());
      _toast(context, 'Đã lưu bảng phân ca.');
    } catch (e) {
      _info(
        context,
        'Chưa lưu: xung đột lịch',
        e.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _details(
    RosterEmployee employee,
    String day,
    List<RosterEntry> rows,
  ) async {
    final admin = s.role == WorkspaceRole.admin;
    final editable = admin && day.compareTo(dayKey(s.today)) >= 0;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${employee.name}\n${shortDate(day)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.isEmpty)
              const Text('Chưa phân công. Ô trống không phải ngày nghỉ OFF.'),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.code} • ${row.hours}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      s.branchName(branch),
                      style: const TextStyle(color: _muted),
                    ),
                    if (editable)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(c);
                              if (await _confirm(
                                    context,
                                    'Hủy ca này?',
                                    'Lịch sử vẫn được giữ; ca có lịch khách sẽ bị chặn.',
                                  ) &&
                                  mounted) {
                                _mutate(
                                  context,
                                  () => s.cancelShift(row.id),
                                  'Đã hủy ca.',
                                );
                              }
                            },
                            child: const Text('Hủy ca'),
                          ),
                          if (row.status == 'scheduled')
                            TextButton(
                              onPressed: () {
                                Navigator.pop(c);
                                setState(() {
                                  if (!swap.contains(row.id)) swap.add(row.id);
                                });
                                if (swap.length == 2) {
                                  _performSwap(swap[0], swap[1]);
                                } else {
                                  _toast(
                                    context,
                                    'Đã giữ ca A. Chọn ca B của nhân viên khác; có thể cùng ngày hoặc khác ngày.',
                                  );
                                }
                              },
                              child: const Text('Giữ ca để đổi A/B'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            if (!admin)
              const Text(
                'Chỉ xem. Liên hệ admin khi cần thay đổi.',
                style: TextStyle(color: _muted),
              ),
          ],
        ),
        actions: [
          if (editable && employee.active)
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                setState(() {
                  selected.clear();
                  selected.add('${employee.id}|$day');
                });
                _assign();
              },
              child: const Text('Phân lại / OFF'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _swapSelected() {
    final rows = <RowData>[];
    for (final key in selected) {
      final parts = key.split('|');
      final matches = entries
          .where((r) => r['employeeId'] == parts[0] && r['day'] == parts[1])
          .toList();
      if (matches.length != 1 || matches.single['status'] != 'scheduled') {
        _toast(
          context,
          'Mỗi ô phải có đúng một ca làm. Không đổi ô trống, OFF hoặc nhiều ca.',
        );
        return;
      }
      rows.add(matches.single);
    }
    _performSwap(rows[0]['id'] as String, rows[1]['id'] as String);
  }

  Future<void> _performSwap(String aId, String bId) async {
    final preview = await showDialog<String>(
      context: context,
      builder: (c) {
        List<RowData>? plan;
        String? error;
        try {
          plan = s.previewSwap(aId, bId);
        } catch (e) {
          error = e.toString().replaceFirst('Bad state: ', '');
        }
        return AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: const Text('Đổi 2 ca đã chọn'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chỉ hoán đổi loại ca và giờ làm của hai ô đã chọn. Nhân viên, ngày, chi nhánh và tất cả ô khác giữ nguyên. Có thể đổi hai ca cùng ngày.',
                    style: TextStyle(color: _muted),
                  ),
                  _gap(),
                  if (plan != null)
                    for (final change in plan) ...[
                      Text(
                        '${s.person(change['employeeId'] as String)['name']} • ${shortDate(change['day'] as String)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        s.branchName(change['salonId'] as String),
                        style: const TextStyle(color: _muted),
                      ),
                      _gap(8),
                      Text(
                        'Hiện tại: ${change['code']} ${clockText(change['start'] as int)}–${clockText(change['end'] as int)}',
                      ),
                      Text(
                        'Sau đổi: ${change['nextCode']} ${clockText(change['nextStart'] as int)}–${clockText(change['nextEnd'] as int)}',
                        style: const TextStyle(color: Color(0xff1a7d68)),
                      ),
                      const Divider(height: 28),
                    ],
                  if (error != null)
                    Text(
                      error,
                      style: const TextStyle(color: Color(0xffb3261e)),
                    ),
                  if (plan != null &&
                      plan.every(
                        (r) =>
                            r['code'] == r['nextCode'] &&
                            r['start'] == r['nextStart'] &&
                            r['end'] == r['nextEnd'],
                      ))
                    const Text(
                      'Hai ca giống nhau nên kết quả không thay đổi; các ô C/OFF khác giữ nguyên.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  _gap(),
                  const Text(
                    'Vẫn kiểm tra lịch khách của cả hai nhân viên trong những ngày liên quan và trùng giờ tại mọi chi nhánh trước khi lưu.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: plan == null
                  ? null
                  : () => Navigator.pop(c, jsonEncode(plan)),
              child: const Text('Xác nhận đổi 2 ca'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (preview == null) {
      setState(swap.clear);
      return;
    }
    try {
      s.swapShifts(aId, bId, expected: preview);
      setState(() {
        selected.clear();
        swap.clear();
      });
      _toast(context, 'Đã đổi đúng 2 ca được chọn. Các ô khác giữ nguyên.');
    } catch (e) {
      setState(swap.clear);
      _info(
        context,
        'Không thể đổi ca',
        e.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }
}
