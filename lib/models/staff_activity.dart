import 'package:cloud_firestore/cloud_firestore.dart';

const staffStatusLabels = {
  'pending': 'Chờ thanh toán',
  'confirmed': 'Đã xác nhận',
  'in_service': 'Đang phục vụ',
  'completed': 'Đã hoàn thành',
  'cancelled': 'Đã hủy',
};

enum StaffPeriod { day, week, month, year, all }

const staffPeriodLabels = {
  StaffPeriod.day: 'Ngày',
  StaffPeriod.week: 'Tuần',
  StaffPeriod.month: 'Tháng',
  StaffPeriod.year: 'Năm',
  StaffPeriod.all: 'Tất cả',
};

DateTime vietnamDay(DateTime instant) {
  final vn = instant.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(vn.year, vn.month, vn.day);
}

DateTime? staffAppointment(Map<String, dynamic> row) =>
    (row['appointmentAt'] as Timestamp?)?.toDate();
String staffStatus(Map<String, dynamic> row) {
  final status = row['status']?.toString() ?? 'pending';
  final payment = row['payment'];
  return status == 'pending' &&
          payment is Map &&
          (payment['choice'] == 'pay_later' || payment['status'] == 'paid')
      ? 'confirmed'
      : status;
}

int staffAmount(Map<String, dynamic> row) {
  final value = row['totalPrice'];
  return value is num && value.isFinite && value >= 0 ? value.round() : 0;
}

String staffMoney(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
String staffDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
String staffTime(DateTime instant) {
  final vn = instant.toUtc().add(const Duration(hours: 7));
  return '${staffDate(vn)} ${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')}';
}

class StaffDateRange {
  StaffDateRange(this.period, DateTime anchor)
    : anchor = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final StaffPeriod period;
  final DateTime anchor;
  DateTime? get start => switch (period) {
    StaffPeriod.day => anchor,
    StaffPeriod.week => anchor.subtract(Duration(days: anchor.weekday - 1)),
    StaffPeriod.month => DateTime.utc(anchor.year, anchor.month),
    StaffPeriod.year => DateTime.utc(anchor.year),
    StaffPeriod.all => null,
  };
  DateTime? get end => switch (period) {
    StaffPeriod.day => anchor.add(const Duration(days: 1)),
    StaffPeriod.week => start!.add(const Duration(days: 7)),
    StaffPeriod.month => DateTime.utc(anchor.year, anchor.month + 1),
    StaffPeriod.year => DateTime.utc(anchor.year + 1),
    StaffPeriod.all => null,
  };
  bool contains(Map<String, dynamic> row) {
    if (period == StaffPeriod.all) return true;
    final instant = staffAppointment(row);
    if (instant == null) return false;
    final day = vietnamDay(instant);
    return !day.isBefore(start!) && day.isBefore(end!);
  }

  String get label => period == StaffPeriod.all
      ? 'Toàn bộ lịch được giao'
      : '${staffDate(start!)} – ${staffDate(end!.subtract(const Duration(days: 1)))}';
}

class StaffActivityStats {
  StaffActivityStats(Iterable<Map<String, dynamic>> bookings) {
    for (final row in bookings) {
      total++;
      final status = staffStatus(row);
      counts.update(status, (n) => n + 1, ifAbsent: () => 1);
      if (status != 'completed') continue;
      completedValue += staffAmount(row);
      final payment = row['payment'];
      if (payment is Map && payment['status'] == 'paid') {
        paidValue += staffAmount(row);
      }
      final customer = row['userId']?.toString();
      if (customer != null && customer.isNotEmpty) customers.add(customer);
      final items = row['services'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          final name = item['name']?.toString() ?? 'Dịch vụ';
          services.update(name, (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
  }
  int total = 0, completedValue = 0, paidValue = 0;
  final counts = <String, int>{};
  final services = <String, int>{};
  final customers = <String>{};
  int count(String status) => counts[status] ?? 0;
  double get completionRate => total == 0 ? 0 : count('completed') / total;
}
