import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isLoadingPhone = true;
  bool _isApplyingPromotionCode = false;
  List<Voucher> _availableLoyaltyVouchers = const [];
  final List<Voucher> _selectedLoyaltyVouchers = [];
  Voucher? _selectedPromotionVoucher;
  final TextEditingController _promotionCodeController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _loadVouchers();
    _loadPhone();
  }

  @override
  void dispose() {
    _promotionCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^0[0-9]{9}$').hasMatch(_normalizePhone(value));
  }

  Future<void> _loadPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingPhone = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final phone = snapshot.data()?['phone']?.toString() ?? '';
      if (mounted) {
        setState(() {
          if (_phoneController.text.trim().isEmpty) {
            _phoneController.text = phone;
          }
          _isLoadingPhone = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPhone = false);
    }
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

  List<Voucher> get _selectedVouchers => _selectedPromotionVoucher != null
      ? [_selectedPromotionVoucher!]
      : List.unmodifiable(_selectedLoyaltyVouchers);

  int get _discountAmount {
    final discount = _selectedVouchers.fold<int>(
      0,
      (total, voucher) => total + voucher.discountFor(_totalPrice),
    );
    return discount > _totalPrice ? _totalPrice : discount;
  }

  int get _finalPrice => _totalPrice - _discountAmount;

  Future<void> _loadVouchers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingVouchers = false);
      return;
    }
    try {
      final vouchers = await VoucherService().getAvailableLoyaltyVouchers(
        userId: user.uid,
        orderAmount: _totalPrice,
      );
      if (mounted) {
        setState(() {
          _availableLoyaltyVouchers = vouchers;
          _isLoadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVouchers = false);
    }
  }

  Future<void> _chooseVoucher() async {
    final temporarySelection = List<Voucher>.from(_selectedLoyaltyVouchers);
    final visitVouchers = _availableLoyaltyVouchers
        .where((voucher) => voucher.rewardType == 'visit_count')
        .toList();
    final orderVouchers = _availableLoyaltyVouchers
        .where((voucher) => voucher.rewardType == 'minimum_order')
        .toList();
    final selected = await showModalBottomSheet<List<Voucher>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget buildVoucherGroup({
            required String title,
            required String description,
            required String rewardType,
            required List<Voucher> vouchers,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description),
                const SizedBox(height: 9),
                if (vouchers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Chưa có voucher thuộc nhóm này.'),
                  )
                else
                  ...vouchers.map((voucher) {
                    final isSelected = temporarySelection.any(
                      (item) => item.id == voucher.id,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: CheckboxListTile(
                        value: isSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0x33F6C768)),
                        ),
                        secondary: const CircleAvatar(
                          child: Icon(Icons.confirmation_number_rounded),
                        ),
                        title: Text(
                          '${voucher.code} · Giảm ${voucher.discountPercent}%',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(voucher.title),
                        onChanged: (_) {
                          setSheetState(() {
                            if (isSelected) {
                              temporarySelection.removeWhere(
                                (item) => item.id == voucher.id,
                              );
                            } else {
                              temporarySelection.removeWhere(
                                (item) => item.rewardType == rewardType,
                              );
                              temporarySelection.add(voucher);
                            }
                          });
                        },
                      ),
                    );
                  }),
              ],
            );
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.82,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn tối đa 2 voucher',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mỗi nhóm chọn 1 voucher. Hai voucher sẽ được cộng mức giảm trong cùng lịch hẹn.',
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            buildVoucherGroup(
                              title: 'Theo số lần hoàn thành dịch vụ',
                              description:
                                  'Chọn 1 mã TRI_AN từ số lần đã tích lũy.',
                              rewardType: 'visit_count',
                              vouchers: visitVouchers,
                            ),
                            const Divider(height: 28),
                            buildVoucherGroup(
                              title: 'Theo giá trị đơn hàng',
                              description:
                                  'Chọn voucher CHITIEU đã nhận từ đơn đủ điều kiện.',
                              rewardType: 'minimum_order',
                              vouchers: orderVouchers,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          List<Voucher>.from(temporarySelection),
                        ),
                        child: Text(
                          temporarySelection.isEmpty
                              ? 'Không dùng voucher tích lũy'
                              : 'Áp dụng ${temporarySelection.length}/2 voucher',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _selectedPromotionVoucher = null;
        _selectedLoyaltyVouchers
          ..clear()
          ..addAll(selected);
        _promotionCodeController.clear();
      });
    }
  }

  Future<void> _applyPromotionCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isApplyingPromotionCode) return;
    FocusScope.of(context).unfocus();
    setState(() => _isApplyingPromotionCode = true);
    try {
      final voucher = await VoucherService().validatePromotionCode(
        userId: user.uid,
        code: _promotionCodeController.text,
        orderAmount: _totalPrice,
      );
      if (!mounted) return;
      _promotionCodeController.text = voucher.code;
      setState(() {
        _selectedPromotionVoucher = voucher;
        _selectedLoyaltyVouchers.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã áp dụng mã ${voucher.code}.'),
          backgroundColor: Colors.green,
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.orange),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Không thể kiểm tra mã khuyến mãi.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplyingPromotionCode = false);
    }
  }

  void _clearVoucher(Voucher voucher) {
    setState(() {
      if (voucher.isPersonal) {
        _selectedLoyaltyVouchers.removeWhere((item) => item.id == voucher.id);
      } else {
        _selectedPromotionVoucher = null;
        _promotionCodeController.clear();
      }
    });
  }

  String _formatPrice(int price) {
    final value = price.toString();
    final result = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && (value.length - index) % 3 == 0) result.write('.');
      result.write(value[index]);
    }
    return '$resultđ';
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

    final phone = _normalizePhone(_phoneController.text);
    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập số điện thoại gồm 10 số và bắt đầu bằng 0.',
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final DateTime appointmentDateTime = _createAppointmentDateTime();

      final String bookingId = await _bookingService.createBooking(
        user: user,
        userPhone: phone,
        salon: widget.salon,
        selectedServices: widget.selectedServices,
        selectedHairstyle: widget.selectedHairstyle,
        selectedBarber: widget.selectedBarber,
        useAnyBarber: widget.useAnyBarber,
        appointmentAt: appointmentDateTime,
        selectedTime: widget.selectedTime,
        paymentChoice: payNow ? 'pay_now' : 'pay_later',
        selectedVouchers: _selectedVouchers,
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
              'Lịch hẹn đã được xác nhận tự động. '
              'Bạn sẽ thanh toán tại salon sau khi sử dụng dịch vụ.',
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
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.orange,
        ),
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
                    'và được xác nhận tự động.',
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone_in_talk_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Số điện thoại liên hệ',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !_isSaving && !_isLoadingPhone,
                    maxLength: 15,
                    decoration: InputDecoration(
                      hintText: _isLoadingPhone
                          ? 'Đang tải số điện thoại...'
                          : 'Ví dụ: 0905123456',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chi nhánh chỉ sử dụng số này để liên hệ với bạn khi cần.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
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
                  if (_selectedVouchers.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tạm tính (${_selectedVouchers.map((voucher) => voucher.code).join(' + ')})',
                          ),
                        ),
                        const SizedBox(width: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0x1F2E7D32),
                  child: Icon(Icons.local_offer_rounded, color: Colors.green),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mã khuyến mãi',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập mã được thông báo từ salon. Mã không tự thêm vào tài khoản.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promotionCodeController,
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_isApplyingPromotionCode,
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã khuyến mãi',
                      prefixIcon: Icon(Icons.sell_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _applyPromotionCode(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _isApplyingPromotionCode
                      ? null
                      : _applyPromotionCode,
                  child: _isApplyingPromotionCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Áp dụng'),
                ),
              ],
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0x1FF6C768),
                child: Icon(Icons.workspace_premium_rounded),
              ),
              title: const Text(
                'Voucher tích lũy của tôi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _isLoadingVouchers
                    ? 'Đang kiểm tra voucher tích lũy...'
                    : _availableLoyaltyVouchers.isEmpty
                    ? 'Chưa có voucher tích lũy phù hợp.'
                    : 'Có ${_availableLoyaltyVouchers.length} voucher có thể chọn.',
              ),
              trailing: _isLoadingVouchers
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _chooseVoucher,
                      child: const Text('Chọn'),
                    ),
              onTap: _isLoadingVouchers ? null : _chooseVoucher,
            ),
            ..._selectedVouchers.map((voucher) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x142E7D32),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x552E7D32)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${voucher.isPersonal ? 'Voucher tích lũy' : 'Mã khuyến mãi'} '
                          '${voucher.code} · Giảm ${voucher.discountPercent}%',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Bỏ voucher',
                        onPressed: () => _clearVoucher(voucher),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
