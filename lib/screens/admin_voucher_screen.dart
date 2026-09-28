import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminVoucherScreen extends StatefulWidget {
  const AdminVoucherScreen({super.key});

  @override
  State<AdminVoucherScreen> createState() => _AdminVoucherScreenState();
}

class _AdminVoucherScreenState extends State<AdminVoucherScreen> {
  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xF2121B28);
  static const _field = Color(0xFF182432);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);

  String _formatPrice(int price) {
    final value = price.toString();
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) result.write('.');
      result.write(value[index]);
    }
    return '${result}đ';
  }

  Future<void> _openEditor({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data() ?? <String, dynamic>{};
    final codeController = TextEditingController(
      text: data['code']?.toString() ?? '',
    );
    final titleController = TextEditingController(
      text: data['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );
    final percentController = TextEditingController(
      text: data['discountPercent']?.toString() ?? '',
    );
    final minimumController = TextEditingController(
      text: data['minOrderAmount']?.toString() ?? '0',
    );
    final usedCount = (data['usedCount'] as num?)?.toInt() ?? 0;
    final usageLimitController = TextEditingController(
      text: data['usageLimit']?.toString() ?? '1',
    );
    bool isActive = data['isActive'] as bool? ?? true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _surface,
          title: Text(
            document == null ? 'Tạo voucher mới' : 'Chỉnh sửa voucher',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _input(codeController, 'Mã voucher', Icons.qr_code_rounded),
                  const SizedBox(height: 12),
                  _input(titleController, 'Tên ưu đãi', Icons.title_rounded),
                  const SizedBox(height: 12),
                  _input(
                    descriptionController,
                    'Mô tả',
                    Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          percentController,
                          'Giảm (%)',
                          Icons.percent_rounded,
                          number: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _input(
                          minimumController,
                          'Đơn tối thiểu (đ)',
                          Icons.payments_outlined,
                          number: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _input(
                    usageLimitController,
                    'Tổng số khách được sử dụng',
                    Icons.people_alt_outlined,
                    number: true,
                  ),
                  if (document != null) ...[
                    const SizedBox(height: 7),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Đã có $usedCount khách sử dụng voucher này.',
                        style: const TextStyle(color: _muted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _gold,
                    title: const Text(
                      'Cho phép sử dụng',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Tắt để tạm dừng voucher mà không cần xóa.',
                      style: TextStyle(color: _muted),
                    ),
                    value: isActive,
                    onChanged: saving
                        ? null
                        : (value) =>
                              setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: _muted)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final code = codeController.text.trim().toUpperCase();
                      final title = titleController.text.trim();
                      final percent = int.tryParse(percentController.text);
                      final minimum = int.tryParse(minimumController.text);
                      final usageLimit = int.tryParse(
                        usageLimitController.text,
                      );
                      if (code.isEmpty ||
                          title.isEmpty ||
                          percent == null ||
                          percent < 1 ||
                          percent > 100 ||
                          minimum == null ||
                          minimum < 0 ||
                          usageLimit == null ||
                          usageLimit < 1 ||
                          usageLimit < usedCount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kiểm tra mã, tên, mức giảm 1–100%, giá tối thiểu và số lượng voucher.',
                            ),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final values = <String, dynamic>{
                        'code': code,
                        'title': title,
                        'description': descriptionController.text.trim(),
                        'discountPercent': percent,
                        'minOrderAmount': minimum,
                        'usageLimit': usageLimit,
                        'usedCount': usedCount,
                        'isActive': isActive,
                        'source': 'admin',
                        'updatedAt': FieldValue.serverTimestamp(),
                      };
                      try {
                        if (document == null) {
                          values['createdAt'] = FieldValue.serverTimestamp();
                          final firestore = FirebaseFirestore.instance;
                          final createdVoucher = firestore
                              .collection('voucher_templates')
                              .doc();
                          final announcement = firestore
                              .collection('announcements')
                              .doc();
                          final batch = firestore.batch();
                          batch.set(createdVoucher, values);
                          batch.set(announcement, {
                            'type': 'voucher_available',
                            'title': 'Voucher mới: $title',
                            'message': minimum == 0
                                ? 'Mã $code giảm $percent%, chỉ dành cho $usageLimit khách hàng đầu tiên. Nhập mã khi xác nhận đặt lịch để sử dụng.'
                                : 'Mã $code giảm $percent% cho đơn từ ${_formatPrice(minimum)}, chỉ dành cho $usageLimit khách hàng đầu tiên. Nhập mã khi xác nhận đặt lịch để sử dụng.',
                            'audience': 'all',
                            'voucherId': createdVoucher.id,
                            'voucherCode': code,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          await batch.commit();
                        } else {
                          await document.reference.update(values);
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } on FirebaseException catch (error) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error.message ?? 'Không thể lưu voucher.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Đang lưu...' : 'Lưu voucher'),
            ),
          ],
        ),
      ),
    );

    codeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    percentController.dispose();
    minimumController.dispose();
    usageLimitController.dispose();
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        prefixIcon: Icon(icon, color: _gold),
        filled: true,
        fillColor: _field,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x44F6C768)),
        ),
      ),
    );
  }

  Future<void> _delete(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa voucher?'),
        content: const Text(
          'Voucher này sẽ không còn xuất hiện với khách hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await document.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý voucher',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        backgroundColor: _gold,
        foregroundColor: _ink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo voucher'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('voucher_templates')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          final documents = [...?snapshot.data?.docs]
            ..sort((a, b) {
              final first = (a.data()['createdAt'] as Timestamp?)?.toDate();
              final second = (b.data()['createdAt'] as Timestamp?)?.toDate();
              return (second ?? DateTime(0)).compareTo(first ?? DateTime(0));
            });
          if (documents.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có voucher. Nhấn “Tạo voucher” để bắt đầu.',
                style: TextStyle(color: _muted, fontSize: 16),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                itemCount: documents.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final data = document.data();
                  final active = data['isActive'] as bool? ?? false;
                  final percent =
                      (data['discountPercent'] as num?)?.toInt() ?? 0;
                  final minimum =
                      (data['minOrderAmount'] as num?)?.toInt() ?? 0;
                  final usageLimit =
                      (data['usageLimit'] as num?)?.toInt() ?? 1;
                  final usedCount =
                      (data['usedCount'] as num?)?.toInt() ?? 0;
                  final remaining = (usageLimit - usedCount).clamp(
                    0,
                    usageLimit,
                  );
                  final hasStock = usedCount < usageLimit;
                  return Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active && hasStock
                            ? const Color(0x66F6C768)
                            : const Color(0x336C7480),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0x22F6C768),
                          foregroundColor: active ? _gold : _muted,
                          child: const Icon(Icons.confirmation_number_rounded),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['code'] ?? ''} · Giảm $percent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                data['title']?.toString() ?? '',
                                style: const TextStyle(color: _gold),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                minimum == 0
                                    ? 'Không yêu cầu giá trị tối thiểu'
                                    : 'Đơn từ ${_formatPrice(minimum)}',
                                style: const TextStyle(color: _muted),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Đã dùng $usedCount/$usageLimit · Còn $remaining lượt',
                                style: TextStyle(
                                  color: hasStock
                                      ? const Color(0xFF59D38C)
                                      : const Color(0xFFFF7777),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: active,
                          activeThumbColor: _gold,
                          onChanged: (value) => document.reference.update({
                            'isActive': value,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }),
                        ),
                        IconButton(
                          tooltip: 'Sửa',
                          onPressed: () => _openEditor(document: document),
                          icon: const Icon(Icons.edit_outlined, color: _gold),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          onPressed: () => _delete(document),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFFF7777),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
