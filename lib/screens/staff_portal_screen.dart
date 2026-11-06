import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/staff_access.dart';
import 'work_shifts_screen.dart';

class StaffPortalScreen extends StatefulWidget {
  const StaffPortalScreen({super.key, required this.access});
  final StaffAccess access;

  @override
  State<StaffPortalScreen> createState() => _StaffPortalScreenState();
}

class _StaffPortalScreenState extends State<StaffPortalScreen> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bookings;

  @override
  void initState() {
    super.initState();
    _watchBookings();
  }

  @override
  void didUpdateWidget(covariant StaffPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.access.employeeId != widget.access.employeeId) {
      _watchBookings();
    }
  }

  void _watchBookings() {
    _bookings = FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: widget.access.employeeId)
        .snapshots(includeMetadataChanges: true);
  }

  @override
  Widget build(BuildContext context) => StaffWorkspace(
    access: widget.access,
    email: FirebaseAuth.instance.currentUser?.email ?? '',
    onSignOut: () => FirebaseAuth.instance.signOut(),
    shifts: WorkShiftsScreen(access: widget.access),
    bookings: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bookings,
      builder: (context, snapshot) {
        // Never display cached bookings after a permission error.
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Không thể tải lịch hẹn hoặc quyền truy cập đã thay đổi.',
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.metadata.isFromCache) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings = snapshot.data!.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        bookings.sort((a, b) => _time(a).compareTo(_time(b)));
        return StaffBookingList(bookings: bookings);
      },
    ),
  );

  int _time(Map<String, dynamic> data) =>
      (data['appointmentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
}

/// The four-tab workspace can also render local preview data without Firebase.
class StaffWorkspace extends StatefulWidget {
  const StaffWorkspace({
    super.key,
    required this.access,
    required this.email,
    required this.onSignOut,
    required this.bookings,
    this.shifts,
  });
  final StaffAccess access;
  final String email;
  final VoidCallback onSignOut;
  final Widget bookings;
  final Widget? shifts;

  @override
  State<StaffWorkspace> createState() => _StaffWorkspaceState();
}

class _StaffWorkspaceState extends State<StaffWorkspace> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Lịch hẹn', 'Lịch làm', 'Thống kê', 'Tài khoản'];
    return Scaffold(
      appBar: AppBar(title: Text('${titles[_tab]} • ${widget.access.name}')),
      body: switch (_tab) {
        0 => widget.bookings,
        1 =>
          widget.shifts ??
              const StaffPhaseOnePlaceholder(
                icon: Icons.calendar_month_outlined,
                text: 'Lịch làm sẽ có trong phiên bản tiếp theo.',
              ),
        2 => const StaffPhaseOnePlaceholder(
          icon: Icons.bar_chart,
          text: 'Thống kê sẽ có trong phiên bản tiếp theo.',
        ),
        _ => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              title: Text(widget.access.name),
              subtitle: const Text('Nhân viên'),
            ),
            ListTile(
              title: const Text('Mã nhân viên'),
              subtitle: SelectableText(widget.access.employeeId),
            ),
            ListTile(
              title: const Text('Chi nhánh chính'),
              subtitle: Text(widget.access.salonId),
            ),
            ListTile(
              title: const Text('Tài khoản'),
              subtitle: Text(widget.email),
            ),
            FilledButton.icon(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note),
            label: 'Lịch hẹn',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Lịch làm',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Thống kê'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class StaffBookingList extends StatelessWidget {
  const StaffBookingList({super.key, required this.bookings});
  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(child: Text('Bạn chưa có lịch hẹn được phân công.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final instant = (booking['appointmentAt'] as Timestamp?)?.toDate();
        final vn = instant?.toUtc().add(const Duration(hours: 7));
        final date = vn == null
            ? 'Chưa có thời gian'
            : '${vn.day.toString().padLeft(2, '0')}/${vn.month.toString().padLeft(2, '0')}/${vn.year} '
                  '${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')}';
        final services = booking['services'];
        final names = services is List
            ? services
                  .whereType<Map>()
                  .map((s) => '${s['name'] ?? ''}')
                  .join(', ')
            : '';
        const statuses = {
          'pending': 'Chờ thanh toán',
          'confirmed': 'Đã xác nhận',
          'in_service': 'Đang phục vụ',
          'completed': 'Đã hoàn thành',
          'cancelled': 'Đã hủy',
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['userName']?.toString() ?? 'Khách hàng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('$date (giờ Việt Nam)'),
                Text(booking['salonName']?.toString() ?? ''),
                Text(names),
                Text(statuses[booking['status']] ?? 'Chưa rõ trạng thái'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StaffPhaseOnePlaceholder extends StatelessWidget {
  const StaffPhaseOnePlaceholder({
    super.key,
    required this.icon,
    required this.text,
  });
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
