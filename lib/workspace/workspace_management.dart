part of 'workspace_app.dart';

class _PeoplePage extends StatefulWidget {
  const _PeoplePage({required this.store});
  final WorkspaceStore store;
  @override
  State<_PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<_PeoplePage> {
  String query = '', branch = 'all';
  Future<void> _edit([RowData? person]) async {
    final p =
        person ??
        <String, dynamic>{
          'id': '',
          'name': '',
          'email': '',
          'salonId': 'salon_01',
          'active': true,
        };
    final values = await _recordForm(
      context,
      person == null ? 'Thêm nhân viên' : 'Hồ sơ nhân viên',
      p,
      [('name', 'Họ và tên', false), ('email', 'Email liên kết', false)],
      branch: true,
      active: true,
      note:
          'Bản duyệt chỉ lưu hồ sơ cục bộ. Liên kết UID và tạo tài khoản Auth sẽ thực hiện khi nối database.',
    );
    if (values != null && mounted) {
      _mutate(
        context,
        () => widget.store.savePerson(values),
        'Đã lưu hồ sơ nhân viên.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final rows = s.people.where(
      (p) =>
          (branch == 'all' || p['salonId'] == branch) &&
          '${p['name']} ${p['email']}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
    );
    return _page([
      _Heading(
        'Đội ngũ chuyên viên',
        'Quản lý hồ sơ, chi nhánh chính và trạng thái truy cập',
        action: FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Thêm nhân viên'),
        ),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 290,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm nhân viên',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          SizedBox(
            width: 290,
            child: DropdownButtonFormField<String>(
              initialValue: branch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chi nhánh chính'),
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
        ],
      ),
      _gap(),
      if (rows.isEmpty)
        const _Empty(
          icon: Icons.groups_outlined,
          title: 'Không tìm thấy nhân viên',
          text: 'Thử tên hoặc chi nhánh khác.',
        ),
      for (final p in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xfff3e7cf),
                      child: Text(
                        '${p['name']}'.trim().isEmpty
                            ? '?'
                            : '${p['name']}'.trim().split(' ').last[0],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['name']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${p['email']}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa hồ sơ',
                      onPressed: () => _edit(p),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                _gap(),
                Text(s.branchName(p['salonId'] as String)),
                _gap(),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Badge(
                      p['active'] == true
                          ? 'Đang hoạt động'
                          : 'Đã ngừng hoạt động',
                      color: p['active'] == true
                          ? const Color(0xff1a7d68)
                          : _muted,
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await _confirm(
                              context,
                              p['active'] == true
                                  ? 'Ngừng hoạt động nhân viên?'
                                  : 'Mở lại nhân viên?',
                              'Hồ sơ, ca và lịch hẹn cũ được giữ. Nhân viên ngừng hoạt động không được xử lý lịch hoặc nhận lịch mới.',
                            ) &&
                            context.mounted) {
                          _mutate(
                            context,
                            () => s.savePerson({
                              ...p,
                              'active': p['active'] != true,
                            }),
                            'Đã cập nhật trạng thái.',
                          );
                        }
                      },
                      child: Text(
                        p['active'] == true
                            ? 'Ngừng hoạt động'
                            : 'Mở hoạt động',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

class _ServicesPage extends StatelessWidget {
  const _ServicesPage({required this.store});
  final WorkspaceStore store;
  Future<void> _edit(BuildContext context, [RowData? item]) async {
    final initial =
        item ??
        <String, dynamic>{
          'id': '',
          'name': '',
          'price': 80000,
          'duration': 30,
          'description': '',
          'active': true,
        };
    final values = await _recordForm(
      context,
      item == null ? 'Thêm dịch vụ' : 'Chỉnh sửa dịch vụ',
      initial,
      [
        ('name', 'Tên dịch vụ', false),
        ('price', 'Giá niêm yết (đ)', true),
        ('duration', 'Thời lượng (phút)', true),
        ('description', 'Mô tả', false),
      ],
      active: true,
      note:
          'Thay giá không làm thay đổi giá đã chốt trong lịch hẹn và bản chụp hoàn thành.',
    );
    if (values != null && context.mounted) {
      _mutate(context, () => store.saveService(values), 'Đã lưu dịch vụ.');
    }
  }

  @override
  Widget build(BuildContext context) => _page([
    _Heading(
      'Danh mục dịch vụ',
      'Giá rõ ràng • Lịch sử giá được giữ trong từng lịch hẹn',
      action: FilledButton.icon(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm dịch vụ'),
      ),
    ),
    for (final service in store.services)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.content_cut, color: _gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${service['name']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa dịch vụ',
                    onPressed: () => _edit(context, service),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              _gap(8),
              Text(
                '${service['description']}',
                style: const TextStyle(color: _muted),
              ),
              _gap(),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    moneyText(service['price'] as int),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('${service['duration']} phút'),
                  _Badge(
                    service['active'] == true ? 'Đang cung cấp' : 'Tạm ngưng',
                    color: service['active'] == true
                        ? const Color(0xff1a7d68)
                        : _muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
  ]);
}

class _VouchersPage extends StatelessWidget {
  const _VouchersPage({required this.store});
  final WorkspaceStore store;
  Future<void> _edit(BuildContext context, [RowData? v]) async {
    final initial =
        v ??
        <String, dynamic>{
          'id': '',
          'name': '',
          'percent': 10,
          'minimum': 100000,
          'limit': 30,
          'used': 0,
          'newVoucher': true,
          'active': true,
        };
    final values = await _recordForm(
      context,
      v == null ? 'Tạo voucher' : 'Chỉnh sửa voucher',
      initial,
      [
        if (v == null) ('id', 'Mã voucher (viết hoa)', false),
        ('name', 'Tên ưu đãi', false),
        ('percent', 'Phần trăm giảm', true),
        ('minimum', 'Giá trị đơn tối thiểu (đ)', true),
        ('limit', 'Tổng lượt sử dụng', true),
      ],
      active: true,
      note: v == null
          ? 'Mã từ 3–20 chữ in hoa hoặc số. Không hoàn lại lượt khi hủy lịch.'
          : 'Mã ${v['id']} • Đã dùng ${v['used']} lượt. Không thay đổi lượt đã tiêu thụ.',
    );
    if (values != null && context.mounted) {
      values['id'] = '${values['id']}'.trim().toUpperCase();
      _mutate(context, () => store.saveVoucher(values), 'Đã lưu ưu đãi.');
    }
  }

  @override
  Widget build(BuildContext context) => _page([
    _Heading(
      'Ưu đãi & voucher',
      'Kiểm soát điều kiện và số lượt sử dụng',
      action: FilledButton.icon(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Tạo ưu đãi'),
      ),
    ),
    for (final v in store.vouchers)
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    color: _gold,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v['id']}',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          '${v['name']}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa voucher',
                    onPressed: () => _edit(context, v),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              _gap(),
              Text(
                'Giảm ${v['percent']}% • Đơn từ ${moneyText(v['minimum'] as int)}',
              ),
              _gap(),
              LinearProgressIndicator(
                value: (v['limit'] as int) <= 0
                    ? 0
                    : ((v['used'] as int) / (v['limit'] as int)).clamp(
                        0.0,
                        1.0,
                      ),
                color: _gold,
                backgroundColor: _paper,
              ),
              _gap(8),
              Text('Đã dùng ${v['used']} / ${v['limit']} lượt'),
              _gap(),
              _Badge(
                v['active'] == true ? 'Đang áp dụng' : 'Tạm ngưng',
                color: v['active'] == true ? const Color(0xff1a7d68) : _muted,
              ),
            ],
          ),
        ),
      ),
  ]);
}

Future<RowData?> _recordForm(
  BuildContext context,
  String title,
  RowData initial,
  List<(String, String, bool)> fields, {
  bool branch = false,
  bool active = false,
  String? note,
}) async {
  final form = GlobalKey<FormState>();
  final controllers = {
    for (final f in fields)
      f.$1: TextEditingController(text: '${initial[f.$1] ?? ''}'),
  };
  var salon = '${initial['salonId'] ?? 'salon_01'}',
      enabled = initial['active'] == true;
  return showDialog<RowData>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        title: Text(title),
        content: SizedBox(
          width: 490,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: controllers[f.$1],
                        keyboardType: f.$3
                            ? TextInputType.number
                            : TextInputType.text,
                        maxLines: f.$1 == 'description' ? 3 : 1,
                        decoration: InputDecoration(labelText: f.$2),
                        validator: (v) {
                          if (f.$1 != 'description' &&
                              (v ?? '').trim().isEmpty) {
                            return 'Vui lòng nhập ${f.$2.toLowerCase()}';
                          }
                          if (f.$3 && int.tryParse(v ?? '') == null) {
                            return 'Nhập số nguyên hợp lệ';
                          }
                          final n = int.tryParse(v ?? '');
                          if (f.$3 && n! < 0) return 'Không được nhập số âm';
                          if ((f.$1 == 'price' || f.$1 == 'duration') &&
                              n! <= 0) {
                            return 'Giá trị phải lớn hơn 0';
                          }
                          if (f.$1 == 'percent' && (n! < 1 || n > 100)) {
                            return 'Chọn từ 1 đến 100';
                          }
                          if (f.$1 == 'limit' &&
                              n! < (initial['used'] as int? ?? 0)) {
                            return 'Không nhỏ hơn số lượt đã dùng';
                          }
                          if (f.$1 == 'email' &&
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(v ?? '')) {
                            return 'Email chưa hợp lệ';
                          }
                          if (f.$1 == 'id' &&
                              !RegExp(
                                r'^[A-Za-z0-9]{3,20}$',
                              ).hasMatch(v ?? '')) {
                            return 'Nhập 3–20 chữ hoặc số';
                          }
                          return null;
                        },
                      ),
                    ),
                  if (branch)
                    DropdownButtonFormField<String>(
                      initialValue: salon,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chi nhánh chính',
                      ),
                      items: [
                        for (final b in sampleSalons)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() => salon = v!),
                    ),
                  if (active)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang hoạt động'),
                      value: enabled,
                      onChanged: (v) => update(() => enabled = v),
                    ),
                  if (note != null)
                    Text(
                      note,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                ],
              ),
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
              if (!form.currentState!.validate()) return;
              Navigator.pop(c, {
                ...initial,
                for (final f in fields)
                  f.$1: f.$3
                      ? int.parse(controllers[f.$1]!.text)
                      : controllers[f.$1]!.text.trim(),
                if (branch) 'salonId': salon,
                if (active) 'active': enabled,
              });
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    ),
  );
}

