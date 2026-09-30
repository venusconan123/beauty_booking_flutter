import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/hair_service.dart';
import '../services/hair_service_catalog.dart';

class AdminServiceScreen extends StatefulWidget {
  const AdminServiceScreen({super.key});

  @override
  State<AdminServiceScreen> createState() => _AdminServiceScreenState();
}

class _AdminServiceScreenState extends State<AdminServiceScreen> {
  static const _ink = Color(0xFF08111E);
  static const _panel = Color(0xFF111B29);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);
  final HairServiceCatalog _catalog = HairServiceCatalog();
  final Set<String> _savingIds = {};

  String _formatPrice(int price) {
    final value = price.toString();
    final output = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) output.write('.');
      output.write(value[index]);
    }
    return '$outputđ';
  }

  Future<void> _edit(ServiceAdminItem? item) async {
    final result = await showDialog<_ServiceFormResult>(
      context: context,
      builder: (_) => _ServiceDialog(item: item),
    );
    if (result == null) return;
    setState(() => _savingIds.add(result.service.id));
    try {
      if (item == null) {
        await _catalog.create(result.service);
      } else {
        await _catalog.save(
          service: result.service,
          isActive: result.isActive,
          order: item.order,
        );
      }
      if (mounted) _message('Đã lưu thông tin dịch vụ.');
    } on FirebaseException catch (error) {
      if (mounted) _message(error.message ?? 'Không thể lưu dịch vụ.', true);
    } finally {
      if (mounted) setState(() => _savingIds.remove(result.service.id));
    }
  }

  Future<void> _toggle(ServiceAdminItem item, bool value) async {
    setState(() => _savingIds.add(item.service.id));
    try {
      await _catalog.save(
        service: item.service,
        isActive: value,
        order: item.order,
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(error.message ?? 'Không thể cập nhật dịch vụ.', true);
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(item.service.id));
    }
  }

  Future<void> _delete(ServiceAdminItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Xóa dịch vụ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Dịch vụ “${item.service.name}” sẽ bị xóa hoặc ẩn khỏi danh sách đặt lịch.',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _catalog.delete(item.service.id);
      if (mounted) _message('Đã xóa dịch vụ.');
    } on FirebaseException catch (error) {
      if (mounted) _message(error.message ?? 'Không thể xóa dịch vụ.', true);
    }
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text('Quản lý dịch vụ'),
        actions: [
          IconButton(
            tooltip: 'Thêm dịch vụ',
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add_circle_outline_rounded, color: _gold),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        backgroundColor: _gold,
        foregroundColor: _ink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm dịch vụ'),
      ),
      body: StreamBuilder<List<ServiceAdminItem>>(
        stream: _catalog.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Không thể tải dịch vụ: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          final items = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 100),
                children: [
                  const Text(
                    'Danh mục dịch vụ chung',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Giá và thời lượng được áp dụng cho cả 3 chi nhánh. Tắt dịch vụ để tạm ẩn khỏi luồng đặt lịch.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  for (final item in items) ...[
                    _card(item),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(ServiceAdminItem item) {
    final saving = _savingIds.contains(item.service.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x44F6C768)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0x22F6C768),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.content_cut_rounded, color: _gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.service.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatPrice(item.service.price)} • ${item.service.durationMinutes} phút',
                  style: const TextStyle(color: _gold),
                ),
                const SizedBox(height: 3),
                Text(
                  item.service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: _gold),
            )
          else ...[
            Switch(
              value: item.isActive,
              activeThumbColor: _gold,
              onChanged: (value) => _toggle(item, value),
            ),
            PopupMenuButton<String>(
              color: _panel,
              onSelected: (value) => value == 'edit' ? _edit(item) : _delete(item),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Chỉnh sửa', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceFormResult {
  const _ServiceFormResult(this.service, this.isActive);
  final HairService service;
  final bool isActive;
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({this.item});
  final ServiceAdminItem? item;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final service = widget.item?.service;
    _name = TextEditingController(text: service?.name ?? '');
    _price = TextEditingController(text: service?.price.toString() ?? '');
    _duration = TextEditingController(
      text: service?.durationMinutes.toString() ?? '',
    );
    _description = TextEditingController(text: service?.description ?? '');
    _active = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _positive(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return 'Vui lòng nhập số lớn hơn 0';
    return null;
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    final id = widget.item?.service.id ??
        'service_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      _ServiceFormResult(
        HairService(
          id: id,
          name: _name.text.trim(),
          price: int.parse(_price.text.trim()),
          durationMinutes: int.parse(_duration.text.trim()),
          description: _description.text.trim(),
        ),
        _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111B29),
      title: Text(
        widget.item == null ? 'Thêm dịch vụ' : 'Chỉnh sửa dịch vụ',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Tên dịch vụ', validator: (value) {
                  if ((value ?? '').trim().length < 2) return 'Tên quá ngắn';
                  return null;
                }),
                _field(_price, 'Giá (VNĐ)', number: true, validator: _positive),
                _field(
                  _duration,
                  'Thời lượng (phút)',
                  number: true,
                  validator: _positive,
                ),
                _field(_description, 'Mô tả', lines: 3, validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  return null;
                }),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  activeThumbColor: const Color(0xFFF6C768),
                  title: const Text(
                    'Đang hiển thị',
                    style: TextStyle(color: Colors.white),
                  ),
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int lines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFB8C0CC)),
          filled: true,
          fillColor: const Color(0xFF182432),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
