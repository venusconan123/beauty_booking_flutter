part of 'workspace_app.dart';

class _BookingPage extends StatefulWidget {
  const _BookingPage({required this.store, required this.onBook});
  final WorkspaceStore store;
  final VoidCallback onBook;
  @override
  State<_BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<_BookingPage> {
  String status = 'all', branch = 'all', search = '';
  DateTime? date;
  @override
  Widget build(BuildContext context) {
    final s = widget.store,
        admin = s.role == WorkspaceRole.admin,
        staff = s.role == WorkspaceRole.staff;
    final rows =
        s.bookings
            .where(
              (b) =>
                  (admin ||
                      (staff
                          ? b['employeeId'] == s.staffId
                          : b['customerId'] == 'customer-local')) &&
                  (status == 'all' || b['status'] == status) &&
                  (branch == 'all' || b['salonId'] == branch) &&
                  (date == null || b['day'] == dayKey(date!)) &&
                  '${b['id']} ${b['customer']} ${b['phone']}'
                      .toLowerCase()
                      .contains(search.toLowerCase()),
            )
            .toList()
          ..sort(
            (
              a,
              b,
            ) => '${b['day']}${(b['start'] as int).toString().padLeft(4, '0')}'
                .compareTo(
                  '${a['day']}${(a['start'] as int).toString().padLeft(4, '0')}',
                ),
          );
    return _page([
      if (staff) ...[
        _WorkspaceBanner(
          eyebrow: 'KHÔNG GIAN NHÂN VIÊN',
          title:
              'Chào ${s.employeeName.split(' ').last}, sẵn sàng cho hôm nay?',
          subtitle:
              '${s.branchName(s.staffBranch)} • Theo dõi lịch hẹn và chăm sóc từng khách hàng.',
          icon: Icons.content_cut,
        ),
        _gap(24),
      ],
      _Heading(
        staff
            ? 'Lịch hẹn được giao'
            : admin
            ? 'Quản lý lịch hẹn'
            : 'Lịch hẹn của tôi',
        staff
            ? 'Bắt đầu và hoàn thành lịch do bạn phụ trách'
            : 'Chi tiết cuộc hẹn, trạng thái phục vụ và thanh toán',
        action: !admin && !staff
            ? FilledButton.icon(
                onPressed: widget.onBook,
                icon: const Icon(Icons.add),
                label: const Text('Đặt lịch mới'),
              )
            : null,
      ),
      Panel(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 270,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Tìm tên / mã lịch / điện thoại',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Tất cả trạng thái'),
                  ),
                  for (final item in statusLabels.entries)
                    DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => status = v!),
              ),
            ),
            if (!staff)
              SizedBox(
                width: 265,
                child: DropdownButtonFormField<String>(
                  initialValue: branch,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chi nhánh'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Tất cả chi nhánh'),
                    ),
                    for (final b in sampleSalons)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => branch = v!),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date ?? s.today,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (d != null && mounted) setState(() => date = d);
              },
              icon: const Icon(Icons.date_range),
              label: Text(
                date == null ? 'Lọc theo ngày' : shortDate(dayKey(date!)),
              ),
            ),
            if (date != null)
              TextButton(
                onPressed: () => setState(() => date = null),
                child: const Text('Xóa ngày'),
              ),
          ],
        ),
      ),
      _gap(),
      Text('${rows.length} lịch hẹn', style: const TextStyle(color: _muted)),
      _gap(12),
      if (rows.isEmpty)
        const _Empty(
          icon: Icons.event_busy,
          title: 'Không có lịch hẹn phù hợp',
          text: 'Thử đổi bộ lọc hoặc tạo một lịch hẹn mới.',
        ),
      for (final b in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _BookingTile(store: s, booking: b),
        ),
    ]);
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.store, required this.booking});
  final WorkspaceStore store;
  final RowData booking;
  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBooking(context, store, b),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${shortDate(b['day'] as String)} • ${clockText(b['start'] as int)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _Badge(
                    statusLabels[b['status']] ?? '${b['status']}',
                    color: b['status'] == 'cancelled'
                        ? Colors.red.shade700
                        : b['status'] == 'in_service'
                        ? Colors.deepOrange.shade700
                        : const Color(0xff1a7d68),
                  ),
                ],
              ),
              _gap(12),
              Text(
                '${b['customer']}  •  ${store.person(b['employeeId'] as String)['name']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _gap(5),
              Text(
                store.branchName(b['salonId'] as String),
                style: const TextStyle(color: _muted),
              ),
              _gap(5),
              Text((b['items'] as List).map((s) => s['name']).join(' + ')),
              _gap(12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${b['id']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                  Text(
                    moneyText((b['total'] as int) - (b['discount'] as int)),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: _muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showBooking(
  BuildContext context,
  WorkspaceStore s,
  RowData b,
) => showDialog<void>(
  context: context,
  builder: (c) => StatefulBuilder(
    builder: (c, update) {
      final admin = s.role == WorkspaceRole.admin,
          worker = s.role == WorkspaceRole.staff;
      final due = (b['total'] as int) - (b['discount'] as int),
          paid = s.paidFor(b['id'] as String);
      Future<void> perform(
        String title,
        String text,
        VoidCallback action,
      ) async {
        if (!await _confirm(c, title, text) || !c.mounted) return;
        try {
          action();
          if (c.mounted) update(() {});
        } catch (e) {
          if (c.mounted) {
            _toast(c, e.toString().replaceFirst('Bad state: ', ''));
          }
        }
      }

      return AlertDialog(
        insetPadding: const EdgeInsets.all(18),
        title: const Text('Chi tiết lịch hẹn'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Badge(statusLabels[b['status']] ?? '${b['status']}'),
                _gap(),
                SelectableText(
                  '${b['id']}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                _gap(),
                Text(
                  '${b['customer']}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('${b['phone']}'),
                _gap(),
                _detailRow(
                  Icons.event,
                  '${shortDate(b['day'] as String)} • ${clockText(b['start'] as int)}–${clockText(b['end'] as int)}',
                ),
                _detailRow(
                  Icons.storefront,
                  s.branchName(b['salonId'] as String),
                ),
                _detailRow(
                  Icons.person_outline,
                  '${s.person(b['employeeId'] as String)['name']}',
                ),
                const Divider(height: 28),
                for (final line in b['items'] as List)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${line['name']}')),
                        Text(moneyText(line['price'] as num)),
                      ],
                    ),
                  ),
                if ((b['discount'] as int) > 0)
                  Row(
                    children: [
                      const Expanded(child: Text('Ưu đãi')),
                      Text('−${moneyText(b['discount'] as int)}'),
                    ],
                  ),
                const Divider(height: 28),
                _amount('Phải thu', due),
                _amount('Đã thu', paid),
                _amount('Còn lại', math.max(0, due - paid)),
                Text(
                  'Phương thức: ${b['payment']}',
                  style: const TextStyle(color: _muted),
                ),
                if ('${b['note']}'.isNotEmpty) ...[
                  _gap(),
                  Text('Ghi chú: ${b['note']}'),
                ],
                if (b['startedAt'] != null) ...[
                  _gap(),
                  const _Badge('Đã ghi nhận bắt đầu phục vụ'),
                ],
                if (b['status'] == 'completed') ...[
                  _gap(),
                  const Text(
                    'Bản chụp dịch vụ và giá lúc hoàn thành được giữ cố định.',
                    style: TextStyle(color: _muted),
                  ),
                ],
                if (b['status'] == 'cancelled' && paid > 0) ...[
                  _gap(),
                  const Text(
                    'Lịch đã hủy có tiền đã thu: cần đối soát hoàn tiền riêng.',
                    style: TextStyle(color: Colors.deepOrange),
                  ),
                ],
                _gap(),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if ((admin || worker) && b['status'] == 'confirmed')
                      FilledButton.icon(
                        onPressed: () => perform(
                          'Bắt đầu phục vụ?',
                          'Xác nhận khách đã đến. Thao tác được ghi lại trong lịch sử.',
                          () => s.startBooking(b['id'] as String),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Bắt đầu phục vụ'),
                      ),
                    if ((admin || worker) && b['status'] == 'in_service')
                      FilledButton.icon(
                        onPressed: () => perform(
                          'Hoàn thành dịch vụ?',
                          'Chốt dịch vụ và giá cho báo cáo. Bấm lại không tạo thêm lượt hoàn thành.',
                          () => s.completeBooking(b['id'] as String),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Hoàn thành'),
                      ),
                    if ((admin || s.role == WorkspaceRole.customer) &&
                        b['status'] == 'confirmed')
                      OutlinedButton(
                        onPressed: () => perform(
                          'Hủy lịch hẹn?',
                          'Giờ đặt sẽ được giải phóng. Lượt voucher đã sử dụng vẫn giữ nguyên.',
                          () => s.cancelBooking(b['id'] as String),
                        ),
                        child: const Text('Hủy lịch'),
                      ),
                    if (admin && b['status'] == 'completed' && paid < due)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final controller = TextEditingController(
                            text: '${due - paid}',
                          );
                          final amount = await showDialog<int>(
                            context: c,
                            builder: (d) => AlertDialog(
                              title: const Text('Ghi nhận thanh toán'),
                              content: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Số tiền nhận (đ)',
                                  helperText:
                                      'Còn phải thu: ${moneyText(due - paid)}',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d),
                                  child: const Text('Quay lại'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(
                                    d,
                                    int.tryParse(controller.text) ?? 0,
                                  ),
                                  child: const Text('Ghi nhận'),
                                ),
                              ],
                            ),
                          );
                          if (amount != null && c.mounted) {
                            try {
                              s.receivePayment(
                                b['id'] as String,
                                amount,
                                'receipt-${DateTime.now().microsecondsSinceEpoch}',
                              );
                              update(() {});
                            } catch (e) {
                              _toast(
                                c,
                                e.toString().replaceFirst('Bad state: ', ''),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Ghi thu'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Đóng'),
          ),
        ],
      );
    },
  ),
);
Widget _detailRow(IconData icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: _muted),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  ),
);
Widget _amount(String label, int amount) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        moneyText(amount),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  ),
);

