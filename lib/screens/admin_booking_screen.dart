import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';

  String _formatDateTime(DateTime dateTime) {
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${dateTime.year}';
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'completed':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFB648);
      case 'confirmed':
        return const Color(0xFF63B3FF);
      case 'completed':
        return const Color(0xFF59D38C);
      case 'cancelled':
        return const Color(0xFFFF6B6B);
      default:
        return _muted;
    }
  }

  String _actionText(String status) {
    switch (status) {
      case 'confirmed':
        return 'xác nhận';
      case 'completed':
        return 'đánh dấu hoàn thành';
      case 'cancelled':
        return 'hủy';
      default:
        return 'cập nhật';
    }
  }

  DateTime _appointmentDate(QueryDocumentSnapshot<Map<String, dynamic>> booking) {
    final Timestamp? timestamp = booking.data()['appointmentAt'] as Timestamp?;
    return timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getActiveBookings(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    final activeBookings = bookings.where((booking) {
      final String status = booking.data()['status'] as String? ?? 'pending';
      return status == 'pending' || status == 'confirmed';
    }).toList();
    activeBookings.sort((first, second) {
      final String firstStatus = first.data()['status'] as String? ?? 'pending';
      final String secondStatus = second.data()['status'] as String? ?? 'pending';
      final int statusComparison = (firstStatus == 'pending' ? 0 : 1).compareTo(secondStatus == 'pending' ? 0 : 1);
      return statusComparison != 0 ? statusComparison : _appointmentDate(first).compareTo(_appointmentDate(second));
    });
    return activeBookings;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getBookingsByStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    String status,
  ) {
    final filtered = bookings.where((booking) => booking.data()['status'] == status).toList();
    filtered.sort((first, second) => _appointmentDate(second).compareTo(_appointmentDate(first)));
    return filtered;
  }

  Future<void> _requestStatusChange({required String bookingId, required String newStatus}) async {
    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Cập nhật lịch hẹn', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn ${_actionText(newStatus)} lịch hẹn này không?',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Không', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newStatus == 'cancelled' ? const Color(0xFFD94B4B) : _gold,
              foregroundColor: newStatus == 'cancelled' ? Colors.white : _ink,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (shouldUpdate == true) await _updateStatus(bookingId: bookingId, newStatus: newStatus);
  }

  Future<void> _updateStatus({required String bookingId, required String newStatus}) async {
    setState(() => _updatingBookingIds.add(bookingId));
    try {
      if (newStatus == 'cancelled') {
        await _cancelBookingAsAdmin(bookingId);
      } else {
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật: ${_statusText(newStatus)}.'), backgroundColor: Colors.green),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      String message = 'Không thể cập nhật lịch hẹn.';
      if (error.code == 'permission-denied') {
        message = 'Tài khoản này không có quyền quản trị.';
      } else if (error.message != null) {
        message = error.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _updatingBookingIds.remove(bookingId));
    }
  }

  Future<void> _cancelBookingAsAdmin(String bookingId) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final bookingReference = firestore.collection('bookings').doc(bookingId);
    await firestore.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingReference);
      if (!bookingSnapshot.exists) return;
      final Map<String, dynamic> data = bookingSnapshot.data()!;
      final List<dynamic> rawSlotIds = data['slotIds'] as List<dynamic>? ?? <dynamic>[];
      transaction.update(bookingReference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final String slotId in rawSlotIds.map((value) => value.toString())) {
        transaction.delete(firestore.collection('booking_slots').doc(slotId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingStream = FirebaseFirestore.instance.collection('bookings').snapshots();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/login_barbershop_background.jpg', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xEB08111E), Color(0xFC08111E)]),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: bookingStream,
                    builder: (context, snapshot) {
                      final bookings = <QueryDocumentSnapshot<Map<String, dynamic>>>[...?snapshot.data?.docs];
                      final int pendingCount = bookings.where((booking) => booking.data()['status'] == 'pending').length;
                      return _tabBar(pendingCount);
                    },
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: bookingStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: _gold));
                        }
                        if (snapshot.hasError) {
                          return _emptyState(Icons.cloud_off_rounded, 'Không thể tải danh sách lịch hẹn.');
                        }
                        final bookings = <QueryDocumentSnapshot<Map<String, dynamic>>>[...?snapshot.data?.docs];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: TabBarView(
                              children: [
                                _buildBookingList(bookings: _getActiveBookings(bookings), emptyIcon: Icons.pending_actions_rounded, emptyMessage: 'Không có lịch nào đang chờ xử lý.'),
                                _buildBookingList(bookings: _getBookingsByStatus(bookings, 'cancelled'), emptyIcon: Icons.event_busy_rounded, emptyMessage: 'Chưa có lịch nào bị hủy.'),
                                _buildBookingList(bookings: _getBookingsByStatus(bookings, 'completed'), emptyIcon: Icons.event_available_rounded, emptyMessage: 'Chưa có lịch nào hoàn thành.'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 13),
      decoration: const BoxDecoration(color: Color(0xD90B1420)),
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
            decoration: BoxDecoration(color: const Color(0x1AF6C768), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x66F6C768))),
            child: const Icon(Icons.admin_panel_settings_rounded, color: _gold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quản lý lịch hẹn', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Điều phối lịch và theo dõi thanh toán', style: TextStyle(color: _muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar(int pendingCount) {
    return Container(
      color: const Color(0xD90B1420),
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x33F6C768))),
            child: TabBar(
              dividerColor: Colors.transparent,
              labelColor: _ink,
              unselectedLabelColor: _muted,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(12)),
              tabs: [
                Tab(icon: Badge(isLabelVisible: pendingCount > 0, label: Text('$pendingCount'), child: const Icon(Icons.pending_actions_rounded)), text: 'Đang xử lý'),
                const Tab(icon: Icon(Icons.event_busy_rounded), text: 'Đã hủy'),
                const Tab(icon: Icon(Icons.event_available_rounded), text: 'Hoàn thành'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    required IconData emptyIcon,
    required String emptyMessage,
  }) {
    if (bookings.isEmpty) return _emptyState(emptyIcon, emptyMessage);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontal = constraints.maxWidth >= 900 ? 28 : 14;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 32),
          itemCount: bookings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _buildBookingCard(bookingId: booking.id, data: booking.data());
          },
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x44F6C768))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _gold),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard({required String bookingId, required Map<String, dynamic> data}) {
    final String status = data['status'] as String? ?? 'pending';
    final String salonName = data['salonName'] as String? ?? 'Không rõ salon';
    final String barberName = data['barberName'] as String? ?? 'Chưa có thợ';
    final String userName = data['userName'] as String? ?? '';
    final String userEmail = data['userEmail'] as String? ?? '';
    final int totalPrice = (data['totalPrice'] as num?)?.toInt() ?? 0;
    final int totalDuration = (data['totalDurationMinutes'] as num?)?.toInt() ?? 0;
    final DateTime? appointmentAt = (data['appointmentAt'] as Timestamp?)?.toDate();
    final List<dynamic> services = data['services'] as List<dynamic>? ?? <dynamic>[];
    final List<String> serviceNames = services
        .map((service) => service is Map ? service['name']?.toString() ?? '' : '')
        .where((name) => name.isNotEmpty)
        .toList();
    final Map<String, dynamic> payment = Map<String, dynamic>.from(data['payment'] as Map? ?? const <String, dynamic>{});
    final String paymentStatus = payment['status']?.toString() ?? 'unpaid';
    final String paymentChoice = payment['choice']?.toString() ?? 'pay_later';

    late final String paymentLabel;
    late final Color paymentColor;
    late final IconData paymentIcon;
    if (paymentStatus == 'paid') {
      paymentLabel = payment['provider'] == 'vnpay' ? 'Đã thanh toán qua VNPAY Sandbox' : 'Đã thanh toán';
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

    final bool isUpdating = _updatingBookingIds.contains(bookingId);
    final bool canUpdate = status == 'pending' || status == 'confirmed';
    final Color statusColor = _statusColor(status);

    return Container(
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x44F6C768)), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(height: 3, color: _gold),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0x1FF6C768), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.content_cut_rounded, color: _gold)),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(salonName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 7),
                          _statusChip(_statusText(status), statusColor),
                        ]),
                      ),
                      if (isUpdating)
                        const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: _gold, strokeWidth: 2)))
                      else if (canUpdate)
                        Theme(
                          data: Theme.of(context).copyWith(cardColor: _field),
                          child: PopupMenuButton<String>(
                            tooltip: 'Cập nhật trạng thái',
                            color: _field,
                            iconColor: _gold,
                            onSelected: (newStatus) => _requestStatusChange(bookingId: bookingId, newStatus: newStatus),
                            itemBuilder: (context) => [
                              if (status == 'pending' && paymentChoice == 'pay_later')
                                const PopupMenuItem(value: 'confirmed', child: Text('Xác nhận lịch', style: TextStyle(color: Colors.white))),
                              if (status == 'confirmed')
                                const PopupMenuItem(value: 'completed', child: Text('Đánh dấu hoàn thành', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'cancelled', child: Text('Hủy lịch', style: TextStyle(color: Color(0xFFFF7777)))),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(17)),
                    child: Column(
                      children: [
                        _buildInfoRow(icon: Icons.person_outline_rounded, label: 'Khách hàng', value: userName.isEmpty ? userEmail : '$userName ($userEmail)'),
                        const SizedBox(height: 10),
                        _buildInfoRow(icon: Icons.badge_outlined, label: 'Thợ', value: barberName),
                        const SizedBox(height: 10),
                        _buildInfoRow(icon: Icons.schedule_rounded, label: 'Thời gian', value: appointmentAt == null ? 'Chưa xác định' : _formatDateTime(appointmentAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(serviceNames.isEmpty ? 'Không có thông tin dịch vụ' : serviceNames.join(' • '), style: const TextStyle(color: Colors.white, height: 1.4)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.timelapse_rounded, color: _muted, size: 20),
                    const SizedBox(width: 7),
                    Text('$totalDuration phút', style: const TextStyle(color: _muted)),
                    const Spacer(),
                    Text(_formatPrice(totalPrice), style: const TextStyle(color: _gold, fontSize: 21, fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 14),
                  _paymentBanner(paymentIcon, paymentLabel, paymentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withAlpha(100))),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _paymentBanner(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withAlpha(100))),
      child: Row(children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _gold),
        const SizedBox(width: 9),
        SizedBox(width: 88, child: Text(label, style: const TextStyle(color: _muted))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.3))),
      ],
    );
  }
}
