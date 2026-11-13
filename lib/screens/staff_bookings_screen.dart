import 'package:flutter/material.dart';
import '../models/staff_activity.dart';
import '../services/scheduling_service.dart';

typedef StaffStatusAction =
    Future<void> Function(Map<String, dynamic> booking, String status);

class StaffBookingList extends StatefulWidget {
  const StaffBookingList({
    super.key,
    required this.bookings,
    this.onChangeStatus,
    this.now,
    this.pendingAction,
  });
  final List<Map<String, dynamic>> bookings;
  final StaffStatusAction? onChangeStatus;
  final DateTime? now;
  final Map<String, dynamic>? pendingAction;
  @override
  State<StaffBookingList> createState() => _StaffBookingListState();
}

class _StaffBookingListState extends State<StaffBookingList> {
  String status = 'all', search = '';
  DateTime? date;
  DateTimeRange? dateRange;
  String? busy;
  Map<String, dynamic>? retryBooking;
  String? retryStatus;
  DateTime get now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final pending = widget.pendingAction;
    if (pending != null) {
      retryBooking =
          widget.bookings
              .where((row) => row['id'] == pending['bookingId'])
              .firstOrNull ??
          {'id': pending['bookingId']};
      retryStatus = pending['status'] as String;
    }
  }

  @override
  void didUpdateWidget(covariant StaffBookingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingAction != null && widget.pendingAction == null) {
      retryBooking = null;
      retryStatus = null;
    }
  }

  Future<void> _perform(
    Map<String, dynamic> row,
    String next, {
    bool retry = false,
  }) async {
    if (busy != null || widget.onChangeStatus == null) return;
    if (!retry) {
      final appointment = staffAppointment(row);
      final early =
          next == 'in_service' &&
          appointment != null &&
          appointment.isAfter(now);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            next == 'in_service'
                ? (early ? 'Bắt đầu phục vụ sớm?' : 'Bắt đầu phục vụ?')
                : 'Hoàn thành lịch hẹn?',
          ),
          content: Text(
            '${row['userName'] ?? 'Khách hàng'}\n'
            '${next == 'in_service' ? (early ? 'Giờ hẹn: ${staffTime(appointment)} (giờ Việt Nam).\nXác nhận khách đã đến và đồng ý được phục vụ sớm. Hệ thống sẽ kiểm tra ca làm và lịch khác trước khi bắt đầu.' : 'Xác nhận khách đã đến và bạn bắt đầu phục vụ.') : 'Xác nhận đã thực hiện xong các dịch vụ. ${row['payment'] is Map && row['payment']['status'] == 'paid' ? 'Lịch đã thanh toán, hệ thống không thu thêm.' : 'Khi hoàn thành, hệ thống tự ghi nhận đã thanh toán ${staffMoney(staffAmount(row))} và cập nhật thống kê. Chỉ xác nhận khi đã nhận đủ tiền của khách.'}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = '${row['id']}');
    try {
      await widget.onChangeStatus!(row, next);
      if (!mounted) return;
      setState(() {
        retryBooking = null;
        retryStatus = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật lịch hẹn.')));
    } catch (error) {
      if (!mounted) return;
      // The callback retains the request ID for uncertain transport failures.
      setState(() {
        retryBooking = error is SchedulingRejectedException ? null : row;
        retryStatus = error is SchedulingRejectedException ? null : next;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  void _details(Map<String, dynamic> row) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['userName'] ?? 'Khách hàng'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            SelectableText('Mã lịch: ${row['id'] ?? ''}'),
            SelectableText('Điện thoại: ${row['userPhone'] ?? 'Chưa có'}'),
            Text('Chi nhánh: ${row['salonName'] ?? row['salonId'] ?? ''}'),
            Text(
              staffAppointment(row) == null
                  ? 'Chưa có thời gian'
                  : '${staffTime(staffAppointment(row)!)} (giờ Việt Nam)',
            ),
            Text('Thời lượng: ${row['totalDurationMinutes'] ?? '—'} phút'),
            if (staffServiceStarted(row) case final DateTime actualStart)
              Text(
                'Bắt đầu thực tế: ${staffTime(actualStart)} (giờ Việt Nam)${row['startedEarly'] == true ? ' · Bắt đầu sớm' : ''}',
              ),
            Text(staffStatusLabels[staffStatus(row)] ?? 'Chưa rõ trạng thái'),
            const Divider(height: 28),
            if (row['services'] is List)
              for (final item in (row['services'] as List).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('${item['name'] ?? 'Dịch vụ'}')),
                      Text(
                        item['price'] is num
                            ? staffMoney((item['price'] as num).round())
                            : '—',
                      ),
                    ],
                  ),
                ),
            const Divider(height: 28),
            Text(
              'Tổng sau giảm giá: ${staffMoney(staffAmount(row))}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_payment(row)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String _payment(Map<String, dynamic> row) {
    final payment = row['payment'];
    if (payment is! Map) return 'Chưa có thông tin thanh toán';
    if (payment['status'] == 'paid') return 'Đã thanh toán';
    return payment['choice'] == 'pay_later'
        ? 'Thanh toán tại quầy • Chưa ghi nhận thu tiền'
        : 'Chưa thanh toán';
  }

  @override
  Widget build(BuildContext context) {
    final activeRange = dateRange != null
        ? StaffDateRange.custom(dateRange!.start, dateRange!.end)
        : date != null
        ? StaffDateRange(StaffPeriod.day, date!)
        : null;
    final rows =
        widget.bookings
            .where(
              (row) =>
                  (status == 'all' || staffStatus(row) == status) &&
                  (activeRange == null || activeRange.contains(row)) &&
                  '${row['id']} ${row['userName']} ${row['userPhone']}'
                      .toLowerCase()
                      .contains(search.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => (staffAppointment(a)?.millisecondsSinceEpoch ?? 0)
                .compareTo(staffAppointment(b)?.millisecondsSinceEpoch ?? 0),
          );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Tìm khách / điện thoại / mã lịch',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: status == 'all',
              onSelected: (_) => setState(() => status = 'all'),
            ),
            for (final entry in staffStatusLabels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: status == entry.key,
                onSelected: (_) => setState(() => status = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.today),
              label: const Text('Hôm nay'),
              onPressed: () => setState(() {
                date = vietnamDay(now);
                dateRange = null;
              }),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text('7 ngày'),
              onPressed: () => setState(() {
                final today = vietnamDay(now);
                date = null;
                dateRange = DateTimeRange(
                  start: today.subtract(const Duration(days: 6)),
                  end: today,
                );
              }),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text('30 ngày'),
              onPressed: () => setState(() {
                final today = vietnamDay(now);
                date = null;
                dateRange = DateTimeRange(
                  start: today.subtract(const Duration(days: 29)),
                  end: today,
                );
              }),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(date == null ? 'Chọn ngày' : staffDate(date!)),
              onPressed: () async {
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: date ?? vietnamDay(now),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (chosen != null && mounted) {
                  setState(() {
                    dateRange = null;
                    date = DateTime.utc(chosen.year, chosen.month, chosen.day);
                  });
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text('Chọn khoảng ngày'),
              onPressed: () async {
                final chosen = await showDateRangePicker(
                  context: context,
                  currentDate: vietnamDay(now),
                  initialDateRange:
                      dateRange ??
                      DateTimeRange(
                        start: date ?? vietnamDay(now),
                        end: date ?? vietnamDay(now),
                      ),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  helpText: 'Chọn từ ngày – đến ngày',
                  saveText: 'Áp dụng',
                  confirmText: 'Áp dụng',
                  cancelText: 'Hủy',
                  fieldStartLabelText: 'Từ ngày',
                  fieldEndLabelText: 'Đến ngày',
                );
                if (chosen == null || !mounted) return;
                setState(() {
                  date = null;
                  dateRange = chosen;
                });
              },
            ),
            if (activeRange != null)
              TextButton(
                onPressed: () => setState(() {
                  date = null;
                  dateRange = null;
                }),
                child: const Text('Bỏ lọc ngày'),
              ),
            IconButton(
              tooltip: 'Cập nhật giờ hiện tại',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (dateRange != null)
          Text(
            'Từ ${staffDate(activeRange!.start!)} đến ${staffDate(activeRange.lastDay!)}',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        if (retryBooking != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thao tác chưa được xác nhận. Thử lại để kiểm tra kết quả.',
                  ),
                  TextButton(
                    onPressed: busy != null
                        ? null
                        : () => _perform(
                            retryBooking!,
                            retryStatus!,
                            retry: true,
                          ),
                    child: const Text('Thử lại thao tác'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('${rows.length} lịch hẹn'),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.bookings.isEmpty
                  ? 'Bạn chưa có lịch hẹn được phân công.'
                  : 'Không có lịch hẹn phù hợp bộ lọc.',
            ),
          ),
        for (final row in rows) _card(context, row),
      ],
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> row) {
    final current = staffStatus(row), time = staffAppointment(row);
    final anotherInService = widget.bookings.any(
      (other) => other['id'] != row['id'] && staffStatus(other) == 'in_service',
    );
    final canStart =
        current == 'confirmed' &&
        time != null &&
        vietnamDay(time) == vietnamDay(now) &&
        !anotherInService;
    final canFinish = current == 'in_service';
    final items = row['services'];
    final names = items is List
        ? items.whereType<Map>().map((s) => '${s['name'] ?? ''}').join(', ')
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['userName'] ?? 'Khách hàng'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              time == null
                  ? 'Chưa có thời gian'
                  : '${staffTime(time)} (giờ Việt Nam)',
            ),
            Text('${row['salonName'] ?? row['salonId'] ?? ''}'),
            Text(names),
            if (staffServiceStarted(row) case final DateTime actualStart)
              Text(
                'Bắt đầu thực tế: ${staffTime(actualStart)}${row['startedEarly'] == true ? ' · Sớm hơn giờ hẹn' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    staffStatusLabels[current] ?? 'Chưa rõ trạng thái',
                  ),
                ),
                Text(
                  staffMoney(staffAmount(row)),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Text(
              _payment(row),
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _details(row),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Chi tiết'),
                ),
                if (widget.onChangeStatus != null &&
                    (current == 'confirmed' || canFinish))
                  FilledButton.icon(
                    onPressed:
                        busy != null ||
                            retryBooking != null ||
                            !(canStart || canFinish)
                        ? null
                        : () => _perform(
                            row,
                            canFinish ? 'completed' : 'in_service',
                          ),
                    icon: Icon(canFinish ? Icons.task_alt : Icons.play_arrow),
                    label: Text(
                      busy == row['id']
                          ? 'Đang cập nhật...'
                          : canFinish
                          ? 'Hoàn thành'
                          : 'Bắt đầu phục vụ',
                    ),
                  ),
              ],
            ),
            if (widget.onChangeStatus != null &&
                current == 'confirmed' &&
                !canStart)
              Text(
                anotherInService
                    ? 'Hãy hoàn thành lịch đang phục vụ trước khi bắt đầu khách tiếp theo.'
                    : 'Chỉ bắt đầu phục vụ lịch hẹn trong ngày hôm nay.',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            if (canStart && time.isAfter(now))
              const Text(
                'Có thể bắt đầu sớm khi khách đã đến, thợ đang rảnh và không trùng lịch khác.',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
          ],
        ),
      ),
    );
  }
}
