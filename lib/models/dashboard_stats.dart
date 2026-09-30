class DashboardStats {
  const DashboardStats({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.paid,
    required this.revenue,
  });

  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int paid;
  final int revenue;

  double get cancellationRate => total == 0 ? 0 : cancelled / total;

  factory DashboardStats.fromBookings(Iterable<Map<String, dynamic>> bookings) {
    var total = 0;
    var pending = 0;
    var confirmed = 0;
    var completed = 0;
    var cancelled = 0;
    var paid = 0;
    var revenue = 0;
    for (final booking in bookings) {
      total++;
      final status = booking['status']?.toString() ?? 'pending';
      if (status == 'pending') pending++;
      if (status == 'confirmed') confirmed++;
      if (status == 'completed') completed++;
      if (status == 'cancelled') cancelled++;
      final payment = booking['payment'];
      final isPaid = payment is Map && payment['status'] == 'paid';
      if (isPaid) paid++;
      if (status == 'completed') {
        revenue += (booking['totalPrice'] as num?)?.toInt() ?? 0;
      }
    }
    return DashboardStats(
      total: total,
      pending: pending,
      confirmed: confirmed,
      completed: completed,
      cancelled: cancelled,
      paid: paid,
      revenue: revenue,
    );
  }
}
