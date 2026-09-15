import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminBookingScreen extends StatefulWidget {
  const AdminBookingScreen({super.key});

  @override
  State<AdminBookingScreen> createState() {
    return _AdminBookingScreenState();
  }
}

class _AdminBookingScreenState extends State<AdminBookingScreen> {
  final Set<String> _updatingBookingIds = {};

  String _formatPrice(int price) {
    return '${price ~/ 1000}.000đ';
  }

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

  DateTime _appointmentDate(
    QueryDocumentSnapshot<Map<String, dynamic>> booking,
  ) {
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

      final String secondStatus =
          second.data()['status'] as String? ?? 'pending';

      final int firstPriority = firstStatus == 'pending' ? 0 : 1;

      final int secondPriority = secondStatus == 'pending' ? 0 : 1;

      final int statusComparison = firstPriority.compareTo(secondPriority);

      if (statusComparison != 0) {
        return statusComparison;
      }

      return _appointmentDate(first).compareTo(_appointmentDate(second));
    });

    return activeBookings;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getBookingsByStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    String status,
  ) {
    final filteredBookings = bookings.where((booking) {
      return booking.data()['status'] == status;
    }).toList();

    filteredBookings.sort((first, second) {
      return _appointmentDate(second).compareTo(_appointmentDate(first));
    });

    return filteredBookings;
  }

  Future<void> _requestStatusChange({
    required String bookingId,
    required String newStatus,
  }) async {
    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cập nhật lịch hẹn'),
          content: Text(
            'Bạn có chắc chắn muốn '
            '${_actionText(newStatus)} '
            'lịch hẹn này không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Không'),
            ),
            FilledButton(
              style: newStatus == 'cancelled'
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Đồng ý'),
            ),
          ],
        );
      },
    );

    if (shouldUpdate != true) {
      return;
    }

    await _updateStatus(bookingId: bookingId, newStatus: newStatus);
  }

  Future<void> _updateStatus({
    required String bookingId,
    required String newStatus,
  }) async {
    setState(() {
      _updatingBookingIds.add(bookingId);
    });

    try {
      if (newStatus == 'cancelled') {
        await _cancelBookingAsAdmin(bookingId);
      } else {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
              'status': newStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật: '
            '${_statusText(newStatus)}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Không thể cập nhật lịch hẹn.';

      if (error.code == 'permission-denied') {
        message = 'Tài khoản này không có quyền quản trị.';
      } else if (error.message != null) {
        message = error.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingBookingIds.remove(bookingId);
        });
      }
    }
  }

  Future<void> _cancelBookingAsAdmin(String bookingId) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final DocumentReference<Map<String, dynamic>> bookingReference = firestore
        .collection('bookings')
        .doc(bookingId);

    await firestore.runTransaction<void>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnapshot =
          await transaction.get(bookingReference);

      if (!bookingSnapshot.exists) {
        return;
      }

      final Map<String, dynamic> data = bookingSnapshot.data()!;

      final List<dynamic> rawSlotIds = data['slotIds'] as List<dynamic>? ?? [];

      final List<String> slotIds = rawSlotIds
          .map((slotId) => slotId.toString())
          .toList();

      transaction.update(bookingReference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final String slotId in slotIds) {
        final DocumentReference<Map<String, dynamic>> slotReference = firestore
            .collection('booking_slots')
            .doc(slotId);

        transaction.delete(slotReference);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> bookingStream =
        FirebaseFirestore.instance.collection('bookings').snapshots();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quản lý lịch hẹn',
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
                    'Không thể tải danh sách '
                    'lịch hẹn.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings = [
              ...?snapshot.data?.docs,
            ];

            final activeBookings = _getActiveBookings(bookings);

            final cancelledBookings = _getBookingsByStatus(
              bookings,
              'cancelled',
            );

            final completedBookings = _getBookingsByStatus(
              bookings,
              'completed',
            );

            final int pendingCount = bookings.where((booking) {
              return booking.data()['status'] == 'pending';
            }).length;

            return Column(
              children: [
                Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF1E3A5F),
                    unselectedLabelColor: Colors.grey.shade700,
                    indicatorColor: const Color(0xFF1E3A5F),
                    tabs: [
                      Tab(
                        icon: Badge(
                          isLabelVisible: pendingCount > 0,
                          label: Text('$pendingCount'),
                          child: const Icon(Icons.pending_actions),
                        ),
                        text: 'Chờ xác nhận',
                      ),
                      const Tab(icon: Icon(Icons.event_busy), text: 'Đã hủy'),
                      const Tab(
                        icon: Icon(Icons.event_available),
                        text: 'Đã hoàn thành',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBookingList(
                        bookings: activeBookings,
                        emptyIcon: Icons.pending_actions,
                        emptyMessage:
                            'Không có lịch nào '
                            'đang chờ xử lý.',
                      ),
                      _buildBookingList(
                        bookings: cancelledBookings,
                        emptyIcon: Icons.event_busy,
                        emptyMessage:
                            'Chưa có lịch nào '
                            'bị hủy.',
                      ),
                      _buildBookingList(
                        bookings: completedBookings,
                        emptyIcon: Icons.event_available,
                        emptyMessage:
                            'Chưa có lịch nào '
                            'hoàn thành.',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    required IconData emptyIcon,
    required String emptyMessage,
  }) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
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

        return _buildBookingCard(bookingId: booking.id, data: booking.data());
      },
    );
  }

  Widget _buildBookingCard({
    required String bookingId,
    required Map<String, dynamic> data,
  }) {
    final String status = data['status'] as String? ?? 'pending';

    final String salonName = data['salonName'] as String? ?? 'Không rõ salon';

    final String barberName = data['barberName'] as String? ?? 'Chưa có thợ';

    final String userName = data['userName'] as String? ?? '';

    final String userEmail = data['userEmail'] as String? ?? '';

    final int totalPrice = (data['totalPrice'] as num?)?.toInt() ?? 0;

    final int totalDuration =
        (data['totalDurationMinutes'] as num?)?.toInt() ?? 0;

    final Timestamp? appointmentTimestamp = data['appointmentAt'] as Timestamp?;

    final DateTime? appointmentAt = appointmentTimestamp?.toDate();

    final List<dynamic> services = data['services'] as List<dynamic>? ?? [];

    final List<String> serviceNames = services
        .map((service) {
          if (service is Map) {
            return service['name']?.toString() ?? '';
          }

          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    final Map<String, dynamic> payment =
        Map<String, dynamic>.from(data['payment'] as Map? ?? const {});

    final bool isPaid = payment['status'] == 'paid';

    final String paymentLabel = payment['provider'] == 'vnpay'
        ? 'Đã thanh toán qua VNPAY Sandbox'
        : 'Đã thanh toán';

    final bool isUpdating = _updatingBookingIds.contains(bookingId);

    final bool canUpdate = status == 'pending' || status == 'confirmed';

    final Color statusColor = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.content_cut)),
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
                if (isUpdating)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (canUpdate)
                  PopupMenuButton<String>(
                    tooltip: 'Cập nhật trạng thái',
                    onSelected: (newStatus) {
                      _requestStatusChange(
                        bookingId: bookingId,
                        newStatus: newStatus,
                      );
                    },
                    itemBuilder: (context) {
                      return [
                        if (status == 'pending')
                          const PopupMenuItem<String>(
                            value: 'confirmed',
                            child: Text('Xác nhận lịch'),
                          ),
                        if (status == 'confirmed')
                          const PopupMenuItem<String>(
                            value: 'completed',
                            child: Text('Đánh dấu hoàn thành'),
                          ),
                        const PopupMenuItem<String>(
                          value: 'cancelled',
                          child: Text(
                            'Hủy lịch',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ];
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusText(status),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Khách hàng',
              value: userName.isEmpty ? userEmail : '$userName ($userEmail)',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'Thợ',
              value: barberName,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.schedule,
              label: 'Thời gian',
              value: appointmentAt == null
                  ? 'Chưa xác định'
                  : _formatDateTime(appointmentAt),
            ),
            const SizedBox(height: 12),
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
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paymentLabel,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
        Icon(icon, size: 20, color: const Color(0xFF1E3A5F)),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
