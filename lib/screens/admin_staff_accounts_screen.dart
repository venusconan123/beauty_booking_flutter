import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/staff_account_service.dart';

class AdminStaffAccountsScreen extends StatefulWidget {
  const AdminStaffAccountsScreen({super.key});
  @override
  State<AdminStaffAccountsScreen> createState() =>
      _AdminStaffAccountsScreenState();
}

class _AdminStaffAccountsScreenState extends State<AdminStaffAccountsScreen> {
  final _uid = TextEditingController();
  final _service = StaffAccountService();
  late final _employees = FirebaseFirestore.instance
      .collection('employees')
      .snapshots();
  late final _accounts = FirebaseFirestore.instance
      .collection('staff_accounts')
      .snapshots();
  String? _employeeId;
  bool _saving = false;

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() operation) async {
    setState(() => _saving = true);
    try {
      await operation();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã cập nhật liên kết.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản nhân viên')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Liên kết UID của tài khoản Auth đã tồn tại và xác minh email với hồ sơ nhân viên. '
          'Không tạo tài khoản mới. Mỗi UID và nhân viên chỉ được liên kết một lần.',
        ),
        if (!StaffAccountService.emulatorEnabled)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Bản cục bộ: thao tác liên kết chỉ được bật khi chạy với Emulator.',
            ),
          ),
        TextField(
          controller: _uid,
          decoration: const InputDecoration(labelText: 'Firebase Auth UID'),
          enabled: !_saving,
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _employees,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Không thể tải hồ sơ nhân viên.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final employees = snapshot.data!.docs
                .where((doc) => doc.id != '_catalog')
                .toList();
            return DropdownButtonFormField<String>(
              initialValue: employees.any((doc) => doc.id == _employeeId)
                  ? _employeeId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Hồ sơ nhân viên hiện có',
              ),
              items: employees
                  .map(
                    (doc) => DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        '${doc.data()['name']} • ${doc.data()['salonId']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _employeeId = value),
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving || !StaffAccountService.emulatorEnabled
              ? null
              : () {
                  if (_employeeId == null || _uid.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chọn nhân viên và nhập UID.'),
                      ),
                    );
                    return;
                  }
                  _perform(() => _service.link(_uid.text, _employeeId!));
                },
          child: Text(_saving ? 'Đang cập nhật...' : 'Liên kết tài khoản'),
        ),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _accounts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Không thể tải liên kết tài khoản.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.docs.isEmpty) {
              return const Text('Chưa có tài khoản nhân viên được liên kết.');
            }
            return Column(
              children: snapshot.data!.docs
                  .map(
                    (doc) => SwitchListTile(
                      title: Text('${doc.data()['employeeId']}'),
                      subtitle: SelectableText(doc.id),
                      value: doc.data()['active'] == true,
                      onChanged: _saving || !StaffAccountService.emulatorEnabled
                          ? null
                          : (active) => _perform(
                              () => _service.setActive(doc.id, active),
                            ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}
