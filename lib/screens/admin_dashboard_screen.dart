import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../models/dashboard_stats.dart';

enum _DashboardPeriod { sevenDays, thirtyDays, all }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _ink = Color(0xFF08111E);
  static const _panel = Color(0xFF111B29);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);
  _DashboardPeriod _period = _DashboardPeriod.thirtyDays;

  DateTime? get _startDate => switch (_period) {
    _DashboardPeriod.sevenDays => DateTime.now().subtract(const Duration(days: 7)),
    _DashboardPeriod.thirtyDays => DateTime.now().subtract(const Duration(days: 30)),
    _DashboardPeriod.all => null,
  };

  String _money(int value) {
    final raw = value.toString();
    final output = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) output.write('.');
      output.write(raw[i]);
    }
    return '${output}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text('Tổng quan quản trị'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Không thể tải thống kê: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          final start = _startDate;
          final bookings = snapshot.data!.docs.where((doc) {
            if (start == null) return true;
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && !createdAt.isBefore(start);
          }).map((doc) => doc.data()).toList();
          final stats = DashboardStats.fromBookings(bookings);
          return _content(bookings, stats);
        },
      ),
    );
  }

  Widget _content(List<Map<String, dynamic>> bookings, DashboardStats stats) {
    final bySalon = {
      for (final salon in sampleSalons)
        salon.id: bookings.where((item) => item['salonId'] == salon.id).length,
    };
    final maximum = bySalon.values.fold<int>(1, (a, b) => a > b ? a : b);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard vận hành',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Số liệu cập nhật trực tiếp từ Firestore',
                        style: TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
                DropdownButton<_DashboardPeriod>(
                  value: _period,
                  dropdownColor: _panel,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: _DashboardPeriod.sevenDays,
                      child: Text('7 ngày'),
                    ),
                    DropdownMenuItem(
                      value: _DashboardPeriod.thirtyDays,
                      child: Text('30 ngày'),
                    ),
                    DropdownMenuItem(
                      value: _DashboardPeriod.all,
                      child: Text('Toàn bộ'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _period = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 36) / 4
                    : constraints.maxWidth >= 540
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _metric('Tổng lịch', '${stats.total}', Icons.event_note_rounded),
                    ),
                    SizedBox(
                      width: width,
                      child: _metric('Chờ thanh toán', '${stats.pending}', Icons.schedule_rounded),
                    ),
                    SizedBox(
                      width: width,
                      child: _metric('Đã hoàn thành', '${stats.completed}', Icons.task_alt_rounded),
                    ),
                    SizedBox(
                      width: width,
                      child: _metric('Doanh thu', _money(stats.revenue), Icons.payments_rounded),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _branchPanel(bySalon, maximum)),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: _qualityPanel(stats)),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _branchPanel(bySalon, maximum),
                    const SizedBox(height: 14),
                    _qualityPanel(stats),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0x22F6C768),
            child: Icon(icon, color: _gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _muted)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchPanel(Map<String, int> bySalon, int maximum) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch hẹn theo chi nhánh',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          for (final salon in sampleSalons) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    salon.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Text('${bySalon[salon.id]} lịch', style: const TextStyle(color: _gold)),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: (bySalon[salon.id] ?? 0) / maximum,
              minHeight: 9,
              borderRadius: BorderRadius.circular(9),
              color: _gold,
              backgroundColor: const Color(0xFF243247),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _qualityPanel(DashboardStats stats) {
    final cancellation = (stats.cancellationRate * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chất lượng vận hành',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _qualityRow('Đã xác nhận', stats.confirmed, Icons.verified_rounded),
          _qualityRow('Đã thanh toán', stats.paid, Icons.account_balance_wallet_rounded),
          _qualityRow('Đã hủy', stats.cancelled, Icons.event_busy_rounded),
          const Divider(color: Color(0x334D6380)),
          Text('Tỷ lệ hủy: $cancellation%', style: const TextStyle(color: _gold, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _qualityRow(String label, int value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(label, style: const TextStyle(color: _muted))),
          Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  BoxDecoration _decoration() => BoxDecoration(
    color: _panel,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0x33F6C768)),
  );
}
