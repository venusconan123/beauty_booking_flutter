import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Salon salon;
  final List<HairService> selectedServices;
  final Barber? selectedBarber;
  final bool useAnyBarber;
  final DateTime selectedDate;
  final String selectedTime;

  const BookingConfirmationScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
    required this.selectedBarber,
    required this.useAnyBarber,
    required this.selectedDate,
    required this.selectedTime,
  });

  @override
  State<BookingConfirmationScreen> createState() {
    return _BookingConfirmationScreenState();
  }
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
  bool _isSaving = false;

  int get _totalPrice {
    return widget.selectedServices.fold(
      0,
      (total, service) => total + service.price,
    );
  }

  int get _totalDuration {
    return widget.selectedServices.fold(
      0,
      (total, service) => total + service.durationMinutes,
    );
  }

  String _formatPrice(int price) {
    return '${price ~/ 1000}.000đ';
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  DateTime _createAppointmentDateTime() {
    final List<String> timeParts =
        widget.selectedTime.split(':');

    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      hour,
      minute,
    );
  }

  Future<void> _saveBooking() async {
    if (_isSaving) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn cần đăng nhập trước khi đặt lịch.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DateTime appointmentDateTime =
          _createAppointmentDateTime();

      final String barberName = widget.useAnyBarber
          ? 'Thợ bất kỳ'
          : widget.selectedBarber?.name ?? 'Chưa chọn thợ';

      await FirebaseFirestore.instance
          .collection('bookings')
          .add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? '',
        'salonId': widget.salon.id,
        'salonName': widget.salon.name,
        'salonAddress': widget.salon.address,
        'barberId': widget.useAnyBarber
            ? null
            : widget.selectedBarber?.id,
        'barberName': barberName,
        'useAnyBarber': widget.useAnyBarber,
        'serviceIds': widget.selectedServices
            .map((service) => service.id)
            .toList(),
        'services': widget.selectedServices.map(
          (service) {
            return {
              'id': service.id,
              'name': service.name,
              'price': service.price,
              'durationMinutes': service.durationMinutes,
            };
          },
        ).toList(),
        'appointmentAt': Timestamp.fromDate(
          appointmentDateTime,
        ),
        'selectedTime': widget.selectedTime,
        'totalPrice': _totalPrice,
        'totalDurationMinutes': _totalDuration,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      await _showSuccessDialog();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Không thể lưu lịch hẹn.';

      switch (error.code) {
        case 'permission-denied':
          message =
              'Bạn không có quyền lưu lịch hẹn. Hãy kiểm tra Firestore Rules.';
          break;
        case 'unavailable':
          message =
              'Firestore đang tạm thời không khả dụng. Vui lòng thử lại.';
          break;
        case 'network-request-failed':
          message = 'Không có kết nối mạng.';
          break;
        default:
          message = error.message ?? message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xảy ra lỗi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 58,
          ),
          title: const Text('Đặt lịch thành công'),
          content: const Text(
            'Lịch hẹn đã được lưu vào hệ thống và đang chờ xác nhận.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Đồng ý'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String barberName = widget.useAnyBarber
        ? 'Thợ bất kỳ'
        : widget.selectedBarber?.name ?? 'Chưa chọn thợ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đặt lịch'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.event_available,
            size: 70,
            color: Color(0xFF1E3A5F),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kiểm tra thông tin lịch hẹn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInformationRow(
                    icon: Icons.store,
                    title: 'Chi nhánh',
                    value: widget.salon.name,
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.location_on_outlined,
                    title: 'Địa chỉ',
                    value: widget.salon.address,
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.person_outline,
                    title: 'Thợ',
                    value: barberName,
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.calendar_month,
                    title: 'Ngày hẹn',
                    value: _formatDate(widget.selectedDate),
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.schedule,
                    title: 'Giờ hẹn',
                    value: widget.selectedTime,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Dịch vụ đã chọn',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...widget.selectedServices.map(
                    (service) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.name,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${service.durationMinutes} phút',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatPrice(service.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Tổng thời gian'),
                      const Spacer(),
                      Text(
                        '$_totalDuration phút',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Tổng thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatPrice(_totalPrice),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveBooking,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isSaving
                    ? 'Đang lưu lịch hẹn...'
                    : 'Xác nhận đặt lịch',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformationRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF1E3A5F),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}