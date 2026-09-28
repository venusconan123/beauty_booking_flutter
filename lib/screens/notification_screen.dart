import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/voucher.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xF2121B28);
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

  DateTime _dateOf(Map<String, dynamic> data) =>
      (data['createdAt'] as Timestamp?)?.toDate() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  (IconData, Color) _appearance(String type) => switch (type) {
    'promotion' => (Icons.local_offer_rounded, const Color(0xFFFFB648)),
    'voucher_received' => (Icons.confirmation_number_rounded, _gold),
    'voucher_available' => (Icons.redeem_rounded, _gold),
    'booking_confirmed' => (
      Icons.event_available_rounded,
      const Color(0xFF59D38C),
    ),
    'booking_completed' => (Icons.task_alt_rounded, const Color(0xFF63B3FF)),
    'booking_cancelled' => (
      Icons.event_busy_rounded,
      const Color(0xFFFF6B6B),
    ),
    'payment_confirmed' => (Icons.verified_rounded, const Color(0xFF59D38C)),
    _ => (Icons.notifications_active_rounded, _gold),
  };

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _ink,
        body: Center(
          child: Text(
            'Bạn cần đăng nhập để xem thông báo.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _ink,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B1420),
          foregroundColor: Colors.white,
          title: const Text(
            'Thông báo & ưu đãi',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: const TabBar(
            indicatorColor: _gold,
            labelColor: _gold,
            unselectedLabelColor: _muted,
            tabs: [
              Tab(icon: Icon(Icons.notifications_rounded), text: 'Thông báo'),
              Tab(
                icon: Icon(Icons.confirmation_number_rounded),
                text: 'Voucher',
              ),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/login_barbershop_background.jpg',
              fit: BoxFit.cover,
            ),
            const ColoredBox(color: Color(0xED08111E)),
            TabBarView(
              children: [_buildNotices(user.uid), _buildVouchers(user.uid)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotices(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('announcements').snapshots(),
      builder: (context, announcementSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .snapshots(),
          builder: (context, personalSnapshot) {
            if (announcementSnapshot.connectionState == ConnectionState.waiting ||
                personalSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _gold),
              );
            }
            final notices = <Map<String, dynamic>>[
              ...?announcementSnapshot.data?.docs.map((doc) => doc.data()),
              ...?personalSnapshot.data?.docs.map((doc) => doc.data()),
            ]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
            if (notices.isEmpty) {
              return _empty(
                Icons.notifications_none_rounded,
                'Chưa có thông báo',
                'Ưu đãi và cập nhật lịch hẹn sẽ xuất hiện tại đây.',
              );
            }
            return _centeredList(
              notices.length,
              (context, index) {
                final data = notices[index];
                final appearance = _appearance(
                  data['type']?.toString() ?? 'general',
                );
                final salonName = data['salonName']?.toString() ?? '';
                return _card(
                  borderColor: appearance.$2,
                  icon: appearance.$1,
                  iconColor: appearance.$2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title']?.toString() ?? 'Thông báo mới',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (salonName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          salonName,
                          style: TextStyle(
                            color: appearance.$2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        data['message']?.toString() ?? '',
                        style: const TextStyle(color: _muted, height: 1.45),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _relativeTime(_dateOf(data)),
                        style: const TextStyle(
                          color: Color(0xFF8792A2),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVouchers(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('vouchers')
          .snapshots(),
      builder: (context, personalSnapshot) {
        if (personalSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        final vouchers = <Voucher>[
          ...?personalSnapshot.data?.docs.map(
            (doc) => Voucher.fromDocument(doc, isPersonal: true),
          ),
        ]..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
        if (vouchers.isEmpty) {
          return Column(
            children: [
              _loyaltyProgress(userId),
              Expanded(
                child: _empty(
                  Icons.confirmation_number_outlined,
                  'Chưa có voucher tích lũy',
                  'Hoàn thành 10 lần sử dụng dịch vụ để nhận voucher giảm 25%.',
                ),
              ),
            ],
          );
        }
        return _centeredList(
          vouchers.length,
          (context, index) => _voucherCard(vouchers[index]),
          header: _loyaltyProgress(userId),
        );
      },
    );
  }

  Widget _voucherCard(Voucher voucher) {
    final expired = voucher.expiresAt != null &&
        !voucher.expiresAt!.isAfter(DateTime.now());
    final alreadyUsed = voucher.isUsed;
    final unavailable = alreadyUsed || !voucher.isActive || expired;
    final status = alreadyUsed
        ? 'Đã dùng'
        : expired
        ? 'Hết hạn'
        : voucher.isActive
        ? 'Có thể dùng'
        : 'Tạm dừng';
    return Opacity(
      opacity: unavailable ? .55 : 1,
      child: _card(
        borderColor: unavailable ? _muted : _gold,
        icon: Icons.confirmation_number_rounded,
        iconColor: unavailable ? _muted : _gold,
        trailing: Text(
          status,
          style: TextStyle(
            color: unavailable ? _muted : const Color(0xFF59D38C),
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              voucher.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Mã ${voucher.code} · Giảm ${voucher.discountPercent}%',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              voucher.minOrderAmount == 0
                  ? 'Áp dụng cho mọi đơn hàng'
                  : 'Đơn tối thiểu ${_formatPrice(voucher.minOrderAmount)}',
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centeredList(
    int itemCount,
    Widget Function(BuildContext, int) itemBuilder, {
    Widget? header,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: itemCount + (header == null ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (header != null && index == 0) return header;
            return itemBuilder(context, index - (header == null ? 0 : 1));
          },
        ),
      ),
    );
  }

  Widget _loyaltyProgress(String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final completed = snapshot.data?.docs.where((document) {
              return document.data()['status'] == 'completed';
            }).length ??
            0;
        final progress = completed % 10;
        final remaining = progress == 0 && completed > 0 ? 10 : 10 - progress;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xF21A2430),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x77F6C768)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: _gold),
                  SizedBox(width: 9),
                  Text(
                    'Tích điểm thành viên',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress / 10,
                minHeight: 9,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: const Color(0xFF263343),
                color: _gold,
              ),
              const SizedBox(height: 8),
              Text(
                '$progress/10 lượt · Còn $remaining lượt để nhận voucher giảm 25%',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card({
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withAlpha(95)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(28),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 13),
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: _gold),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
