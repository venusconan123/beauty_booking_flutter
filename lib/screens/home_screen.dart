import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import 'admin_chat_screen.dart';
import 'admin_booking_screen.dart';
import 'admin_barber_screen.dart';
import 'admin_hairstyle_screen.dart';
import 'admin_loyalty_settings_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_report_screen.dart';
import 'admin_voucher_screen.dart';
import 'booking_branch_selection_screen.dart';
import 'booking_history_screen.dart';
import 'hairstyle_gallery_screen.dart';
import 'quick_booking_branch_screen.dart';
import 'salon_detail_screen.dart';
import 'salon_map_screen.dart';
import 'notification_screen.dart';
import 'support_chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _ink = Color(0xFF090E14);
  static const Color _panel = Color(0xFF111923);
  static const Color _cream = Color(0xFFF5EFE5);
  static const Color _gold = Color(0xFFF0C36A);
  static const Color _muted = Color(0xFFB8C0CC);

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        icon: const Icon(Icons.logout_rounded, color: _gold, size: 44),
        title: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất không?',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) await FirebaseAuth.instance.signOut();
  }

  void _openBookingHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookingHistoryScreen()),
    );
  }

  void _openAdminBookingScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminBookingScreen()));
  }

  void _openAdminBarberScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminBarberScreen()),
    );
  }

  void _openAdminHairstyleScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminHairstyleScreen()),
    );
  }

  void _openAdminNotificationScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminNotificationScreen()),
    );
  }

  void _openAdminReportScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminReportScreen()),
    );
  }

  void _openAdminVoucherScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminVoucherScreen()),
    );
  }

  void _openAdminLoyaltySettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminLoyaltySettingsScreen(),
      ),
    );
  }

  void _openSupportChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportChatScreen()),
    );
  }

  void _openAdminChatScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminChatScreen()),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationScreen()));
  }

  void _openHairstyleGallery(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HairstyleGalleryScreen()),
    );
  }

  void _openMap(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SalonMapScreen()));
  }

  void _openSalon(BuildContext context, Salon salon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SalonDetailScreen(salon: salon)),
    );
  }

  void _openBookingBranchSelection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BookingBranchSelectionScreen(
          salons: sampleSalons,
        ),
      ),
    );
  }

  void _openQuickBooking(
    BuildContext context,
    HairService service, {
    Hairstyle? selectedHairstyle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuickBookingBranchScreen(
          selectedService: service,
          selectedHairstyle: selectedHairstyle,
          salons: sampleSalons,
        ),
      ),
    );
  }

  Widget _buildAdminButton(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!(snapshot.data?.exists ?? false)) {
          return const SizedBox.shrink();
        }
        return PopupMenuButton<String>(
          tooltip: 'Khu vực quản trị',
          color: _panel,
          iconColor: Colors.white,
          icon: const Icon(Icons.admin_panel_settings_rounded),
          onSelected: (value) {
            if (value == 'hairstyles') {
              _openAdminHairstyleScreen(context);
            } else if (value == 'employees') {
              _openAdminBarberScreen(context);
            } else if (value == 'notifications') {
              _openAdminNotificationScreen(context);
            } else if (value == 'reports') {
              _openAdminReportScreen(context);
            } else if (value == 'vouchers') {
              _openAdminVoucherScreen(context);
            } else if (value == 'loyalty') {
              _openAdminLoyaltySettingsScreen(context);
            } else if (value == 'chats') {
              _openAdminChatScreen(context);
            } else {
              _openAdminBookingScreen(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'bookings',
              child: ListTile(
                leading: Icon(Icons.calendar_month_outlined, color: _gold),
                title: Text(
                  'Quản lý lịch hẹn',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'employees',
              child: ListTile(
                leading: Icon(Icons.badge_outlined, color: _gold),
                title: Text(
                  'Quản lý nhân viên',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'hairstyles',
              child: ListTile(
                leading: Icon(Icons.photo_library_outlined, color: _gold),
                title: Text(
                  'Quản lý mẫu tóc',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'notifications',
              child: ListTile(
                leading: Icon(Icons.campaign_outlined, color: _gold),
                title: Text(
                  'Quản lý thông báo',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'vouchers',
              child: ListTile(
                leading: Icon(
                  Icons.confirmation_number_outlined,
                  color: _gold,
                ),
                title: Text(
                  'Quản lý voucher',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'loyalty',
              child: ListTile(
                leading: Icon(Icons.workspace_premium_outlined, color: _gold),
                title: Text(
                  'Quản lý tích điểm',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'chats',
              child: ListTile(
                leading: Icon(Icons.forum_outlined, color: _gold),
                title: Text(
                  'Quản lý tin nhắn',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            PopupMenuItem(
              value: 'reports',
              child: ListTile(
                leading: Icon(Icons.flag_outlined, color: _gold),
                title: Text(
                  'Quản lý báo cáo',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _headerIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.white,
      hoverColor: const Color(0x22F0C36A),
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      floatingActionButton: _buildChatButton(context),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopArea(context)),
          SliverToBoxAdapter(child: _buildTrendSection(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildServiceStrip(context)),
          SliverToBoxAdapter(child: _buildSalonSection(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 36)),
        ],
      ),
    );
  }

  Widget _buildChatButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data?.exists ?? false;
        return FloatingActionButton.extended(
          heroTag: 'support_chat',
          backgroundColor: _gold,
          foregroundColor: _ink,
          onPressed: () => isAdmin
              ? _openAdminChatScreen(context)
              : _openSupportChat(context),
          icon: Icon(
            isAdmin ? Icons.support_agent_rounded : Icons.chat_bubble_rounded,
          ),
          label: Text(
            isAdmin ? 'Tin nhắn khách hàng' : 'Chat với admin',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        );
      },
    );
  }

  Widget _buildTopArea(BuildContext context) {
    return Container(
      color: _ink,
      child: SafeArea(
        bottom: false,
        child: Column(children: [_buildHeader(context), _buildHero(context)]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 820;
        return Container(
          height: 68,
          padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x33F0C36A))),
          ),
          child: Row(
            children: [
              const Icon(Icons.content_cut_rounded, color: _gold, size: 29),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'MEN HAIR BOOKING',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (wide) ...[
                _navText('Trang chủ', selected: true),
                const SizedBox(width: 18),
              ],
              _buildAdminButton(context),
              _headerIcon(
                tooltip: 'Bản đồ salon',
                icon: Icons.map_outlined,
                onPressed: () => _openMap(context),
              ),
              _headerIcon(
                tooltip: 'Lịch hẹn của tôi',
                icon: Icons.calendar_month_outlined,
                onPressed: () => _openBookingHistory(context),
              ),
              _headerIcon(
                tooltip: 'Thông báo',
                icon: Icons.notifications_none_rounded,
                onPressed: () => _openNotifications(context),
              ),
              _headerIcon(
                tooltip: 'Đăng xuất',
                icon: Icons.logout_rounded,
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navText(String label, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? _gold : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 30 : 0,
            height: 2,
            color: _gold,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 760;
        return Container(
          height: wide ? 410 : 520,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/home_editorial_hero.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: wide
                    ? const [
                        Color(0xF5090E14),
                        Color(0xB0090E14),
                        Color(0x08090E14),
                      ]
                    : const [
                        Color(0xF2090E14),
                        Color(0xB8090E14),
                        Color(0x44090E14),
                      ],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              wide ? 64 : 22,
              34,
              wide ? 64 : 22,
              30,
            ),
            child: Align(
              alignment: wide ? Alignment.centerLeft : Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 570 : 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TÓC ĐẸP HƠN  •  PHIÊN BẢN TỐT HƠN CỦA BẠN',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PHONG CÁCH MỚI,\nKHÍ CHẤT MỚI',
                      style: TextStyle(
                        color: const Color(0xFFFFF5E4),
                        fontSize: wide ? 48 : 36,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đặt lịch cùng stylist phù hợp và khám phá diện mạo dành riêng cho bạn.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: sampleSalons.isEmpty
                              ? null
                              : () => _openBookingBranchSelection(context),
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                          ),
                          label: const Text('ĐẶT LỊCH NGAY'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openHairstyleGallery(context),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 19,
                          ),
                          label: const Text('XEM KIỂU TÓC'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendSection(BuildContext context) {
    const styles = [
      (
        image: 'assets/images/style_textured_crop.jpg',
        name: 'Textured Crop',
        detail: 'Năng động • Hiện đại • Dễ chăm sóc',
      ),
      (
        image: 'assets/images/style_korean_layer.jpg',
        name: 'Korean Layer',
        detail: 'Thanh lịch • Trẻ trung • Hợp nhiều khuôn mặt',
      ),
      (
        image: 'assets/images/style_modern_mullet.jpg',
        name: 'Modern Mullet',
        detail: 'Cá tính • Thời thượng • Tạo chất riêng',
      ),
    ];

    return _contentWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 30, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('KIỂU TÓC NỔI BẬT', 'ĐANG THỊNH HÀNH'),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 840;
                final double cardWidth = wide
                    ? (constraints.maxWidth - 28) / 3
                    : constraints.maxWidth * .82;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int index = 0; index < styles.length; index++) ...[
                        SizedBox(
                          width: cardWidth,
                          child: _styleCard(
                            context,
                            styles[index].image,
                            styles[index].name,
                            styles[index].detail,
                          ),
                        ),
                        if (index != styles.length - 1)
                          const SizedBox(width: 14),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _styleCard(
    BuildContext context,
    String image,
    String name,
    String detail,
  ) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showStyleDetail(context, name, detail),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE6000000)],
                stops: [.38, 1],
              ),
              border: Border.all(color: const Color(0x44F0C36A)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFFFF5E4),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceStrip(BuildContext context) {
    const services = [
      (Icons.workspace_premium_rounded, comboTenSteps, '150.000đ'),
      (Icons.content_cut_rounded, hairCut, '80.000đ'),
      (Icons.shower_rounded, hairWash, '30.000đ'),
      (Icons.auto_awesome_rounded, hairStyling, '50.000đ'),
      (Icons.colorize_rounded, hairDye, '300.000đ'),
      (Icons.spa_outlined, skinCare, '100.000đ'),
    ];

    return _contentWidth(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1F59472B)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runSpacing: 16,
          spacing: 18,
          children: [
            for (final service in services)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: sampleSalons.isEmpty
                    ? null
                    : () => _openQuickBooking(context, service.$2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF0E6D5),
                        child: Icon(service.$1, color: const Color(0xFF6F5429)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.$2.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            service.$3,
                            style: const TextStyle(color: Color(0xFF9B6B24)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonSection(BuildContext context) {
    return _contentWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('ĐỊA ĐIỂM NỔI BẬT', 'SALON ĐƯỢC YÊU THÍCH'),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 900;
                final double width = wide
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final salon in sampleSalons)
                      SizedBox(
                        width: width,
                        child: _buildSalonCard(context, salon),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(String eyebrow, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF9B6B24),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: .4,
          ),
        ),
      ],
    );
  }

  Widget _buildSalonCard(BuildContext context, Salon salon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSalon(context, salon),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 180,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
                child: Image.asset(
                  'assets/images/login_barbershop_background.jpg',
                  width: 132,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: _gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${salon.rating}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: _muted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${salon.distance} km',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        salon.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, height: 1.35),
                      ),
                      const Spacer(),
                      const Row(
                        children: [
                          Text(
                            'Xem salon',
                            style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: _gold,
                          ),
                        ],
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

  Widget _contentWidth({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1420),
        child: child,
      ),
    );
  }

  void _showStyleDetail(BuildContext context, String name, String detail) {
    final selectedHairstyle = defaultHairstyles.firstWhere(
      (hairstyle) => hairstyle.name == name,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: _gold,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: sampleSalons.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _openQuickBooking(
                          context,
                          hairStyling,
                          selectedHairstyle: selectedHairstyle,
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _ink,
                ),
                child: const Text('Đặt lịch với kiểu tóc này'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
