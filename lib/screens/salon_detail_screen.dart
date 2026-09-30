import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';
import '../services/barber_service.dart';
import '../services/hair_service_catalog.dart';
import '../services/salon_contact_service.dart';
import 'service_selection_screen.dart';

class SalonDetailScreen extends StatefulWidget {
  final Salon salon;

  const SalonDetailScreen({super.key, required this.salon});

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  static const _ink = Color(0xFF061427);
  static const _panel = Color(0xFF0E223B);
  static const _field = Color(0xFF152D49);
  static const _gold = Color(0xFFF4C567);
  static const _muted = Color(0xFFABB8C9);

  static const _sections = [
    (Icons.storefront_rounded, 'Chi nhánh'),
    (Icons.content_cut_rounded, 'Dịch vụ'),
    (Icons.people_alt_rounded, 'Nhân viên'),
    (Icons.star_rounded, 'Đánh giá'),
  ];

  final PageController _pageController = PageController();
  final BarberService _barberService = BarberService();
  final HairServiceCatalog _serviceCatalog = HairServiceCatalog();
  final SalonContactService _contactService = SalonContactService();
  StreamSubscription<String>? _hotlineSubscription;
  late String _hotline;

  @override
  void initState() {
    super.initState();
    _hotline = widget.salon.hotline;
    _hotlineSubscription = _contactService
        .watchHotline(widget.salon)
        .listen((value) {
          if (mounted && value != _hotline) {
            setState(() => _hotline = value);
          }
        }, onError: (_) {});
  }

