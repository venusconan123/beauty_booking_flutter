import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/booking_service.dart';
import '../services/vnpay_payment_service.dart';

enum _BookingSection { registered, confirmed, completed }

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  static const Color _ink = Color(0xFF08111E);
  static const Color _surface = Color(0xF2121B28);
  static const Color _field = Color(0xFF182432);
  static const Color _gold = Color(0xFFF6C768);
  static const Color _muted = Color(0xFFB8C0CC);

  final Set<String> _startingPaymentIds = <String>{};
  _BookingSection _selectedSection = _BookingSection.registered;

  bool _belongsToSelectedSection(String status) {
    return switch (_selectedSection) {
      _BookingSection.registered =>
        status == 'pending' || status == 'cancelled',
      _BookingSection.confirmed => status == 'confirmed',
      _BookingSection.completed => status == 'completed',
    };
  }

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';

  String _ratingStars(int rating) =>
      List<String>.generate(5, (index) => index < rating ? '★' : '☆').join();

  String _formatDateTime(DateTime dateTime) {
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${dateTime.year}';
  }

  String _getStatusText(String status) {
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

  Color _getStatusColor(String status) {
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

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        icon: const Icon(
          Icons.event_busy_rounded,
          color: Color(0xFFFF6B6B),
          size: 46,
        ),
        title: const Text(
          'Hủy lịch hẹn',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn hủy lịch hẹn này không?',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Giữ lịch', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD94B4B),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để hủy lịch hẹn.')),
      );
      return;
    }

    try {
      await BookingService().cancelBooking(
        bookingId: bookingId,
        userId: user.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy lịch hẹn.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Bạn không có quyền hủy lịch này.'
                : 'Không thể hủy lịch hẹn: ${error.message}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startVnpayPayment(
    BuildContext context,
    String bookingId,
  ) async {
    if (_startingPaymentIds.contains(bookingId)) return;
    setState(() => _startingPaymentIds.add(bookingId));
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const VnpayPaymentException(
          'Bạn cần đăng nhập trước khi thanh toán.',
        );
      }
      final Uri paymentUri = await VnpayPaymentService().createPaymentUrl(
        bookingId: bookingId,
        user: user,
      );
      final bool opened = await launchUrl(
        paymentUri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened) {
        throw const VnpayPaymentException(
          'Không thể mở cổng thanh toán VNPAY.',
        );
      }
    } on VnpayPaymentException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể bắt đầu thanh toán: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _startingPaymentIds.remove(bookingId));
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
          backgroundColor: _surface,
          title: Text(
            existingReview == null ? 'Đánh giá trải nghiệm' : 'Sửa đánh giá',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    onChanged: (value) =>
                        setDialogState(() => barberRating = value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    booking['salonName']?.toString() ?? 'Chi nhánh',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _starSelector(
                    value: salonRating,
                    onChanged: (value) =>
                        setDialogState(() => salonRating = value),
                  ),
                  const SizedBox(height: 18),
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
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0x44F6C768)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Để sau', style: TextStyle(color: _muted)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Gửi đánh giá',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('reviews').doc(bookingId).set(
        {
          'bookingId': bookingId,
          'userId': user.uid,
          'salonId': booking['salonId']?.toString() ?? '',
          'salonName': booking['salonName']?.toString() ?? '',
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
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
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
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(rating),
          icon: Icon(
            rating <= value ? Icons.star_rounded : Icons.star_border_rounded,
            color: _gold,
            size: 31,
          ),
        );
      }),
    );
  }

  Widget _reviewPanel({
    required String bookingId,
    required Map<String, dynamic> booking,
  }) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('reviews')
          .doc(bookingId)
          .get(),
      builder: (context, snapshot) {
        final review = snapshot.data?.data();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 14),
            child: LinearProgressIndicator(
              color: _gold,
              backgroundColor: _field,
            ),
          );
        }
        if (review == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () =>
                    _showReviewDialog(bookingId: bookingId, booking: booking),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _ink,
                ),
                icon: const Icon(Icons.star_rounded),
                label: const Text(
                  'Đánh giá thợ và chi nhánh',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          );
        }
        final barberRating = (review['barberRating'] as num?)?.toInt() ?? 0;
        final salonRating = (review['salonRating'] as num?)?.toInt() ?? 0;
        final comment = review['comment']?.toString() ?? '';
        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x1AF6C768),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x55F6C768)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.reviews_rounded, color: _gold),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Đánh giá của bạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showReviewDialog(
                      bookingId: bookingId,
                      booking: booking,
                      existingReview: review,
                    ),
                    child: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(color: _gold),
                    ),
                  ),
                ],
              ),
              Text(
                'Thợ: ${_ratingStars(barberRating)}',
                style: const TextStyle(color: _gold),
              ),
              const SizedBox(height: 4),
              Text(
                'Chi nhánh: ${_ratingStars(salonRating)}',
                style: const TextStyle(color: _gold),
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  comment,
                  style: const TextStyle(color: _muted, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _pageShell(
        child: _messageState(
          icon: Icons.lock_outline_rounded,
          title: 'Bạn chưa đăng nhập',
          message: 'Đăng nhập để xem và quản lý các lịch hẹn của bạn.',
        ),
      );
    }

    final bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return _pageShell(
      child: Column(
        children: [
          _sectionSelector(),
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
                  return _messageState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Không thể tải lịch hẹn',
                    message: '${snapshot.error}',
                  );
                }

                final bookings =
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[
                      ...?snapshot.data?.docs,
                    ].where((booking) {
                      final status =
                          booking.data()['status']?.toString() ?? 'pending';
                      return _belongsToSelectedSection(status);
                    }).toList();
                bookings.sort((first, second) {
                  final firstTimestamp =
                      first.data()['appointmentAt'] as Timestamp?;
                  final secondTimestamp =
                      second.data()['appointmentAt'] as Timestamp?;
                  final firstDate =
                      firstTimestamp?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final secondDate =
                      secondTimestamp?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return secondDate.compareTo(firstDate);
                });

                if (bookings.isEmpty) {
                  return _messageState(
                    icon: Icons.event_note_rounded,
                    title: 'Chưa có lịch trong mục này',
                    message: switch (_selectedSection) {
                      _BookingSection.registered =>
                        'Lịch mới đăng ký hoặc đã hủy sẽ xuất hiện tại đây.',
                      _BookingSection.confirmed =>
                        'Lịch được salon xác nhận sẽ xuất hiện tại đây.',
                      _BookingSection.completed =>
                        'Lịch đã hoàn thành sẽ xuất hiện tại đây để bạn đánh giá.',
                    },
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double horizontal = constraints.maxWidth >= 900
                        ? 32
                        : 16;
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        18,
                        horizontal,
                        32,
                      ),
                      itemCount: bookings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return _buildBookingCard(
                          context: context,
                          bookingId: booking.id,
                          data: booking.data(),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionSelector() {
    const items = <(_BookingSection, IconData, String)>[
      (_BookingSection.registered, Icons.edit_calendar_rounded, 'Đã đăng ký'),
      (_BookingSection.confirmed, Icons.event_available_rounded, 'Đã xác nhận'),
      (_BookingSection.completed, Icons.task_alt_rounded, 'Đã hoàn thành'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: items.map((item) {
          final selected = item.$1 == _selectedSection;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _selectedSection = item.$1),
              avatar: Icon(item.$2, size: 19, color: selected ? _ink : _muted),
              label: Text(item.$3),
              labelStyle: TextStyle(
                color: selected ? _ink : Colors.white,
                fontWeight: FontWeight.w800,
              ),
              selectedColor: _gold,
              backgroundColor: _field,
              side: BorderSide(
                color: selected ? _gold : const Color(0x44F6C768),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _pageShell({required Widget child}) {
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
                colors: [Color(0xE608111E), Color(0xFA08111E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1060),
                      child: child,
                    ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 14),
      decoration: const BoxDecoration(
        color: Color(0xD90B1420),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1AF6C768),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66F6C768)),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: _gold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch hẹn của tôi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Theo dõi lịch và trạng thái thanh toán',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x55F6C768)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _gold),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required BuildContext context,
    required String bookingId,
    required Map<String, dynamic> data,
  }) {
    final String salonName =
        data['salonName'] as String? ?? 'Không rõ chi nhánh';
    final String salonAddress = data['salonAddress'] as String? ?? '';
    final String barberName = data['barberName'] as String? ?? 'Thợ bất kỳ';
    final String status = data['status'] as String? ?? 'pending';
    final int totalPrice = (data['totalPrice'] as num?)?.toInt() ?? 0;
    final int totalDuration =
        (data['totalDurationMinutes'] as num?)?.toInt() ?? 0;
    final Timestamp? appointmentTimestamp = data['appointmentAt'] as Timestamp?;
    final DateTime? appointmentDate = appointmentTimestamp?.toDate();
    final List<dynamic> services =
        data['services'] as List<dynamic>? ?? <dynamic>[];
    final List<String> serviceNames = services
        .map(
          (service) => service is Map ? service['name']?.toString() ?? '' : '',
        )
        .where((name) => name.isNotEmpty)
        .toList();
    final payment = Map<String, dynamic>.from(
      data['payment'] as Map? ?? const <String, dynamic>{},
    );
    final String paymentStatus = payment['status']?.toString() ?? 'unpaid';
    final String paymentChoice = payment['choice']?.toString() ?? 'pay_later';
    final bool isPaid = paymentStatus == 'paid';
    final bool isStartingPayment = _startingPaymentIds.contains(bookingId);
    final Color statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x44F6C768)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0x1FF6C768),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.content_cut_rounded,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              salonName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              serviceNames.isEmpty
                                  ? 'Dịch vụ tại salon'
                                  : serviceNames.join(' • '),
                              style: const TextStyle(
                                color: _muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _statusChip(_getStatusText(status), statusColor),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _field,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      children: [
                        if (salonAddress.isNotEmpty) ...[
                          _informationRow(
                            Icons.location_on_outlined,
                            salonAddress,
                          ),
                          const SizedBox(height: 11),
                        ],
                        _informationRow(
                          Icons.person_outline_rounded,
                          'Thợ: $barberName',
                        ),
                        const SizedBox(height: 11),
                        _informationRow(
                          Icons.schedule_rounded,
                          appointmentDate == null
                              ? 'Chưa xác định thời gian'
                              : _formatDateTime(appointmentDate),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 14),
                  if (isPaid)
                    _paymentBanner(
                      icon: Icons.verified_rounded,
                      text: payment['provider'] == 'vnpay'
                          ? 'Đã thanh toán qua VNPAY Sandbox'
                          : 'Đã thanh toán',
                      color: const Color(0xFF59D38C),
                    )
                  else if (paymentChoice == 'pay_later' &&
                      status != 'cancelled')
                    _paymentBanner(
                      icon: Icons.payments_outlined,
                      text: 'Thanh toán sau tại salon',
                      color: _gold,
                    )
                  else if (paymentStatus == 'pending')
                    _paymentBanner(
                      icon: Icons.hourglass_top_rounded,
                      text: 'Đang chờ VNPAY xác nhận thanh toán',
                      color: const Color(0xFFFFB648),
                    ),
                  if (status == 'completed')
                    _reviewPanel(bookingId: bookingId, booking: data),
                  if (!isPaid &&
                      (status == 'confirmed' ||
                          (status == 'pending' &&
                              paymentChoice == 'pay_now'))) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isStartingPayment
                            ? null
                            : () => _startVnpayPayment(context, bookingId),
                        icon: isStartingPayment
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.account_balance_wallet_rounded),
                        label: Text(
                          isStartingPayment
                              ? 'Đang mở VNPAY...'
                              : 'Thanh toán bằng VNPAY',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Thanh toán toàn bộ ${_formatPrice(totalPrice)} trên môi trường VNPAY Sandbox (không trừ tiền thật).',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (status == 'pending') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelBooking(context, bookingId),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text(
                          'Hủy lịch hẹn',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF7777),
                          side: const BorderSide(color: Color(0x88FF6B6B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
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

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(100)),
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

  Widget _informationRow(IconData icon, String text, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _gold),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentBanner({
    required IconData icon,
    required String text,
    required Color color,
  }) {
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
}
