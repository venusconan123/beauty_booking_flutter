import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import '../models/voucher.dart';
import '../services/booking_service.dart';
import '../services/vnpay_payment_service.dart';
import '../services/voucher_service.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Salon salon;
  final List<HairService> selectedServices;
  final Hairstyle? selectedHairstyle;
  final Barber? selectedBarber;
  final bool useAnyBarber;
  final DateTime selectedDate;
  final String selectedTime;

  const BookingConfirmationScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
    this.selectedHairstyle,
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

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isSaving = false;
  bool _isLoadingVouchers = true;
  List<Voucher> _availableVouchers = const [];
  Voucher? _selectedVoucher;

  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  int get _totalPrice {
    return widget.selectedServices.fold(
      0,
      (total, service) => total + service.price,
    );
  }

  int get _totalDuration {
    return widget.selectedServices.fold(0, (total, service) {
      return total + service.durationMinutes;
    });
  }

  int get _discountAmount =>
      _selectedVoucher?.discountFor(_totalPrice) ?? 0;

  int get _finalPrice => _totalPrice - _discountAmount;

  Future<void> _loadVouchers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingVouchers = false);
      return;
    }
    try {
      final vouchers = await VoucherService().getAvailableVouchers(
        userId: user.uid,
        orderAmount: _totalPrice,
      );
      if (mounted) {
        setState(() {
          _availableVouchers = vouchers;
          _isLoadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVouchers = false);
    }
  }

  Future<void> _chooseVoucher() async {
    final selected = await showModalBottomSheet<Voucher>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn voucher',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (_availableVouchers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('Chưa có voucher phù hợp với đơn này.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availableVouchers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final voucher = _availableVouchers[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0x33F6C768)),
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.confirmation_number_rounded),
                        ),
                        title: Text(
                          '${voucher.code} · Giảm ${voucher.discountPercent}%',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          voucher.minOrderAmount == 0
                              ? voucher.title
                              : '${voucher.title}\nĐơn tối thiểu ${_formatPrice(voucher.minOrderAmount)}',
                        ),
                        isThreeLine: voucher.minOrderAmount > 0,
                        onTap: () => Navigator.pop(sheetContext, voucher),
                      );
                    },
                  ),
                ),
              if (_selectedVoucher != null)
                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Không dùng voucher'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedVoucher = selected);
  }

  String _formatPrice(int price) {
    final value = price.toString();
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) result.write('.');
      result.write(value[index]);
    }
    return '${result}đ';
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  DateTime _createAppointmentDateTime() {
    final List<String> timeParts = widget.selectedTime.split(':');

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

  Future<void> _saveBooking({required bool payNow}) async {
    if (_isSaving) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đăng nhập trước khi đặt lịch.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final DateTime appointmentDateTime = _createAppointmentDateTime();

      final String bookingId = await _bookingService.createBooking(
        user: user,
        salon: widget.salon,
        selectedServices: widget.selectedServices,
        selectedHairstyle: widget.selectedHairstyle,
        selectedBarber: widget.selectedBarber,
        useAnyBarber: widget.useAnyBarber,
        appointmentAt: appointmentDateTime,
        selectedTime: widget.selectedTime,
        paymentChoice: payNow ? 'pay_now' : 'pay_later',
        selectedVoucher: _selectedVoucher,
      );

      if (!mounted) {
        return;
      }

      if (payNow) {
        try {
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
            throw const VnpayPaymentException('Không thể mở trang VNPAY.');
          }
        } catch (error) {
          if (!mounted) {
            return;
          }
          final String paymentError = error is VnpayPaymentException
              ? error.message
              : 'Không thể kết nối VNPAY.';
          await _showSuccessDialog(
            message:
                'Lịch đã được lưu, nhưng chưa mở được VNPAY. '
                '$paymentError Bạn có thể thử lại trong Lịch hẹn của tôi.',
          );
        }
      } else {
        await _showSuccessDialog(
          message:
              'Lịch đã được lưu và đang chờ xác nhận. '
              'Bạn đã chọn thanh toán sau tại salon.',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on BookingConflictException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.orange),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Không thể lưu lịch hẹn.';

      switch (error.code) {
        case 'permission-denied':
          message =
              'Bạn không có quyền lưu lịch hẹn. '
              'Hãy kiểm tra Firestore Rules.';
          break;

        case 'unavailable':
          message =
              'Firestore đang tạm thời không khả dụng. '
              'Vui lòng thử lại.';
          break;

        case 'network-request-failed':
          message = 'Không có kết nối mạng.';
          break;

        default:
          message = error.message ?? message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  Future<void> _showSuccessDialog({String? message}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 58),
          title: const Text('Đặt lịch thành công'),
          content: Text(
            message ??
                'Lịch hẹn đã được lưu vào hệ thống '
                    'và đang chờ xác nhận.',
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
      appBar: AppBar(title: const Text('Xác nhận đặt lịch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.event_available, size: 70, color: Color(0xFF1E3A5F)),
          const SizedBox(height: 12),
          const Text(
            'Kiểm tra thông tin lịch hẹn',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (widget.selectedHairstyle != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Mẫu tóc đã chọn',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 116,
                    height: 104,
                    child: widget.selectedHairstyle!.imageUrl.isNotEmpty
                        ? Image.network(
                            widget.selectedHairstyle!.imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            widget.selectedHairstyle!.assetPath,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.selectedHairstyle!.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(widget.selectedHairstyle!.description),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          _buildVoucherCard(),
          const SizedBox(height: 24),
          const Text(
            'Dịch vụ đã chọn',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...widget.selectedServices.map((service) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${service.durationMinutes} phút',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatPrice(service.price),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  if (_selectedVoucher != null) ...[
                    Row(
                      children: [
                        Text('Tạm tính (${_selectedVoucher!.code})'),
                        const Spacer(),
                        Text(_formatPrice(_totalPrice)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Voucher giảm',
                          style: TextStyle(color: Colors.green),
                        ),
                        const Spacer(),
                        Text(
                          '-${_formatPrice(_discountAmount)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                  ],
                  Row(
                    children: [
                      const Text('Tổng thời gian'),
                      const Spacer(),
                      Text(
                        '$_totalDuration phút',
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                        _formatPrice(_finalPrice),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _saveBooking(payNow: false),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text(
                    'Đặt lịch – Thanh toán sau',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _saveBooking(payNow: true),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_wallet),
                  label: Text(
                    _isSaving
                        ? 'Đang lưu lịch hẹn...'
                        : 'Đặt lịch – Thanh toán ngay bằng VNPAY',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'VNPAY Sandbox là môi trường thử nghiệm, không trừ tiền thật.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
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
        Icon(icon, color: const Color(0xFF1E3A5F)),
        const SizedBox(width: 14),
        SizedBox(
          width: 90,
          child: Text(title, style: TextStyle(color: Colors.grey.shade700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherCard() {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0x1F2E7D32),
          child: Icon(Icons.confirmation_number_rounded, color: Colors.green),
        ),
        title: Text(
          _selectedVoucher?.title ?? 'Voucher ưu đãi',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          _isLoadingVouchers
              ? 'Đang kiểm tra voucher của bạn...'
              : _selectedVoucher == null
              ? _availableVouchers.isEmpty
                    ? 'Bạn chưa có voucher phù hợp.'
                    : 'Có ${_availableVouchers.length} voucher có thể sử dụng.'
              : '${_selectedVoucher!.code} · Giảm ${_selectedVoucher!.discountPercent}%',
        ),
        trailing: _isLoadingVouchers
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _chooseVoucher,
                child: Text(_selectedVoucher == null ? 'Chọn' : 'Đổi'),
              ),
        onTap: _isLoadingVouchers ? null : _chooseVoucher,
      ),
    );
  }
}