  Future<void> _callHotline() async {
    final phone = _hotline.replaceAll(RegExp(r'[^0-9+]'), '');
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hotline: $_hotline')),
      );
    }
  }

  int _selectedSection = 0;

  @override
  void dispose() {
    _hotlineSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _bookNow() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceSelectionScreen(
          salon: widget.salon.copyWith(hotline: _hotline),
        ),
      ),
    );
  }

  void _goToSection(int index) {
    setState(() => _selectedSection = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _report({
    required String type,
    required String targetId,
    required String targetName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Gửi báo cáo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Bạn muốn báo cáo thông tin “$targetName” để admin kiểm tra?',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'type': type,
        'targetId': targetId,
        'targetName': targetName,
        'salonId': widget.salon.id,
        'salonName': widget.salon.name,
        'reporterId': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi báo cáo tới quản trị viên.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể gửi báo cáo: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1050) {
              return _wideLayout();
            }
            return _mobileLayout();
          },
        ),
      ),
    );
  }

  Widget _wideLayout() {
    return Column(
      children: [
        _header(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 310, child: _branchPanel()),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _desktopTabs(),
                      const SizedBox(height: 12),
                      Expanded(child: _sectionContent(_selectedSection)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(width: 310, child: _bookingPanel()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return Column(
      children: [
        _header(),
        _mobileStepper(),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _selectedSection = index);
            },
            children: [
              _branchPage(),
              _servicesPage(),
              _employeesPage(),
              _reviewsPage(),
            ],
          ),
        ),
        _mobileBookingBar(),
      ],
    );
  }

  Widget _header() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF081A30),
        border: Border(bottom: BorderSide(color: Color(0x44F4C567))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.content_cut_rounded, color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.salon.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileStepper() {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        scrollDirection: Axis.horizontal,
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedSection;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(
              _sections[index].$1,
              size: 18,
              color: selected ? _ink : _muted,
            ),
            label: Text(_sections[index].$2),
            selectedColor: _gold,
            backgroundColor: _field,
            side: BorderSide(
              color: selected ? _gold : const Color(0x445D7390),
            ),
            labelStyle: TextStyle(
              color: selected ? _ink : Colors.white,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) => _goToSection(index),
          );
        },
      ),
    );
  }

  Widget _desktopTabs() {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(7),
      decoration: _panelDecoration(),
      child: Row(
        children: List.generate(_sections.length, (index) {
          final selected = index == _selectedSection;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedSection = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected ? _gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _sections[index].$1,
                        color: selected ? _ink : _muted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _sections[index].$2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? _ink : Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionContent(int index) {
    return switch (index) {
      0 => _branchPage(),
      1 => _servicesPage(),
      2 => _employeesPage(),
      _ => _reviewsPage(),
    };
  }

  Widget _branchPanel() {
    return Container(
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 245,
            child: Image.asset(
              'assets/images/login_barbershop_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: _branchInformation(compact: true),
          ),
        ],
      ),
    );
  }

  Widget _branchPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            image: const DecorationImage(
              image: AssetImage(
                'assets/images/login_barbershop_background.jpg',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE0061427)],
              ),
            ),
            padding: const EdgeInsets.all(18),
            alignment: Alignment.bottomLeft,
            child: Text(
              widget.salon.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(),
          child: _branchInformation(),
        ),
      ],
    );
  }

  Widget _branchInformation({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Text(
            widget.salon.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        if (compact) const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: _gold, size: 21),
            Text(
              ' ${widget.salon.rating}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.location_on_outlined, color: _muted, size: 20),
            Text(
              ' ${widget.salon.distance} km',
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _infoRow(Icons.place_rounded, widget.salon.address),
        const SizedBox(height: 12),
        _infoRow(
          Icons.schedule_rounded,
          'Mở cửa: ${widget.salon.openingTime} – ${widget.salon.closingTime}',
          color: const Color(0xFF5DDB91),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: _gold, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hotline: $_hotline',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _callHotline,
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('Gọi ngay'),
              style: TextButton.styleFrom(foregroundColor: _gold),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _field,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              _FacilityRow(
                icon: Icons.local_parking_rounded,
                label: 'Có chỗ để xe',
              ),
              SizedBox(height: 10),
              _FacilityRow(
                icon: Icons.wifi_rounded,
                label: 'Wi-Fi miễn phí',
              ),
              SizedBox(height: 10),
              _FacilityRow(
                icon: Icons.ac_unit_rounded,
                label: 'Không gian máy lạnh',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text, {Color color = _muted}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _servicesPage() {
    return StreamBuilder<List<HairService>>(
      stream: _serviceCatalog.watchActive(),
      builder: (context, snapshot) {
        final services = snapshot.data ?? widget.salon.services;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          children: [
            _sectionHeading(
              'Dịch vụ tại salon',
              'Chọn dịch vụ ở bước đặt lịch tiếp theo',
            ),
            const SizedBox(height: 12),
            ...services.map(_serviceCard),
          ],
        );
      },
    );
  }

  Widget _serviceCard(HairService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0x22F4C567),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(_serviceIcon(service.id), color: _gold, size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${service.durationMinutes} phút • ${_price(service.price)}',
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  service.description,
                  style: const TextStyle(color: _muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _serviceIcon(String id) {
    if (id.contains('combo')) return Icons.workspace_premium_rounded;
    if (id.contains('wash')) return Icons.shower_rounded;
    if (id.contains('dye')) return Icons.colorize_rounded;
    if (id.contains('care')) return Icons.spa_rounded;
    return Icons.content_cut_rounded;
  }

  String _formatBookingDate(Map<String, dynamic> booking) {
    final timestamp = booking['appointmentAt'] as Timestamp?;
    if (timestamp == null) {
      return 'Lịch đã hoàn thành';
    }
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${date.year}';
  }

  Future<void> _startReview({Barber? barber}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để đánh giá.')),
      );
      return;
    }

    try {
      final bookingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .get();
      final bookings = bookingSnapshot.docs.where((document) {
        final data = document.data();
        return data['status'] == 'completed' &&
            data['salonId'] == widget.salon.id &&
            (barber == null || data['barberId'] == barber.id);
      }).toList();
      bookings.sort((first, second) {
        final firstTime =
            (first.data()['appointmentAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
        final secondTime =
            (second.data()['appointmentAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
        return secondTime.compareTo(firstTime);
      });

      if (!mounted) {
        return;
      }
      if (bookings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              barber == null
                  ? 'Bạn cần hoàn thành một lịch tại chi nhánh này trước khi đánh giá.'
                  : 'Bạn chưa có lịch đã hoàn thành với thợ ${barber.name}.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final reviewSnapshots = await Future.wait(
        bookings.map(
          (booking) => FirebaseFirestore.instance
              .collection('reviews')
              .doc(booking.id)
              .get(),
        ),
      );
      if (!mounted) {
        return;
      }

      int selectedIndex = reviewSnapshots.indexWhere(
        (review) => !review.exists,
      );
      if (selectedIndex < 0) {
        selectedIndex = 0;
      }
      if (bookings.length > 1) {
        final chosen = await showModalBottomSheet<int>(
          context: context,
          backgroundColor: _panel,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.42,
            maxChildSize: 0.9,
            builder: (context, scrollController) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn lịch muốn đánh giá',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: bookings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final booking = bookings[index].data();
                          final reviewed = reviewSnapshots[index].exists;
                          return ListTile(
                            tileColor: _field,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Icon(
                              reviewed
                                  ? Icons.rate_review_rounded
                                  : Icons.star_outline_rounded,
                              color: _gold,
                            ),
                            title: Text(
                              booking['barberName']?.toString() ??
                                  'Thợ phục vụ',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${_formatBookingDate(booking)} • '
                              '${reviewed ? 'Đã đánh giá' : 'Chưa đánh giá'}',
                              style: const TextStyle(color: _muted),
                            ),
                            onTap: () => Navigator.pop(context, index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (chosen == null) {
          return;
        }
        selectedIndex = chosen;
      }

      await _showReviewDialog(
        bookingId: bookings[selectedIndex].id,
        booking: bookings[selectedIndex].data(),
        existingReview: reviewSnapshots[selectedIndex].data(),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải lịch để đánh giá: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReviewDialog({
    required String bookingId,
    required Map<String, dynamic> booking,
    Map<String, dynamic>? existingReview,
  }) async {
    int barberRating = (existingReview?['barberRating'] as num?)?.toInt() ?? 5;
    int salonRating = (existingReview?['salonRating'] as num?)?.toInt() ?? 5;
    final commentController = TextEditingController(
      text: existingReview?['comment']?.toString() ?? '',
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: Text(
            existingReview == null ? 'Đánh giá trải nghiệm' : 'Sửa đánh giá',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thợ ${booking['barberName'] ?? 'phục vụ'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _starSelector(
                    value: barberRating,
                    onChanged: (value) {
                      setDialogState(() => barberRating = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    booking['salonName']?.toString() ?? widget.salon.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _starSelector(
                    value: salonRating,
                    onChanged: (value) {
                      setDialogState(() => salonRating = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Chia sẻ cảm nhận của bạn',
                      labelStyle: const TextStyle(color: _muted),
                      filled: true,
                      fillColor: _field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau', style: TextStyle(color: _muted)),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true) {
      commentController.dispose();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      commentController.dispose();
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('reviews').doc(bookingId).set(
        {
          'bookingId': bookingId,
          'userId': user.uid,
          'salonId': booking['salonId']?.toString() ?? widget.salon.id,
          'salonName': booking['salonName']?.toString() ?? widget.salon.name,
          'barberId': booking['barberId']?.toString() ?? '',
          'barberName': booking['barberName']?.toString() ?? '',
          'salonRating': salonRating,
          'barberRating': barberRating,
          'comment': commentController.text.trim(),
          if (existingReview == null) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu đánh giá: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      commentController.dispose();
    }
  }

  Widget _starSelector({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Wrap(
      children: List.generate(5, (index) {
        final rating = index + 1;
        return IconButton(
          tooltip: '$rating sao',
          onPressed: () => onChanged(rating),
          icon: Icon(
            rating <= value ? Icons.star_rounded : Icons.star_border_rounded,
            color: _gold,
          ),
        );
      }),
    );
  }

  Widget _employeesPage() {
    return StreamBuilder<List<Barber>>(
      stream: _barberService.watchBySalon(widget.salon.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _gold),
          );
        }
        final employees = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          children: [
            _sectionHeading(
              'Đội ngũ nhân viên',
              'Xem hồ sơ, kinh nghiệm và đánh giá của từng thợ',
            ),
            const SizedBox(height: 12),
            ...employees.map(_employeeCard),
          ],
        );
      },
    );
  }

  Widget _employeeCard(Barber barber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: _field,
            backgroundImage: barber.imageUrl?.isNotEmpty == true
                ? NetworkImage(barber.imageUrl!)
                : null,
            child: barber.imageUrl?.isNotEmpty == true
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: _gold,
                    size: 45,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barber.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${barber.age} tuổi • ${barber.gender} • '
                  '${barber.experienceYears} năm kinh nghiệm',
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: barber.skills
                      .map(
                        (skill) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _field,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _gold, size: 19),
                    Text(
                      ' ${barber.rating}  (${barber.reviewCount} đánh giá)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showEmployeeProfile(barber),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: _gold),
                      ),
                      child: const Text('Xem thông tin'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _startReview(barber: barber),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _ink,
                      ),
                      icon: const Icon(Icons.star_rounded, size: 18),
                      label: const Text('Đánh giá'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Báo cáo thông tin',
            onPressed: () => _report(
              type: 'employee',
              targetId: barber.id,
              targetName: barber.name,
            ),
            icon: const Icon(Icons.flag_outlined, color: _muted),
          ),
        ],
      ),
    );
  }

  void _showEmployeeProfile(Barber barber) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                barber.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${barber.age} tuổi • ${barber.gender} • '
                '${barber.experienceYears} năm kinh nghiệm',
                style: const TextStyle(color: _gold),
              ),
              const SizedBox(height: 14),
              Text(
                barber.bio,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _bookNow();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _ink,
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Đặt lịch tại chi nhánh'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('salonId', isEqualTo: widget.salon.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _gold),
          );
        }
        final reviews = [...snapshot.data!.docs];
        reviews.sort((first, second) {
          final firstTime =
              (first.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  0;
          final secondTime =
              (second.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  0;
          return secondTime.compareTo(firstTime);
        });
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          children: [
            _reviewSummary(reviews),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () => _startReview(),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _ink,
                ),
                icon: const Icon(Icons.rate_review_rounded),
                label: const Text(
                  'Viết đánh giá cho chi nhánh',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              _emptyReviews()
            else
              ...reviews.map((review) => _reviewCard(review.id, review.data())),
          ],
        );
      },
    );
  }

  Widget _reviewSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
  ) {
    final average = reviews.isEmpty
        ? widget.salon.rating
        : reviews
                .map(
                  (review) =>
                      (review.data()['salonRating'] as num?)?.toDouble() ?? 0,
                )
                .fold<double>(0, (sum, value) => sum + value) /
            reviews.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: const TextStyle(
              color: _gold,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_rounded, color: _gold),
                    Icon(Icons.star_rounded, color: _gold),
                    Icon(Icons.star_rounded, color: _gold),
                    Icon(Icons.star_rounded, color: _gold),
                    Icon(Icons.star_half_rounded, color: _gold),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${reviews.length} đánh giá đã xác thực',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyReviews() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: _panelDecoration(),
      child: const Column(
        children: [
          Icon(Icons.rate_review_outlined, color: _gold, size: 48),
          SizedBox(height: 10),
          Text(
            'Chưa có đánh giá',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Đánh giá từ các lịch đã hoàn thành sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(String id, Map<String, dynamic> data) {
    final rating = (data['salonRating'] as num?)?.toInt() ?? 0;
    final comment = data['comment']?.toString() ?? '';
    final barberName = data['barberName']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: _panelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: _field,
            foregroundColor: _gold,
            child: Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khách hàng đã xác thực',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  List<String>.generate(
                    5,
                    (index) => index < rating ? '★' : '☆',
                  ).join(),
                  style: const TextStyle(color: _gold, fontSize: 18),
                ),
                if (barberName.isNotEmpty)
                  Text(
                    'Thợ phục vụ: $barberName',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: const TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Báo cáo đánh giá',
            onPressed: () => _report(
              type: 'review',
              targetId: id,
              targetName: comment.isEmpty ? 'Đánh giá' : comment,
            ),
            icon: const Icon(Icons.flag_outlined, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _bookingPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: _gold),
              SizedBox(width: 9),
              Text(
                'Lịch hẹn của bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _summaryRow(Icons.storefront_rounded, widget.salon.name),
          const SizedBox(height: 12),
          _summaryRow(
            Icons.schedule_rounded,
            'Mở cửa từ ${widget.salon.openingTime}',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Text(
              'Chọn dịch vụ, nhân viên và thời gian ở các bước tiếp theo. '
              'Bạn có thể thanh toán ngay qua VNPAY hoặc thanh toán sau.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _bookNow,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text(
                'Tiếp tục đặt lịch',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _gold, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _mobileBookingBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF081A30),
        border: Border(top: BorderSide(color: Color(0x44F4C567))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mở cửa ${widget.salon.openingTime}–${widget.salon.closingTime}',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _bookNow,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 14,
              ),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: const Text(
              'Đặt lịch',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted)),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: const Color(0x445D7390)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  String _price(int price) => '${price ~/ 1000}.000đ';
}

class _FacilityRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FacilityRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _SalonDetailScreenState._gold, size: 20),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: _SalonDetailScreenState._muted,
          ),
        ),
      ],
    );
  }
}