class _BookingWizard extends StatefulWidget {
  const _BookingWizard({required this.store, this.initialBranch = 'salon_01'});
  final WorkspaceStore store;
  final String initialBranch;
  @override
  State<_BookingWizard> createState() => _BookingWizardState();
}

class _BookingWizardState extends State<_BookingWizard> {
  WorkspaceStore get s => widget.store;
  int step = 0;
  String branch = 'salon_01', employee = 'staff-1';
  late DateTime date;
  int? minute;
  final selected = <String>{};
  final voucher = TextEditingController(), note = TextEditingController();
  late final TextEditingController name, phone;
  late final String requestId;
  String? error;
  @override
  void initState() {
    super.initState();
    branch = widget.initialBranch;
    employee =
        s.people.firstWhere(
              (p) => p['active'] == true && p['salonId'] == branch,
              orElse: () => s.people.firstWhere((p) => p['active'] == true),
            )['id']
            as String;
    date = s.today.add(const Duration(days: 1));
    name = TextEditingController(text: s.customerName);
    phone = TextEditingController(text: s.customerPhone);
    requestId = 'request-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    for (final c in [voucher, note, name, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  List<RowData> get items =>
      s.services.where((v) => selected.contains(v['id'])).toList();
  int get total => items.fold<int>(0, (n, v) => n + (v['price'] as int));
  int get duration => s.durationOf(items);
  @override
  Widget build(BuildContext context) {
    const steps = ['Chi nhánh', 'Dịch vụ', 'Thợ & thời gian', 'Xác nhận'];
    final staff = s.people.where((p) => p['active'] == true).toList();
    final slots = s.availableSlots(employee, branch, dayKey(date), duration);
    final promo = s.vouchers
        .where(
          (v) =>
              v['id'] == voucher.text.trim().toUpperCase() &&
              v['active'] == true &&
              total >= v['minimum'] &&
              v['used'] < v['limit'],
        )
        .firstOrNull;
    final discount = promo == null
        ? 0
        : total * (promo['percent'] as int) ~/ 100;
    Widget content = switch (step) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            'Chọn nơi bạn muốn đến',
            'Ba không gian, cùng một chất lượng',
          ),
          for (final salon in sampleSalons)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: branch == salon.id
                    ? const Color(0xfffff5e3)
                    : Colors.white,
                child: ListTile(
                  selected: branch == salon.id,
                  leading: Icon(
                    branch == salon.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => setState(() {
                    branch = salon.id;
                    employee =
                        s.people.firstWhere(
                              (p) =>
                                  p['salonId'] == branch && p['active'] == true,
                              orElse: () => staff.first,
                            )['id']
                            as String;
                    minute = null;
                  }),
                  title: Text(
                    salon.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${salon.address}\n07:00–22:00 • ★ ${salon.rating}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Dịch vụ & chăm sóc', 'Chọn một hoặc nhiều dịch vụ'),
          for (final service in s.services.where((v) => v['active'] == true))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: CheckboxListTile(
                  value: selected.contains(service['id']),
                  onChanged: (v) => setState(() {
                    v == true
                        ? selected.add(service['id'] as String)
                        : selected.remove(service['id']);
                    minute = null;
                  }),
                  title: Text(
                    '${service['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${service['duration']} phút • ${service['description']}',
                  ),
                  secondary: Text(
                    moneyText(service['price'] as int),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            'Chọn thợ & giờ hẹn',
            'Chỉ hiện giờ đủ thời lượng trong ca làm và chưa có khách',
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('employee-$branch'),
            initialValue: employee,
            decoration: const InputDecoration(labelText: 'Chuyên viên'),
            isExpanded: true,
            items: [
              for (final p in staff)
                DropdownMenuItem(
                  value: p['id'] as String,
                  child: Text(
                    '${p['name']} • CN ${'${p['salonId']}'.substring(6)}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              employee = v!;
              minute = null;
            }),
          ),
          _gap(),
          OutlinedButton.icon(
            onPressed: () async {
              final next = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: s.today,
                lastDate: s.today.add(const Duration(days: 90)),
              );
              if (next != null && mounted) {
                setState(() {
                  date = next;
                  minute = null;
                });
              }
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(shortDate(dayKey(date))),
          ),
          _gap(),
          if (slots.isEmpty)
            const _Empty(
              icon: Icons.event_busy,
              title: 'Chưa có giờ phù hợp',
              text:
                  'Thợ có thể chưa được xếp ca tại chi nhánh này. Thử ngày hoặc thợ khác.',
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final m in slots)
                ChoiceChip(
                  label: Text(clockText(m)),
                  selected: minute == m,
                  onSelected: (_) => setState(() => minute = m),
                ),
            ],
          ),
          _gap(),
          Text(
            'Thời gian giữ chỗ: $duration phút (làm tròn theo khung 30 phút).',
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            'Sẵn sàng cho diện mạo mới?',
            'Kiểm tra thông tin trước khi xác nhận',
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
          ),
          _gap(),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
          _gap(),
          TextField(
            controller: voucher,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Mã ưu đãi (không bắt buộc)',
              helperText: 'Thử WELCOME10 cho đơn từ 100.000đ',
              suffixIcon: IconButton(
                tooltip: 'Kiểm tra mã',
                onPressed: () {
                  setState(() {});
                  _toast(
                    context,
                    promo == null
                        ? 'Mã không hợp lệ hoặc chưa đủ điều kiện.'
                        : 'Đã áp dụng ưu đãi.',
                  );
                },
                icon: const Icon(Icons.check),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          _gap(),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho chuyên viên',
            ),
          ),
          _gap(),
          const Panel(
            child: Row(
              children: [
                Icon(Icons.payments_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thanh toán tại salon\nBản duyệt này không thu tiền hoặc gọi VNPay.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    };
    final summary = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LỊCH HẸN CỦA BẠN',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
          _gap(),
          Text(
            s.branchName(branch),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          _gap(),
          Text('${s.person(employee)['name']}'),
          Text(
            '${shortDate(dayKey(date))}${minute == null ? '' : ' • ${clockText(minute!)}'}',
          ),
          _gap(),
          if (items.isEmpty)
            const Text('Chưa chọn dịch vụ', style: TextStyle(color: _muted)),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text('${item['name']}')),
                  Text(moneyText(item['price'] as int)),
                ],
              ),
            ),
          const Divider(height: 28),
          _amount('Tạm tính', total),
          if (discount > 0) _amount('Giảm giá', -discount),
          _amount('Tổng thanh toán', total - discount),
          _gap(8),
          const Text(
            'Giá được kiểm tra lại khi xác nhận. Giờ có thể thay đổi nếu khách khác vừa đặt.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch trải nghiệm')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      ActionChip(
                        avatar: CircleAvatar(
                          radius: 12,
                          backgroundColor: step == i ? _gold : _line,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        label: Text(steps[i]),
                        onPressed: i < step
                            ? () => setState(() {
                                step = i;
                                error = null;
                              })
                            : null,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= 850
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: content),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: summary),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [content, _gap(24), summary],
                          ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      if (step > 0)
                        TextButton(
                          onPressed: () => setState(() {
                            step--;
                            error = null;
                          }),
                          child: const Text('Quay lại'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(
                          step == 3
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                        ),
                        label: Text(
                          step == 3 ? 'Xác nhận đặt lịch' : 'Tiếp tục',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (step == 1 && selected.isEmpty) {
      setState(() => error = 'Vui lòng chọn ít nhất một dịch vụ.');
      return;
    }
    if (step == 2 && minute == null) {
      setState(() => error = 'Vui lòng chọn giờ hẹn.');
      return;
    }
    if (step < 3) {
      setState(() {
        step++;
        error = null;
      });
      return;
    }
    try {
      s.saveProfile(name.text, phone.text);
      final id = s.createBooking(
        requestId: requestId,
        employee: employee,
        branch: branch,
        day: dayKey(date),
        start: minute!,
        serviceIds: selected,
        voucher: voucher.text,
        note: note.text,
      );
      if (!mounted) return;
      await _info(
        context,
        'Đặt lịch thành công',
        'Mã lịch: $id\n${shortDate(dayKey(date))} • ${clockText(minute!)}\nBạn có thể xem và hủy trong Lịch hẹn của tôi. Đây là lịch cục bộ để duyệt giao diện.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    }
  }
}

class _ReportsPage extends StatefulWidget {
  const _ReportsPage({required this.store});
  final WorkspaceStore store;
  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  ReportPeriod period = ReportPeriod.month;
  late DateTime anchor;
  String branch = 'all', employee = 'all';
  @override
  void initState() {
    super.initState();
    anchor = widget.store.today;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store, staff = s.role == WorkspaceRole.staff;
    final rows = s.reportRows(
      period,
      anchor,
      branch: branch == 'all' ? null : branch,
      employee: employee == 'all' ? null : employee,
    );
    final value = rows.fold<int>(0, (n, c) => n + (c['due'] as int));
    final paid = rows.fold<int>(
      0,
      (n, c) => n + s.paidFor(c['bookingId'] as String),
    );
    final services = rows.fold<int>(
      0,
      (n, c) => n + (c['items'] as List).length,
    );
    final grouped = <String, int>{};
    for (final r in rows) {
      grouped.update(
        r['employeeId'] as String,
        (v) => v + (r['due'] as int),
        ifAbsent: () => r['due'] as int,
      );
    }
    final maxValue = grouped.values.fold<int>(1, math.max);
    const labels = {
      ReportPeriod.day: 'Ngày',
      ReportPeriod.week: 'Tuần',
      ReportPeriod.month: 'Tháng',
      ReportPeriod.year: 'Năm',
    };
    return _page([
      _Heading(
        staff ? 'Hiệu suất của bạn' : 'Báo cáo hoạt động',
        'Theo thời điểm hoàn thành • Múi giờ Việt Nam',
        action: OutlinedButton.icon(
          onPressed: () async {
            final csv = [
              'Mã lịch,Ngày hoàn thành,Nhân viên,Giá trị dịch vụ,Đã thu,Còn lại',
              for (final c in rows)
                '${c['bookingId']},${c['day']},${s.person(c['employeeId'] as String)['name']},${c['due']},${s.paidFor(c['bookingId'] as String)},${(c['due'] as int) - s.paidFor(c['bookingId'] as String)}',
            ].join('\n');
            await Clipboard.setData(ClipboardData(text: csv));
            if (context.mounted) {
              _toast(
                context,
                'Đã sao chép báo cáo CSV. Dán vào bảng tính để lưu.',
              );
            }
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Sao chép báo cáo'),
        ),
      ),
      Panel(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final p in ReportPeriod.values)
                  ChoiceChip(
                    label: Text(labels[p]!),
                    selected: period == p,
                    onSelected: (_) => setState(() => period = p),
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: anchor,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (d != null && mounted) setState(() => anchor = d);
              },
              icon: const Icon(Icons.date_range),
              label: Text(shortDate(dayKey(anchor))),
            ),
            if (!staff) ...[
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: branch,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chi nhánh'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Toàn hệ thống'),
                    ),
                    for (final b in sampleSalons)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => branch = v!),
                ),
              ),
              SizedBox(
                width: 225,
                child: DropdownButtonFormField<String>(
                  initialValue: employee,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nhân viên'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Tất cả nhân viên'),
                    ),
                    for (final p in s.people)
                      DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text('${p['name']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => employee = v!),
                ),
              ),
            ],
          ],
        ),
      ),
      _gap(),
      _Metrics([
        ('Lịch hoàn thành', '${rows.length}', Icons.task_alt),
        ('Lượt dịch vụ', '$services', Icons.content_cut),
        ('Giá trị dịch vụ', moneyText(value), Icons.payments_outlined),
        ('Đã thu', moneyText(paid), Icons.account_balance_wallet_outlined),
      ]),
      _gap(),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Công nợ còn lại',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  moneyText(math.max(0, value - paid)),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xffa56519),
                  ),
                ),
              ],
            ),
            _gap(10),
            const Text(
              'Đã thu và công nợ thuộc những lịch hoàn thành trong kỳ, đối soát tại thời điểm xem. Đây không phải dòng tiền nhận trong kỳ. Một lịch cắt + gội = 1 lịch, 2 lượt dịch vụ. Tuần từ thứ Hai đến Chủ nhật.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
      _gap(),
      if (rows.isEmpty)
        const _Empty(
          icon: Icons.insights,
          title: 'Chưa có lượt hoàn thành trong kỳ',
          text: 'Thử kỳ khác hoặc hoàn thành một lịch được giao.',
        ),
      if (rows.isNotEmpty)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giá trị dịch vụ theo nhân viên',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              _gap(),
              for (final item in grouped.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${s.person(item.key)['name']}'),
                          ),
                          Text(moneyText(item.value)),
                        ],
                      ),
                      _gap(7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: item.value / maxValue,
                          minHeight: 9,
                          color: _gold,
                          backgroundColor: _paper,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      _gap(),
      for (final c in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shortDate(c['day'] as String)} • ${s.person(c['employeeId'] as String)['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _gap(6),
                Text((c['items'] as List).map((i) => i['name']).join(' + ')),
                _gap(8),
                _amount('Giá trị hoàn thành', c['due'] as int),
                Text(
                  'Đã thu ${moneyText(s.paidFor(c['bookingId'] as String))}',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}
