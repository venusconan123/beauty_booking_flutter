import 'package:beauty_booking_app/models/dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardStats', () {
    test('tổng hợp trạng thái, thanh toán và doanh thu hoàn thành', () {
      final stats = DashboardStats.fromBookings([
        {
          'status': 'completed',
          'totalPrice': 150000,
          'payment': {'status': 'paid'},
        },
        {
          'status': 'pending',
          'totalPrice': 80000,
          'payment': {'status': 'unpaid'},
        },
        {
          'status': 'cancelled',
          'totalPrice': 30000,
          'payment': {'status': 'unpaid'},
        },
      ]);

      expect(stats.total, 3);
      expect(stats.completed, 1);
      expect(stats.pending, 1);
      expect(stats.cancelled, 1);
      expect(stats.paid, 1);
      expect(stats.revenue, 150000);
      expect(stats.cancellationRate, closeTo(1 / 3, 0.0001));
    });

    test('không chia cho không khi chưa có lịch', () {
      final stats = DashboardStats.fromBookings(const []);
      expect(stats.total, 0);
      expect(stats.revenue, 0);
      expect(stats.cancellationRate, 0);
    });
  });
}