class _BranchesPage extends StatelessWidget {
  const _BranchesPage({required this.store, required this.onBook});
  final WorkspaceStore store;
  final ValueChanged<String> onBook;
  @override
  Widget build(BuildContext context) => _page([
    const _Heading(
      'Không gian của bạn',
      'Chọn salon phù hợp và mở chỉ đường khi cần',
    ),
    for (final b in sampleSalons)
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/login_barbershop_background.jpg',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(Icons.storefront, size: 48, color: _gold),
                    ),
                  ),
                ),
              ),
              _gap(),
              Text(
                b.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _gap(10),
              _detailRow(Icons.location_on_outlined, b.address),
              _detailRow(
                Icons.schedule,
                '${b.openingTime}–${b.closingTime} hằng ngày',
              ),
              _detailRow(Icons.phone_outlined, b.hotline),
              _detailRow(Icons.star_outline, '${b.rating} / 5 • Điểm minh họa'),
              _gap(),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.https('www.google.com', '/maps/dir/', {
                        'api': '1',
                        'destination': '${b.latitude},${b.longitude}',
                        'travelmode': 'driving',
                      });
                      try {
                        final opened = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!opened && context.mounted) {
                          _info(
                            context,
                            'Mở chỉ đường',
                            'Không mở được ứng dụng bản đồ. Địa chỉ: ${b.address}',
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          _info(
                            context,
                            'Mở chỉ đường',
                            'Bạn có thể tìm địa chỉ này trên Google Maps: ${b.address}',
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Chỉ đường Google Maps'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final opened = await launchUrl(
                          Uri(scheme: 'tel', path: b.hotline),
                        );
                        if (!opened && context.mounted) {
                          _toast(context, 'Hotline: ${b.hotline}');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          _toast(context, 'Hotline: ${b.hotline}');
                        }
                      }
                    },
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Gọi salon'),
                  ),
                  if (store.role == WorkspaceRole.customer)
                    FilledButton(
                      onPressed: () => onBook(b.id),
                      child: const Text('Đặt lịch'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
  ]);
}

