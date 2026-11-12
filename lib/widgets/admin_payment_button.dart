import 'package:flutter/material.dart';
import '../models/staff_activity.dart';
import '../services/scheduling_service.dart';

class AdminPaymentButton extends StatefulWidget {
  const AdminPaymentButton({
    super.key,
    required this.bookingId,
    required this.amount,
    this.onRecord,
  });
  final String bookingId;
  final int amount;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? onRecord;
  @override
  State<AdminPaymentButton> createState() => _AdminPaymentButtonState();
}

class _AdminPaymentButtonState extends State<AdminPaymentButton> {
  bool busy = false;
  SchedulingMutation? pending;
  Future<void> _record() async {
    if (busy) return;
    if (pending == null) {
      var method = 'cash';
      final chosen = await showDialog<String>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
            title: const Text('Ghi nhận thanh toán'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã lịch: ${widget.bookingId}'),
                  const SizedBox(height: 12),
                  Text(
                    'Số tiền: ${staffMoney(widget.amount)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hình thức đã nhận',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Chuyển khoản'),
                      ),
                    ],
                    onChanged: (v) => update(() => method = v!),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chỉ xác nhận sau khi đã nhận đủ tiền hoặc kiểm tra tiền vào tài khoản. '
                    'Thao tác này ghi nhận khoản đã thu, không thực hiện chuyển tiền.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, method),
                child: const Text('Xác nhận đã nhận tiền'),
              ),
            ],
          ),
        ),
      );
      if (chosen == null || !mounted) return;
      pending = SchedulingMutation('recordBookingPayment', {
        'bookingId': widget.bookingId,
        'expectedAmount': widget.amount,
        'method': chosen,
      });
    }
    setState(() => busy = true);
    try {
      final result =
          await (widget.onRecord?.call(pending!.data) ??
              SchedulingService().call(pending!.name, pending!.data));
      pending = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['alreadyPaid'] == true
                ? 'Lịch đã thanh toán trước đó; không ghi nhận thêm.'
                : 'Đã ghi nhận thanh toán. Thống kê đang cập nhật.',
          ),
        ),
      );
    } catch (error) {
      if (error is SchedulingRejectedException) pending = null;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy || widget.amount <= 0 ? null : _record,
    icon: Icon(
      pending != null && !busy ? Icons.refresh : Icons.payments_outlined,
    ),
    label: Text(
      busy
          ? 'Đang ghi nhận...'
          : pending != null
          ? 'Thử lại ghi nhận'
          : 'Ghi nhận thanh toán',
    ),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xffd9ad60),
      foregroundColor: const Color(0xff0b1623),
    ),
  );
}
