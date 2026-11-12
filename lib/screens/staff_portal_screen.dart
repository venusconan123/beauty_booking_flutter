import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/staff_access.dart';
import '../widgets/salon_page_intro.dart';
import '../services/scheduling_service.dart';
import 'staff_bookings_screen.dart';
import 'staff_statistics_screen.dart';
export 'staff_bookings_screen.dart' show StaffBookingList;
import 'work_shifts_screen.dart';
import 'change_password_screen.dart';

class StaffPortalScreen extends StatefulWidget {
  const StaffPortalScreen({super.key, required this.access});
  final StaffAccess access;

  @override
  State<StaffPortalScreen> createState() => _StaffPortalScreenState();
}

class _StaffPortalScreenState extends State<StaffPortalScreen> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bookings;
  SchedulingMutation? _pending;

  Future<void> _changeStatus(Map<String, dynamic> row, String status) async {
    final request = _pending ??= SchedulingMutation('changeBookingStatus', {
      'bookingId': row['id'],
      'status': status,
    });
    if (mounted) setState(() {});
    if (request.data['bookingId'] != row['id'] ||
        request.data['status'] != status) {
      throw StateError(
        'Cần xác nhận kết quả thao tác trước đó trước khi tiếp tục.',
      );
    }
    try {
      await SchedulingService().call(request.name, request.data);
      if (mounted) setState(() => _pending = null);
    } on SchedulingRejectedException {
      if (mounted) setState(() => _pending = null);
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _watchBookings();
  }

  @override
  void didUpdateWidget(covariant StaffPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.access.employeeId != widget.access.employeeId) {
      _pending = null;
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
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _bookings,
        builder: (context, snapshot) {
          Widget appointments;
          Widget statistics;
          // Never display cached bookings after a permission error.
          if (snapshot.hasError) {
            appointments = statistics = const Center(
              child: Text(
                'Không thể tải lịch hẹn hoặc quyền truy cập đã thay đổi.',
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.metadata.isFromCache) {
            appointments = statistics = const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            final bookings = snapshot.data!.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
            bookings.sort((a, b) => _time(a).compareTo(_time(b)));
            statistics = StaffStatisticsScreen(bookings: bookings);
            appointments = StaffBookingList(
              bookings: bookings,
              onChangeStatus: _changeStatus,
              pendingAction: _pending?.data,
            );
          }
          return StaffWorkspace(
            access: widget.access,
            email: FirebaseAuth.instance.currentUser?.email ?? '',
            onSignOut: () => FirebaseAuth.instance.signOut(),
            shifts: WorkShiftsScreen(access: widget.access),
            statistics: statistics,
            bookings: appointments,
          );
        },
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
    this.statistics,
    this.onChangePassword,
  });
  final StaffAccess access;
  final String email;
  final VoidCallback onSignOut;
  final Widget bookings;
  final Widget? shifts;
  final Widget? statistics;
  final Future<void> Function(String currentPassword, String newPassword)?
  onChangePassword;

  @override
  State<StaffWorkspace> createState() => _StaffWorkspaceState();
}

class _StaffWorkspaceState extends State<StaffWorkspace> {
  int _tab = 1;

  Future<void> _changePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ChangePasswordScreen(onChangePassword: widget.onChangePassword),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã đổi mật khẩu. Dùng mật khẩu mới cho lần đăng nhập sau.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Lịch hẹn', 'Lịch làm', 'Thống kê', 'Tài khoản'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${titles[_tab]} • ${widget.access.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch (_tab) {
        0 => LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              if (constraints.maxHeight >= 650)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SalonPageIntro(
                    label: 'KHÔNG GIAN NHÂN VIÊN',
                    title: 'Chào ${widget.access.name},',
                    description:
                        'Theo dõi lịch được giao và chuẩn bị cho từng cuộc hẹn.',
                    icon: Icons.badge_outlined,
                  ),
                ),
              Expanded(child: widget.bookings),
            ],
          ),
        ),
        1 =>
          widget.shifts ??
              const StaffPhaseOnePlaceholder(
                icon: Icons.calendar_month_outlined,
                text: 'Lịch làm sẽ có trong phiên bản tiếp theo.',
              ),
        2 => widget.statistics ?? const StaffStatisticsScreen(bookings: []),
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
            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Đổi mật khẩu'),
            ),
            const SizedBox(height: 12),
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
