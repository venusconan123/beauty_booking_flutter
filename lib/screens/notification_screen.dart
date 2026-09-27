import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const Color _ink = Color(0xFF08111E);
  static const Color _surface = Color(0xF2121B28);
  static const Color _gold = Color(0xFFF6C768);
  static const Color _muted = Color(0xFFB8C0CC);

  DateTime _dateOf(Map<String, dynamic> data) {
    return (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  (IconData, Color) _appearance(String type) {
    return switch (type) {
      'promotion' => (Icons.local_offer_rounded, const Color(0xFFFFB648)),
      'booking_confirmed' => (Icons.event_available_rounded, const Color(0xFF59D38C)),
      'booking_completed' => (Icons.task_alt_rounded, const Color(0xFF63B3FF)),
      'booking_cancelled' => (Icons.event_busy_rounded, const Color(0xFFFF6B6B)),
      'payment_confirmed' => (Icons.verified_rounded, const Color(0xFF59D38C)),
      _ => (Icons.notifications_active_rounded, _gold),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _ink,
        body: Center(
          child: Text('Bạn cần đăng nhập để xem thông báo.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final announcements =
        FirebaseFirestore.instance.collection('announcements').snapshots();
    final personal = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .snapshots();

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text('Thông báo',
            style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0x33F6C768)),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_barbershop_background.jpg',
              fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF008111E), Color(0xFF08111E)],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: announcements,
            builder: (context, announcementSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: personal,
                builder: (context, personalSnapshot) {
                  if (announcementSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      personalSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: _gold));
                  }
                  final notices =
                      <({String id, Map<String, dynamic> data})>[
                    ...?announcementSnapshot.data?.docs.map(
                      (doc) => (id: doc.id, data: doc.data()),
                    ),
                    ...?personalSnapshot.data?.docs.map(
                      (doc) => (id: doc.id, data: doc.data()),
                    ),
                  ];
                  notices.sort((a, b) =>
                      _dateOf(b.data).compareTo(_dateOf(a.data)));
                  if (notices.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 64, color: _gold),
                            SizedBox(height: 14),
                            Text('Chưa có thông báo',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            Text(
                              'Ưu đãi và cập nhật lịch hẹn sẽ xuất hiện tại đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: notices.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data = notices[index].data;
                          final type =
                              data['type']?.toString() ?? 'general';
                          final appearance = _appearance(type);
                          final salonName =
                              data['salonName']?.toString() ?? '';
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: appearance.$2.withAlpha(95)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: appearance.$2.withAlpha(28),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(appearance.$1,
                                      color: appearance.$2),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title']?.toString() ??
                                            'Thông báo mới',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (salonName.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(salonName,
                                            style: TextStyle(
                                                color: appearance.$2,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                      const SizedBox(height: 7),
                                      Text(
                                        data['message']?.toString() ?? '',
                                        style: const TextStyle(
                                            color: _muted, height: 1.45),
                                      ),
                                      const SizedBox(height: 9),
                                      Text(
                                        _relativeTime(_dateOf(data)),
                                        style: const TextStyle(
                                            color: Color(0xFF8792A2),
                                            fontSize: 12),
                                      ),
                                    ],
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
              );
            },
          ),
        ],
      ),
    );
  }
}

