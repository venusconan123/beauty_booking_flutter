import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/booking_service.dart';

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  String _formatPrice(int price) {
    return '${price ~/ 1000}.000đ';
  }

  String _formatDateTime(DateTime dateTime) {
    final String day =
        dateTime.day.toString().padLeft(2, '0');
    final String month =
        dateTime.month.toString().padLeft(2, '0');
    final String hour =
        dateTime.hour.toString().padLeft(2, '0');
    final String minute =
        dateTime.minute.toString().padLeft(2, '0');

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

  Future<void> _cancelBooking(
    BuildContext context,
    String bookingId,
  ) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.event_busy,
            color: Colors.red,
            size: 48,
          ),
          title: const Text('Hủy lịch hẹn'),
          content: const Text(
            'Bạn có chắc chắn muốn hủy lịch hẹn này không?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Không'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hủy lịch'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

if (user == null) {
  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Bạn cần đăng nhập để hủy lịch hẹn.',
      ),
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

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy lịch hẹn.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }

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

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Bạn cần đăng nhập để xem lịch hẹn.'),
        ),
      );
    }

    final Stream<QuerySnapshot<Map<String, dynamic>>>
        bookingStream = FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch hẹn của tôi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: bookingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể tải lịch hẹn.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final bookings = [
            ...?snapshot.data?.docs,
          ];

          bookings.sort((first, second) {
            final Timestamp? firstTimestamp =
                first.data()['appointmentAt'] as Timestamp?;

            final Timestamp? secondTimestamp =
                second.data()['appointmentAt'] as Timestamp?;

            final DateTime firstDate =
                firstTimestamp?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate =
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
                    Icon(
                      Icons.event_note,
                      size: 72,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Bạn chưa có lịch hẹn nào.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Hãy quay lại trang chủ để đặt lịch.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final data = booking.data();

              return _buildBookingCard(
                context: context,
                bookingId: booking.id,
                data: data,
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

    final String salonAddress =
        data['salonAddress'] as String? ?? '';

    final String barberName =
        data['barberName'] as String? ?? 'Thợ bất kỳ';

    final String status =
        data['status'] as String? ?? 'pending';

    final int totalPrice =
        (data['totalPrice'] as num?)?.toInt() ?? 0;

    final int totalDuration =
        (data['totalDurationMinutes'] as num?)?.toInt() ??
            0;

    final Timestamp? appointmentTimestamp =
        data['appointmentAt'] as Timestamp?;

    final DateTime? appointmentDate =
        appointmentTimestamp?.toDate();

    final List<dynamic> services =
        data['services'] as List<dynamic>? ?? [];

    final List<String> serviceNames = services
        .map((service) {
          if (service is Map) {
            return service['name']?.toString() ?? '';
          }

          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

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
                  child: Icon(
                    Icons.content_cut,
                    color: Color(0xFF1E3A5F),
                  ),
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
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(salonAddress),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Thợ: $barberName'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  appointmentDate == null
                      ? 'Chưa xác định thời gian'
                      : _formatDateTime(appointmentDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _cancelBooking(
                      context,
                      bookingId,
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Hủy lịch hẹn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}