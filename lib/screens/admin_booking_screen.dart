import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../models/salon.dart';
import '../services/voucher_service.dart';

enum _BookingFilter { active, cancelled, completed }

class AdminBookingScreen extends StatefulWidget {
  const AdminBookingScreen({super.key});

  @override
  State<AdminBookingScreen> createState() => _AdminBookingScreenState();
}

class _AdminBookingScreenState extends State<AdminBookingScreen> {
  static const Color _ink = Color(0xFF08111E);
  static const Color _surface = Color(0xF2121B28);
  static const Color _field = Color(0xFF182432);
  static const Color _gold = Color(0xFFF6C768);
  static const Color _muted = Color(0xFFB8C0CC);

  final Set<String> _updatingBookingIds = <String>{};
  late String _selectedSalonId;
  _BookingFilter _selectedFilter = _BookingFilter.active;
  Timer? _relativeTimeTicker;

  @override
  void initState() {
    super.initState();
    _selectedSalonId = sampleSalons.first.id;
    _relativeTimeTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relativeTimeTicker?.cancel();
    super.dispose();
  }

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${dateTime.year}';
  }

  String _relativeCreatedTime(DateTime? createdAt) {
    if (createdAt == null) return 'Vừa đăng ký';
    final difference = DateTime.now().difference(createdAt);
    if (difference.isNegative || difference.inSeconds < 45)
      return 'Vừa đăng ký';
    if (difference.inMinutes < 60) {
      return 'Đã đăng ký ${difference.inMinutes} phút trước';
    }
    if (difference.inHours < 24) {
      return 'Đã đăng ký ${difference.inHours} giờ trước';
    }
    if (difference.inDays < 7) {
      return 'Đã đăng ký ${difference.inDays} ngày trước';
    }
    return 'Đăng ký ngày ${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  }

  String _statusText(String status, {required bool isPaid}) {
    if (isPaid && (status == 'pending' || status == 'confirmed')) {
      return 'Đã xác nhận tự động';
    }
    return switch (status) {
      'pending' => 'Chờ admin xác nhận',
      'confirmed' => 'Đã xác nhận',
      'completed' => 'Đã hoàn thành',
      'cancelled' => 'Đã hủy',
      _ => 'Không xác định',
    };
  }

  Color _statusColor(String status, {required bool isPaid}) {
    if (isPaid && (status == 'pending' || status == 'confirmed')) {
      return const Color(0xFF59D38C);
    }
    return switch (status) {
      'pending' => const Color(0xFFFFB648),
      'confirmed' => const Color(0xFF63B3FF),
      'completed' => const Color(0xFF59D38C),
      'cancelled' => const Color(0xFFFF6B6B),
      _ => _muted,
    };
  }

  DateTime? _createdAt(QueryDocumentSnapshot<Map<String, dynamic>> booking) {
    return (booking.data()['createdAt'] as Timestamp?)?.toDate();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _bookingsForBranch(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    String salonId,
  ) {
    return bookings.where((booking) {
      return booking.data()['salonId'] == salonId;
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredBookings(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    final filtered = _bookingsForBranch(bookings, _selectedSalonId).where((
      booking,
    ) {
      final status = booking.data()['status'] as String? ?? 'pending';
      return switch (_selectedFilter) {
        _BookingFilter.active => status == 'pending' || status == 'confirmed',
        _BookingFilter.cancelled => status == 'cancelled',
        _BookingFilter.completed => status == 'completed',
      };
    }).toList();

    // Lịch mới đăng ký nằm trên, lịch đăng ký trước được đưa xuống dưới.
    filtered.sort((first, second) {
      final firstTime = _createdAt(first)?.millisecondsSinceEpoch ?? 0;
      final secondTime = _createdAt(second)?.millisecondsSinceEpoch ?? 0;
      return secondTime.compareTo(firstTime);
    });
    return filtered;
  }

  Future<void> _requestStatusChange({
    required String bookingId,
    required String newStatus,
  }) async {
    final action = switch (newStatus) {
      'confirmed' => 'xác nhận',
      'completed' => 'đánh dấu hoàn thành',
      'cancelled' => 'hủy',
      _ => 'cập nhật',
    };
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text(
          'Cập nhật lịch hẹn',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Bạn có chắc chắn muốn $action lịch hẹn này không?',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Không', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newStatus == 'cancelled'
                  ? const Color(0xFFD94B4B)
                  : _gold,
              foregroundColor: newStatus == 'cancelled' ? Colors.white : _ink,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (shouldUpdate == true) {
      await _updateStatus(bookingId: bookingId, newStatus: newStatus);
    }
  }

  Future<void> _updateStatus({
    required String bookingId,
    required String newStatus,
  }) async {
    setState(() => _updatingBookingIds.add(bookingId));
    try {
      if (newStatus == 'cancelled') {
        await _cancelBookingAsAdmin(bookingId);
      } else {
        await _updateBookingAndNotify(bookingId, newStatus);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật lịch hẹn.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'Tài khoản này không có quyền quản trị.'
          : error.message ?? 'Không thể cập nhật lịch hẹn.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _updatingBookingIds.remove(bookingId));
    }
  }

  ({String title, String message, String type}) _notificationForStatus(
    String status,
    String salonName,
  ) {
    return switch (status) {
      'confirmed' => (
        title: 'Lịch hẹn đã được xác nhận',
        message: '$salonName đã xác nhận lịch hẹn của bạn.',
        type: 'booking_confirmed',
      ),
      'completed' => (
        title: 'Lịch hẹn đã hoàn thành',
        message:
            'Cảm ơn bạn đã sử dụng dịch vụ tại $salonName. Hãy để lại đánh giá nhé!',
        type: 'booking_completed',
      ),
      _ => (
        title: 'Lịch hẹn đã được cập nhật',
        message: 'Trạng thái lịch hẹn tại $salonName vừa thay đổi.',
        type: 'booking_updated',
      ),
    };
  }

  Future<void> _updateBookingAndNotify(
    String bookingId,
    String newStatus,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final bookingReference = firestore.collection('bookings').doc(bookingId);
    final bookingSnapshot = await bookingReference.get();
    if (!bookingSnapshot.exists) return;
    final data = bookingSnapshot.data()!;
    final userId = data['userId']?.toString() ?? '';
    final salonName = data['salonName']?.toString() ?? 'salon';
    final notice = _notificationForStatus(newStatus, salonName);
    final batch = firestore.batch();
    batch.update(bookingReference, {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (userId.isNotEmpty) {
      final notificationReference = firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();
      batch.set(notificationReference, {
        'type': notice.type,
        'title': notice.title,
        'message': notice.message,
        'bookingId': bookingId,
        'salonId': data['salonId']?.toString() ?? '',
        'salonName': salonName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    if (newStatus == 'completed' && userId.isNotEmpty) {
      await VoucherService().awardLoyaltyVoucherIfEligible(
        userId: userId,
        bookingId: bookingId,
      );
    }
  }

  Future<void> _cancelBookingAsAdmin(String bookingId) async {
    final firestore = FirebaseFirestore.instance;
    final bookingReference = firestore.collection('bookings').doc(bookingId);
    final notificationReference = firestore
        .collection('_notification_ids')
        .doc();
    await firestore.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingReference);
      if (!bookingSnapshot.exists) return;
      final data = bookingSnapshot.data()!;
      final rawSlotIds = data['slotIds'] as List<dynamic>? ?? <dynamic>[];
      transaction.update(bookingReference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final userId = data['userId']?.toString() ?? '';
      if (userId.isNotEmpty) {
        final userNotification = firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationReference.id);
        transaction.set(userNotification, {
          'type': 'booking_cancelled',
          'title': 'Lịch hẹn đã bị hủy',
          'message': 'Lịch hẹn tại ${data['salonName'] ?? 'salon'} đã bị hủy.',
          'bookingId': bookingId,
          'salonId': data['salonId']?.toString() ?? '',
          'salonName': data['salonName']?.toString() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      for (final slotId in rawSlotIds.map((value) => value.toString())) {
        transaction.delete(firestore.collection('booking_slots').doc(slotId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .snapshots();
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_barbershop_background.jpg',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF008111E), Color(0xFF08111E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: bookingStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: _gold),
                        );
                      }
                      if (snapshot.hasError) {
                        return _emptyState(
                          Icons.cloud_off_rounded,
                          'Không thể tải danh sách lịch hẹn.',
                        );
                      }
                      final bookings =
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[
                            ...?snapshot.data?.docs,
                          ];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 980;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: wide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          width: 294,
                                          child: _buildBranchSidebar(bookings),
                                        ),
                                        Expanded(
                                          child: _buildBranchContent(bookings),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildMobileBranches(bookings),
                                        Expanded(
                                          child: _buildBranchContent(bookings),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 13),
      decoration: const BoxDecoration(
        color: Color(0xEB0B1420),
        border: Border(bottom: BorderSide(color: Color(0x33F6C768))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0x1AF6C768),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66F6C768)),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: _gold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản lý lịch hẹn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Theo dõi riêng từng chi nhánh',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSidebar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 8, 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33F6C768)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 7, 8, 12),
            child: Text(
              '3 CHI NHÁNH',
              style: TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          for (final salon in sampleSalons) ...[
            _branchButton(salon, bookings, compact: false),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileBranches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        itemCount: sampleSalons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => SizedBox(
          width: 248,
          child: _branchButton(sampleSalons[index], bookings, compact: true),
        ),
      ),
    );
  }

  Widget _branchButton(
    Salon salon,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings, {
    required bool compact,
  }) {
    final selected = salon.id == _selectedSalonId;
    final branchBookings = _bookingsForBranch(bookings, salon.id);
    final activeCount = branchBookings.where((booking) {
      final status = booking.data()['status'];
      return status == 'pending' || status == 'confirmed';
    }).length;

    return Material(
      color: selected ? const Color(0x26F6C768) : _field,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => setState(() {
          _selectedSalonId = salon.id;
          _selectedFilter = _BookingFilter.active;
        }),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? _gold : const Color(0x1FFFFFFF),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: compact ? 20 : 22,
                backgroundColor: selected ? _gold : const Color(0x1FF6C768),
                child: Icon(
                  Icons.storefront_rounded,
                  color: selected ? _ink : _gold,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name.replaceFirst('30Shine ', ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$activeCount lịch đang xử lý',
                      style: TextStyle(
                        color: selected ? _gold : _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allBookings,
  ) {
    final branchBookings = _bookingsForBranch(allBookings, _selectedSalonId);
    final filtered = _filteredBookings(allBookings);
    final selectedSalon = sampleSalons.firstWhere(
      (salon) => salon.id == _selectedSalonId,
    );
    final paidCount = branchBookings.where((booking) {
      final payment = booking.data()['payment'] as Map?;
      return payment?['status'] == 'paid';
    }).length;
    final pendingCount = branchBookings
        .where((booking) => booking.data()['status'] == 'pending')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedSalon.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedSalon.address,
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _summaryPill(
                    Icons.pending_actions_rounded,
                    '$pendingCount chờ xử lý',
                    const Color(0xFFFFB648),
                  ),
                  _summaryPill(
                    Icons.verified_rounded,
                    '$paidCount đã thanh toán',
                    const Color(0xFF59D38C),
                  ),
                  _summaryPill(
                    Icons.receipt_long_rounded,
                    '${branchBookings.length} tổng lịch',
                    const Color(0xFF63B3FF),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _filterBar(branchBookings),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState(
                  _filterIcon(_selectedFilter),
                  _filterEmptyMessage(_selectedFilter),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 18, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 15),
                  itemBuilder: (_, index) {
                    final booking = filtered[index];
                    return _buildBookingCard(
                      bookingId: booking.id,
                      data: booking.data(),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _summaryPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> branchBookings,
  ) {
    int countFor(_BookingFilter filter) {
      return branchBookings.where((booking) {
        final status = booking.data()['status'];
        return switch (filter) {
          _BookingFilter.active => status == 'pending' || status == 'confirmed',
          _BookingFilter.cancelled => status == 'cancelled',
          _BookingFilter.completed => status == 'completed',
        };
      }).length;
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x33F6C768)),
      ),
      child: Row(
        children: [
          for (final filter in _BookingFilter.values)
            Expanded(child: _filterButton(filter, countFor(filter))),
        ],
      ),
    );
  }

  Widget _filterButton(_BookingFilter filter, int count) {
    final selected = filter == _selectedFilter;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _gold : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filterIcon(filter),
              size: 19,
              color: selected ? _ink : _muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_filterLabel(filter)} ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _ink : _muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_BookingFilter filter) => switch (filter) {
    _BookingFilter.active => 'Đang xử lý',
    _BookingFilter.cancelled => 'Đã hủy',
    _BookingFilter.completed => 'Hoàn thành',
  };

  IconData _filterIcon(_BookingFilter filter) => switch (filter) {
    _BookingFilter.active => Icons.pending_actions_rounded,
    _BookingFilter.cancelled => Icons.event_busy_rounded,
    _BookingFilter.completed => Icons.event_available_rounded,
  };

  String _filterEmptyMessage(_BookingFilter filter) => switch (filter) {
    _BookingFilter.active => 'Chi nhánh này không có lịch đang xử lý.',
    _BookingFilter.cancelled => 'Chi nhánh này chưa có lịch bị hủy.',
    _BookingFilter.completed => 'Chi nhánh này chưa có lịch hoàn thành.',
  };

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x44F6C768)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _gold),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required String bookingId,
    required Map<String, dynamic> data,
  }) {
    final status = data['status'] as String? ?? 'pending';
    final barberName = data['barberName'] as String? ?? 'Chưa có thợ';
    final userName = data['userName'] as String? ?? '';
    final userEmail = data['userEmail'] as String? ?? '';
    final totalPrice = (data['totalPrice'] as num?)?.toInt() ?? 0;
    final totalDuration = (data['totalDurationMinutes'] as num?)?.toInt() ?? 0;
    final appointmentAt = (data['appointmentAt'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final services = data['services'] as List<dynamic>? ?? <dynamic>[];
    final serviceNames = services
        .map(
          (service) => service is Map ? service['name']?.toString() ?? '' : '',
        )
        .where((name) => name.isNotEmpty)
        .toList();
    final payment = Map<String, dynamic>.from(
      data['payment'] as Map? ?? const <String, dynamic>{},
    );
    final paymentStatus = payment['status']?.toString() ?? 'unpaid';
    final paymentChoice = payment['choice']?.toString() ?? 'pay_later';
    final isPaid = paymentStatus == 'paid';
    final voucher = data['voucher'] is Map
        ? Map<String, dynamic>.from(data['voucher'] as Map)
        : const <String, dynamic>{};
    final voucherCode = voucher['code']?.toString() ?? '';
    final discountPercent =
        (voucher['discountPercent'] as num?)?.toInt() ?? 0;
    final discountAmount =
        (data['discountAmount'] as num?)?.toInt() ?? 0;
    final hairstyle = data['hairstyle'] is Map
        ? Map<String, dynamic>.from(data['hairstyle'] as Map)
        : const <String, dynamic>{};
    final hairstyleName = hairstyle['name']?.toString() ?? '';
    final effectiveStatus = isPaid && status == 'pending'
        ? 'confirmed'
        : status;
    final isUpdating = _updatingBookingIds.contains(bookingId);
    final statusColor = _statusColor(effectiveStatus, isPaid: isPaid);

    late final String paymentLabel;
    late final Color paymentColor;
    late final IconData paymentIcon;
    if (isPaid) {
      paymentLabel = 'Đã thanh toán qua VNPAY Sandbox';
      paymentColor = const Color(0xFF59D38C);
      paymentIcon = Icons.verified_rounded;
    } else if (paymentStatus == 'pending') {
      paymentLabel = 'Đang thanh toán qua VNPAY';
      paymentColor = const Color(0xFFFFB648);
      paymentIcon = Icons.hourglass_top_rounded;
    } else if (paymentChoice == 'pay_later') {
      paymentLabel = 'Thanh toán sau tại salon';
      paymentColor = _gold;
      paymentIcon = Icons.payments_outlined;
    } else {
      paymentLabel = 'Chưa thanh toán qua VNPAY';
      paymentColor = const Color(0xFFFFB648);
      paymentIcon = Icons.account_balance_wallet_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x44F6C768)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(height: 3, color: statusColor),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hairstyleThumbnail(hairstyle),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hairstyleName.isEmpty
                                  ? 'Khách chưa chọn mẫu tóc'
                                  : hairstyleName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 8,
                              runSpacing: 7,
                              children: [
                                _statusChip(
                                  _statusText(effectiveStatus, isPaid: isPaid),
                                  statusColor,
                                ),
                                _statusChip(
                                  _relativeCreatedTime(createdAt),
                                  const Color(0xFF9EC5FF),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isUpdating)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              color: _gold,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _field,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Khách hàng',
                          value: userName.isEmpty
                              ? userEmail
                              : '$userName ($userEmail)',
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Thợ',
                          value: barberName,
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Lịch hẹn',
                          value: appointmentAt == null
                              ? 'Chưa xác định'
                              : _formatDateTime(appointmentAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    serviceNames.isEmpty
                        ? 'Không có thông tin dịch vụ'
                        : serviceNames.join(' • '),
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      const Icon(
                        Icons.timelapse_rounded,
                        color: _muted,
                        size: 20,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$totalDuration phút',
                        style: const TextStyle(color: _muted),
                      ),
                      const Spacer(),
                      Text(
                        _formatPrice(totalPrice),
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  _paymentBanner(paymentIcon, paymentLabel, paymentColor),
                  if (voucherCode.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _paymentBanner(
                      Icons.confirmation_number_rounded,
                      'Voucher $voucherCode · giảm $discountPercent% '
                      '(-${_formatPrice(discountAmount)})',
                      _gold,
                    ),
                  ],
                  if (!isUpdating &&
                      (effectiveStatus == 'pending' ||
                          effectiveStatus == 'confirmed')) ...[
                    const SizedBox(height: 14),
                    _actionButtons(
                      bookingId: bookingId,
                      status: effectiveStatus,
                      paymentChoice: paymentChoice,
                      isPaid: isPaid,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hairstyleThumbnail(Map<String, dynamic> hairstyle) {
    final imageUrl = hairstyle['imageUrl']?.toString() ?? '';
    final assetPath = hairstyle['assetPath']?.toString() ?? '';
    Widget image;
    if (imageUrl.isNotEmpty) {
      image = Image.network(imageUrl, fit: BoxFit.cover);
    } else if (assetPath.isNotEmpty) {
      image = Image.asset(assetPath, fit: BoxFit.cover);
    } else {
      image = const ColoredBox(
        color: Color(0x1FF6C768),
        child: Icon(Icons.content_cut_rounded, color: _gold, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(width: 58, height: 58, child: image),
    );
  }

  Widget _actionButtons({
    required String bookingId,
    required String status,
    required String paymentChoice,
    required bool isPaid,
  }) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 9,
      runSpacing: 9,
      children: [
        if (status == 'pending' && paymentChoice == 'pay_later' && !isPaid)
          FilledButton.icon(
            onPressed: () => _requestStatusChange(
              bookingId: bookingId,
              newStatus: 'confirmed',
            ),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Xác nhận lịch'),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
            ),
          ),
        if (status == 'confirmed')
          FilledButton.icon(
            onPressed: () => _requestStatusChange(
              bookingId: bookingId,
              newStatus: 'completed',
            ),
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Hoàn thành'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF59D38C),
              foregroundColor: _ink,
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _requestStatusChange(
            bookingId: bookingId,
            newStatus: 'cancelled',
          ),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Hủy lịch'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF7777),
            side: const BorderSide(color: Color(0x88FF7777)),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(95)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _paymentBanner(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _gold),
        const SizedBox(width: 9),
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
