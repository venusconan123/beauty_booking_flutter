import 'package:flutter/material.dart';
import '../models/staff_activity.dart';

class StaffStatisticsScreen extends StatefulWidget {
  const StaffStatisticsScreen({super.key, required this.bookings, this.now});
  final List<Map<String, dynamic>> bookings;
  final DateTime? now;
  @override
  State<StaffStatisticsScreen> createState() => _StaffStatisticsScreenState();
}

class _StaffStatisticsScreenState extends State<StaffStatisticsScreen> {
  StaffPeriod period = StaffPeriod.month;
  late DateTime anchor = vietnamDay(widget.now ?? DateTime.now());
  DateTimeRange? customRange;

  Future<void> _chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      currentDate: vietnamDay(widget.now ?? DateTime.now()),
      initialDateRange:
          customRange ?? DateTimeRange(start: anchor, end: anchor),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn từ ngày – đến ngày',
      saveText: 'Áp dụng',
      confirmText: 'Áp dụng',
      cancelText: 'Hủy',
      fieldStartLabelText: 'Từ ngày',
      fieldEndLabelText: 'Đến ngày',
    );
    if (selected == null || !mounted) return;
    setState(() {
      customRange = selected;
      period = StaffPeriod.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = period == StaffPeriod.custom
        ? StaffDateRange.custom(customRange!.start, customRange!.end)
        : StaffDateRange(
            period,
            period == StaffPeriod.today
                ? vietnamDay(widget.now ?? DateTime.now())
                : anchor,
          );
    final stats = StaffActivityStats(widget.bookings.where(range.contains));
    final services = stats.services.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Thống kê cá nhân',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tính theo ngày hẹn (giờ Việt Nam), chỉ gồm lịch được giao cho bạn.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in StaffPeriod.values)
              ChoiceChip(
                label: Text(staffPeriodLabels[p]!),
                selected: period == p,
                onSelected: (_) {
                  if (p == StaffPeriod.custom) {
                    _chooseRange();
                  } else {
                    setState(() => period = p);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Còn chưa thu trong lịch hoàn thành: ${staffMoney(stats.completedValue - stats.paidValue)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (period == StaffPeriod.custom)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _chooseRange,
              icon: const Icon(Icons.date_range),
              label: Text(
                'Từ ${staffDate(range.start!)} đến ${staffDate(range.lastDay!)}',
              ),
            ),
          ),
        if (period != StaffPeriod.all &&
            period != StaffPeriod.today &&
            period != StaffPeriod.custom)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text('Chọn ngày: ${staffDate(anchor)}'),
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: anchor,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null && mounted) {
                  setState(
                    () => anchor = DateTime.utc(
                      selected.year,
                      selected.month,
                      selected.day,
                    ),
                  );
                }
              },
            ),
          ),
        Text(range.label, style: const TextStyle(color: Colors.blueGrey)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth >= 600
                ? (c.maxWidth - 12) / 2
                : c.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [
                  ('Tổng lịch hẹn', '${stats.total}', Icons.event_note),
                  (
                    'Đã hoàn thành',
                    '${stats.count('completed')}',
                    Icons.task_alt,
                  ),
                  (
                    'Giá trị dịch vụ hoàn thành',
                    staffMoney(stats.completedValue),
                    Icons.content_cut,
                  ),
                  (
                    'Đã thanh toán trong lịch hoàn thành',
                    staffMoney(stats.paidValue),
                    Icons.payments_outlined,
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$3, color: const Color(0xff98702f)),
                            const SizedBox(height: 12),
                            Text(item.$1),
                            const SizedBox(height: 8),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Giá trị dịch vụ không phải tiền lương hoặc hoa hồng. '
          'Lịch thanh toán tại quầy được tự ghi nhận đã thanh toán khi xác nhận hoàn thành.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        if (stats.total == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Chưa có lịch hẹn trong khoảng thời gian này.'),
          ),
        const SizedBox(height: 20),
        Text(
          'Trạng thái lịch hẹn',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final status in staffStatusLabels.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(status.value),
            trailing: Text('${stats.count(status.key)}'),
          ),
        Text(
          'Tỷ lệ hoàn thành: ${(stats.completionRate * 100).toStringAsFixed(1)}%',
        ),
        const SizedBox(height: 20),
        Text(
          'Dịch vụ đã thực hiện',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Số lượt dịch vụ trong các lịch đã hoàn thành.'),
        if (services.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Chưa có dịch vụ hoàn thành.'),
          ),
        for (final service in services)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(service.key),
            trailing: Text('${service.value} lượt'),
          ),
      ],
    );
  }
}
