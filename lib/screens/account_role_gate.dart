import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/staff_access.dart';
import 'email_verification_screen.dart';
import 'home_screen.dart';
import 'staff_portal_screen.dart';

/// A live role gate: errors fail closed; deactivation replaces the entire
/// workspace, disposing its appointment subscription rather than hiding tabs.
class AccountRoleGate extends StatefulWidget {
  const AccountRoleGate({super.key, required this.user});
  final User user;
  @override
  State<AccountRoleGate> createState() => _AccountRoleGateState();
}

class _AccountRoleGateState extends State<AccountRoleGate> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _admin;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _account;
  String? _employeeId;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _employee;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _link;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    _admin = db
        .collection('admins')
        .doc(widget.user.uid)
        .snapshots(includeMetadataChanges: true);
    _account = db
        .collection('staff_accounts')
        .doc(widget.user.uid)
        .snapshots(includeMetadataChanges: true);
  }

  Widget _waiting() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
  Widget _blocked([String? message]) => StaffAccessBlocked(
    message:
        message ??
        'Tài khoản nhân viên đã ngừng hoạt động hoặc liên kết không hợp lệ.',
    onSignOut: () => FirebaseAuth.instance.signOut(),
  );

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _admin,
        builder: (context, admin) {
          if (admin.hasError) {
            return _blocked(
              'Không thể xác minh quyền truy cập. Vui lòng đăng nhập lại.',
            );
          }
          if (!admin.hasData || admin.data!.metadata.isFromCache) {
            return _waiting();
          }
          if (admin.data!.exists) return const HomeScreen();
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _account,
            builder: (context, account) {
              if (account.hasError) {
                return _blocked('Không thể xác minh tài khoản nhân viên.');
              }
              if (!account.hasData || account.data!.metadata.isFromCache) {
                return _waiting();
              }
              final data = account.data!.data();
              if (data == null) return const HomeScreen();
              if (data['active'] != true) return _blocked();
              final id = data['employeeId'];
              if (id is! String || id.isEmpty || id.contains('/')) {
                return _blocked();
              }
              if (!widget.user.emailVerified) {
                return EmailVerificationScreen(user: widget.user);
              }
              if (_employeeId != id) {
                _employeeId = id;
                _employee = FirebaseFirestore.instance
                    .collection('employees')
                    .doc(id)
                    .snapshots(includeMetadataChanges: true);
                _link = FirebaseFirestore.instance
                    .collection('employee_accounts')
                    .doc(id)
                    .snapshots(includeMetadataChanges: true);
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                key: ValueKey('employee-$id'),
                stream: _employee,
                builder: (context, employee) {
                  if (employee.hasError) return _blocked();
                  if (!employee.hasData ||
                      employee.data!.metadata.isFromCache) {
                    return _waiting();
                  }
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _link,
                    builder: (context, link) {
                      if (link.hasError) return _blocked();
                      if (!link.hasData || link.data!.metadata.isFromCache) {
                        return _waiting();
                      }
                      final profile = employee.data!.data();
                      final role = StaffAccess.resolve(
                        isAdmin: false,
                        uid: widget.user.uid,
                        account: data,
                        employee: profile,
                        linkedUid: link.data!.data()?['uid'] is String
                            ? link.data!.data()!['uid'] as String
                            : null,
                      );
                      if (role != AccountRole.staff) return _blocked();
                      return StaffPortalScreen(
                        access: StaffAccess(
                          employeeId: id,
                          salonId: profile!['salonId'] as String,
                          name: profile['name']?.toString() ?? 'Nhân viên',
                          active: true,
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
}

class StaffAccessBlocked extends StatelessWidget {
  const StaffAccessBlocked({
    super.key,
    required this.message,
    required this.onSignOut,
  });
  final String message;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onSignOut, child: const Text('Đăng xuất')),
          ],
        ),
      ),
    ),
  );
}
