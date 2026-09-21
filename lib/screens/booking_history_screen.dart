import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/booking_service.dart';
import '../services/vnpay_payment_service.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final Set<String> _startingPaymentIds = <String>{};

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';

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
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.event_busy, color: Colors.red, size: 48),
          title: const Text('Hủy lịch hẹn'),
          content: const Text(
            'Bạn có chắc chắn muốn hủy lịch hẹn này không?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Không'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hủy lịch'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đăng nhập để hủy lịch hẹn.'),
          backgroundColor: Colors.red,
        ),
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
      if (mounted) {
        setState(() => _startingPaymentIds.remove(bookingId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để xem lịch hẹn.')),
      );
    }

    final bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch hẹn của tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể tải lịch hẹn.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final bookings = <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ];
          bookings.sort((first, second) {
            final firstTimestamp = first.data()['appointmentAt'] as Timestamp?;
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note, size: 72, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Bạn chưa có lịch hẹn nào.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('Hãy quay lại trang chủ để đặt lịch.'),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    final appointmentTimestamp = data['appointmentAt'] as Timestamp?;
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
    final String paymentChoice =
        payment['choice']?.toString() ?? 'pay_later';
    final bool isPaid = paymentStatus == 'paid';
    final bool isStartingPayment = _startingPaymentIds.contains(bookingId);
    final Color statusColor = _getStatusColor(status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(Icons.content_cut, color: Color(0xFF1E3A5F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    salonName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (salonAddress.isNotEmpty) ...[
              const SizedBox(height: 12),
              _informationRow(Icons.location_on_outlined, salonAddress),
            ],
            const SizedBox(height: 10),
            _informationRow(Icons.person_outline, 'Thợ: $barberName'),
            const SizedBox(height: 10),
            _informationRow(
              Icons.schedule,
              appointmentDate == null
                  ? 'Chưa xác định thời gian'
                  : _formatDateTime(appointmentDate),
              bold: true,
            ),
            const SizedBox(height: 12),
            const Divider(),
            Text(
              serviceNames.isEmpty
                  ? 'Không có thông tin dịch vụ'
                  : serviceNames.join(' • '),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('$totalDuration phút'),
                const Spacer(),
                Text(
                  _formatPrice(totalPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            if (isPaid) ...[
              const SizedBox(height: 12),
              _paidBanner(payment['provider']?.toString() ?? ''),
            ] else if (paymentChoice == 'pay_later' &&
                status != 'cancelled') ...[
              const SizedBox(height: 12),
              const Text(
                'Thanh toán sau tại salon',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (paymentStatus == 'pending') ...[
              const SizedBox(height: 12),
              const Text(
                'Đang chờ VNPAY xác nhận thanh toán',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (!isPaid &&
                (status == 'confirmed' ||
                    (status == 'pending' &&
                        paymentChoice == 'pay_now'))) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isStartingPayment
                      ? null
                      : () => _startVnpayPayment(
                          context,
                          bookingId,
                        ),
                  icon: isStartingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_wallet),
                  label: Text(
                    isStartingPayment
                        ? 'Đang mở VNPAY...'
                        : 'Thanh toán bằng VNPAY',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF005BAA),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Thanh toán toàn bộ ${_formatPrice(totalPrice)} '
                'trên môi trường VNPAY Sandbox (không trừ tiền thật).',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelBooking(context, bookingId),
                  icon: const Icon(Icons.close),
                  label: const Text('Hủy lịch hẹn'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _informationRow(IconData icon, String text, {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
        ),
      ],
    );
  }

  Widget _paidBanner(String provider) {
    final bool isVnpay = provider == 'vnpay';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVnpay
                  ? 'Đã thanh toán qua VNPAY Sandbox'
                  : 'Đã thanh toán',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
