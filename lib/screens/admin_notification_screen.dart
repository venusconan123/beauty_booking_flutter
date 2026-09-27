import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/sample_salons.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  static const Color _ink = Color(0xFF08111E);
  static const Color _surface = Color(0xF2121B28);
  static const Color _field = Color(0xFF182432);
  static const Color _gold = Color(0xFFF6C768);
  static const Color _muted = Color(0xFFB8C0CC);

  Future<void> _composeAnnouncement() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String salonId = 'all';
    bool sending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Tạo thông báo mới',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fieldInput(
                    controller: titleController,
                    label: 'Tiêu đề',
                    icon: Icons.title_rounded,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: salonId,
                    dropdownColor: _field,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                        label: 'Ưu đãi áp dụng tại',
                        icon: Icons.store_mall_directory_rounded),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Tất cả chi nhánh'),
                      ),
                      ...sampleSalons.map(
                        (salon) => DropdownMenuItem(
                          value: salon.id,
                          child: Text(salon.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: sending
                        ? null
                        : (value) =>
                            setDialogState(() => salonId = value ?? 'all'),
                  ),
                  const SizedBox(height: 14),
                  _fieldInput(
                    controller: messageController,
                    label: 'Nội dung ưu đãi / thông báo',
                    icon: Icons.campaign_rounded,
                    maxLength: 800,
                    maxLines: 6,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy', style: TextStyle(color: _muted)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: _ink),
              onPressed: sending
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final message = messageController.text.trim();
                      if (title.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Vui lòng nhập đủ tiêu đề và nội dung.')),
                        );
                        return;
                      }
                      setDialogState(() => sending = true);
                      try {
                        final selectedSalon = salonId == 'all'
                            ? null
                            : sampleSalons.firstWhere(
                                (salon) => salon.id == salonId,
                              );
                        await FirebaseFirestore.instance
                            .collection('announcements')
                            .add({
                          'type': 'promotion',
                          'title': title,
                          'message': message,
                          'audience': salonId == 'all' ? 'all' : 'salon',
                          'salonId': selectedSalon?.id ?? '',
                          'salonName': selectedSalon?.name ?? '',
                          'createdBy':
                              FirebaseAuth.instance.currentUser?.uid ?? '',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi thông báo đến khách hàng.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } on FirebaseException catch (error) {
                        setDialogState(() => sending = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Không thể gửi: ${error.message}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(sending ? 'Đang gửi...' : 'Gửi thông báo',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    messageController.dispose();
  }

  InputDecoration _decoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
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
    );
  }

  Widget _fieldInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label: label, icon: icon),
    );
  }

  Future<void> _deleteAnnouncement(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Xóa thông báo',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Thông báo sẽ không còn hiển thị với khách hàng.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Giữ lại')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD94B4B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(id)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text('Quản lý thông báo',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _composeAnnouncement,
        backgroundColor: _gold,
        foregroundColor: _ink,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Tạo thông báo',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('announcements').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _gold));
          }
          final documents = [...?snapshot.data?.docs];
          documents.sort((a, b) {
            final first =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final second =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return second.compareTo(first);
          });
          if (documents.isEmpty) {
            return const Center(
              child: Text('Chưa có thông báo nào.',
                  style: TextStyle(color: _muted, fontSize: 16)),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                itemCount: documents.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final data = document.data();
                  final salonName = data['salonName']?.toString() ?? '';
                  return Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0x44F6C768)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0x22F6C768),
                          foregroundColor: _gold,
                          child: Icon(Icons.campaign_rounded),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(
                                salonName.isEmpty
                                    ? 'Áp dụng tại tất cả chi nhánh'
                                    : 'Ưu đãi tại $salonName',
                                style: const TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(data['message']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: _muted, height: 1.45)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa thông báo',
                          onPressed: () =>
                              _deleteAnnouncement(document.id),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFFF7777)),
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