class _StylesPage extends StatelessWidget {
  const _StylesPage({required this.onBook});
  final VoidCallback onBook;
  @override
  Widget build(BuildContext context) {
    const styles = [
      (
        'Textured Crop',
        'style_textured_crop.jpg',
        'Gọn gàng, dễ chăm sóc; hợp phong cách năng động.',
      ),
      (
        'Korean Layer',
        'style_korean_layer.jpg',
        'Layer tự nhiên, mềm mại; cần tư vấn theo chất tóc.',
      ),
      (
        'Modern Mullet',
        'style_modern_mullet.jpg',
        'Cá tính với phần gáy dài và lớp tóc tạo chuyển động.',
      ),
      (
        'Modern Side Part',
        'style_modern_side_part.jpg',
        'Lịch lãm, dễ phối đồ công sở và những dịp đặc biệt.',
      ),
      (
        'Modern Quiff',
        'style_modern_quiff.jpg',
        'Tạo độ phồng phía trước; hợp người thích tạo kiểu.',
      ),
      (
        'Buzz Fade',
        'style_buzz_fade.jpg',
        'Tối giản, thoáng mát với chuyển sắc hai bên.',
      ),
    ];
    return _page([
      const _Heading(
        'Tìm chất riêng',
        'Bộ sưu tập kiểu tóc • Chuyên viên sẽ tư vấn theo chất tóc thực tế',
      ),
      LayoutBuilder(
        builder: (context, c) {
          final count = c.maxWidth >= 1000
              ? 3
              : c.maxWidth >= 600
              ? 2
              : 1;
          final width = (c.maxWidth - (count - 1) * 18) / count;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final style in styles)
                SizedBox(
                  width: width,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/${style.$2}',
                          height: 270,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 180,
                            child: Icon(Icons.content_cut, size: 60),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                style.$1,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              _gap(8),
                              Text(
                                style.$3,
                                style: const TextStyle(color: _muted),
                              ),
                              _gap(),
                              FilledButton.icon(
                                onPressed: onBook,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Đặt lịch tư vấn'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ]);
  }
}

class _SupportPage extends StatefulWidget {
  const _SupportPage({required this.store});
  final WorkspaceStore store;
  @override
  State<_SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<_SupportPage> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store, admin = s.role == WorkspaceRole.admin;
    return _page([
      _Heading(
        admin ? 'Hộp thư hỗ trợ' : 'Chúng tôi sẵn sàng lắng nghe',
        'Tin nhắn cục bộ giữa khách và quản trị viên • Chưa kết nối chatbot AI',
      ),
      if (!admin)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Câu hỏi thường gặp',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              for (final q in [
                (
                  'Làm sao để hủy lịch?',
                  'Mở Lịch hẹn của tôi → chi tiết → Hủy lịch. Chỉ hủy trước khi bắt đầu phục vụ.',
                ),
                (
                  'Voucher được áp dụng thế nào?',
                  'Nhập mã ở bước xác nhận. Hệ thống kiểm tra đơn tối thiểu, trạng thái và lượt dùng trước khi lưu.',
                ),
                (
                  'Tôi muốn đổi giờ hẹn',
                  'Hủy lịch chưa bắt đầu và đặt giờ mới. Nếu lịch đã phục vụ, hãy liên hệ salon.',
                ),
              ])
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(q.$1),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(q.$2),
                    ),
                  ],
                ),
            ],
          ),
        ),
      _gap(),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.messages.isEmpty)
              const _Empty(
                icon: Icons.chat_bubble_outline,
                title: 'Bắt đầu cuộc trò chuyện',
                text: 'Khách gửi câu hỏi, sau đó đổi sang Admin để trả lời.',
              ),
            for (final m in s.messages)
              Align(
                alignment: m['sender'] == 'admin'
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 530),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: m['sender'] == 'admin'
                        ? _paper
                        : const Color(0xffffedcb),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['sender'] == 'admin'
                            ? 'Chăm sóc khách hàng'
                            : s.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      _gap(6),
                      Text('${m['text']}'),
                    ],
                  ),
                ),
              ),
            _gap(),
            TextField(
              controller: input,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: admin
                    ? 'Trả lời khách hàng'
                    : 'Bạn cần hỗ trợ điều gì?',
              ),
            ),
            _gap(12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  if (input.text.trim().isEmpty) return;
                  s.sendMessage(input.text, reply: admin);
                  input.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.send_outlined),
                label: const Text('Gửi tin nhắn'),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.store,
    required this.onExit,
    required this.onRoles,
  });
  final WorkspaceStore store;
  final VoidCallback onExit, onRoles;
  @override
  Widget build(BuildContext context) {
    final s = store, staff = s.role == WorkspaceRole.staff;
    return _page([
      const _Heading(
        'Tài khoản & tùy chọn',
        'Thông tin cá nhân và dữ liệu bản duyệt',
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: _ink,
                  child: Icon(Icons.person_outline, color: _gold, size: 32),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff
                            ? s.employeeName
                            : s.role == WorkspaceRole.admin
                            ? 'Quản trị viên'
                            : s.customerName,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        staff
                            ? 'Nhân viên'
                            : s.role == WorkspaceRole.admin
                            ? 'Quản lý hệ thống'
                            : 'Khách hàng',
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _gap(),
            if (staff) ...[
              _detailRow(Icons.mail_outline, '${s.person(s.staffId)['email']}'),
              _detailRow(Icons.storefront, s.branchName(s.staffBranch)),
              _detailRow(Icons.badge_outlined, s.staffId),
              const Text(
                'Liên kết tài khoản, vai trò và chi nhánh do admin quản lý.',
                style: TextStyle(color: _muted),
              ),
            ] else if (s.role == WorkspaceRole.customer) ...[
              _detailRow(Icons.phone_outlined, s.customerPhone),
              TextButton.icon(
                onPressed: () async {
                  final v = await _recordForm(
                    context,
                    'Cập nhật hồ sơ',
                    {'name': s.customerName, 'phone': s.customerPhone},
                    [
                      ('name', 'Họ và tên', false),
                      ('phone', 'Số điện thoại', false),
                    ],
                  );
                  if (v != null && context.mounted) {
                    _mutate(
                      context,
                      () => s.saveProfile(
                        v['name'] as String,
                        v['phone'] as String,
                      ),
                      'Đã lưu hồ sơ.',
                    );
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa hồ sơ'),
              ),
            ],
            _gap(),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onRoles,
                  icon: const Icon(Icons.switch_account_outlined),
                  label: const Text('Đổi vai trò xem trước'),
                ),
                TextButton.icon(
                  onPressed: onExit,
                  icon: const Icon(Icons.logout),
                  label: const Text('Về màn hình đăng nhập'),
                ),
              ],
            ),
          ],
        ),
      ),
      _gap(),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dữ liệu giao diện',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _gap(),
            const Text(
              'Trên Web, dữ liệu được lưu trong trình duyệt này và giữ khi tải lại. Trên nền tảng khác, bản xem trước chỉ giữ dữ liệu trong phiên. Không dùng dữ liệu cá nhân thật. Mật khẩu không được lưu.',
              style: TextStyle(color: _muted),
            ),
            if (s.role == WorkspaceRole.admin) ...[
              _gap(),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: s.exportJson()));
                  if (context.mounted) {
                    _toast(
                      context,
                      'Đã sao chép JSON. Dán vào tệp để lưu bản dữ liệu giao diện.',
                    );
                  }
                },
                icon: const Icon(Icons.save_alt),
                label: const Text('Sao chép bản lưu JSON'),
              ),
            ],
          ],
        ),
      ),
      if (s.role == WorkspaceRole.admin) ...[
        _gap(),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhật ký thao tác',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              _gap(),
              if (s.audit.isEmpty) const Text('Chưa có thao tác mới.'),
              for (final event in s.audit.reversed.take(20))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, color: _gold),
                  title: Text('${event['action']}'),
                  subtitle: Text('${event['actor']} • ${event['at']}'),
                ),
            ],
          ),
        ),
      ],
    ]);
  }
}
