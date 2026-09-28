import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'support_chat_screen.dart';

class AdminChatScreen extends StatelessWidget {
  const AdminChatScreen({super.key});

  static const Color _ink = Color(0xFF090E14);
  static const Color _panel = Color(0xFF111923);
  static const Color _gold = Color(0xFFF0C36A);
  static const Color _cream = Color(0xFFF5EFE5);

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate().toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.hour)}:${twoDigits(date.minute)} · '
        '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý tin nhắn',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_chats')
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể tải danh sách chat. Hãy deploy Firestore Rules mới.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data?.docs ?? [];
          if (chats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_chat_unread_outlined, size: 60, color: _gold),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có tin nhắn từ khách hàng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: chats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final data = chat.data();
                  final name = data['userName']?.toString().trim();
                  final email = data['userEmail']?.toString() ?? '';
                  final unread = data['unreadForAdmin'] as bool? ?? false;
                  return Material(
                    color: unread ? const Color(0xFFFFF5DC) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: _panel,
                        foregroundColor: _gold,
                        child: Text(
                          (name?.isNotEmpty == true ? name![0] : 'K')
                              .toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name?.isNotEmpty == true ? name! : 'Khách hàng',
                              style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(data['lastMessageAt'] as Timestamp?),
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          data['lastMessage']?.toString() ?? email,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: unread
                          ? const Badge(
                              backgroundColor: _gold,
                              child: Icon(Icons.chat_bubble_rounded, size: 18),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SupportChatScreen(
                              customerId: chat.id,
                              customerName: name,
                              customerEmail: email,
                            ),
                          ),
                        );
                      },
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
