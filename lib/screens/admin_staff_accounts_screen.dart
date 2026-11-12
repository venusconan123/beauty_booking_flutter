import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../services/staff_account_service.dart';

class AdminStaffAccountsScreen extends StatefulWidget {
  const AdminStaffAccountsScreen({super.key});
  @override
  State<AdminStaffAccountsScreen> createState() =>
      _AdminStaffAccountsScreenState();
}

class _AdminStaffAccountsScreenState extends State<AdminStaffAccountsScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _obscure = true;
  final _service = StaffAccountService();
  late final _employees = FirebaseFirestore.instance
      .collection('employees')
      .snapshots();
  late final _accounts = FirebaseFirestore.instance
      .collection('staff_accounts')
      .snapshots();
  String? _employeeId;
  String _salonId = 'salon_01';
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _perform(
    Future<void> Function() operation, {
    String message = 'Đã cập nhật tài khoản.',
  }) async {
    setState(() => _saving = true);
    try {
      await operation();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _create(Set<String> employeeIds) async {
    if (!_form.currentState!.validate()) return;
    if (_employeeId == null || !employeeIds.contains(_employeeId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hồ sơ nhân viên.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.create(
        email: _email.text,
        password: _password.text,
        employeeId: _employeeId!,
      );
      _password.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Đã tạo tài khoản nhân viên'),
          content: Text(
            '${result['email']}\n\n'
            'Nhân viên đăng nhập bằng email và mật khẩu ban đầu bạn vừa nhập.\n\n'
            '${result['requiresEmailVerification'] == true ? 'Lần đầu đăng nhập, nhân viên cần xác minh email. ' : ''}'
            'Sau đó ứng dụng tự mở tab Lịch làm.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
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
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _employees,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không thể tải hồ sơ nhân viên.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _content(
          snapshot.data!.docs.where((doc) => doc.id != '_catalog').toList(),
        );
      },
    ),
  );

  Widget _content(List<QueryDocumentSnapshot<Map<String, dynamic>>> employees) {
    final branchEmployees =
        employees.where((doc) => doc.data()['salonId'] == _salonId).toList()
          ..sort(
            (a, b) => '${a.data()['name']}'.compareTo('${b.data()['name']}'),
          );
    final employeeNames = {
      for (final doc in employees) doc.id: '${doc.data()['name'] ?? doc.id}',
    };
    final branchIds = branchEmployees.map((doc) => doc.id).toSet();
    final salon = sampleSalons.firstWhere((salon) => salon.id == _salonId);
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Chọn chi nhánh', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final branch in sampleSalons)
                    SizedBox(
                      width: width,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                          backgroundColor: branch.id == _salonId
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Colors.white,
                          side: BorderSide(
                            color: branch.id == _salonId
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xffdce1e7),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _saving
                            ? null
                            : () {
                                if (_salonId == branch.id) return;
                                setState(() {
                                  _salonId = branch.id;
                                  _employeeId = null;
                                });
                              },
                        child: Row(
                          children: [
                            Icon(
                              branch.id == _salonId
                                  ? Icons.check_circle
                                  : Icons.storefront_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branch.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${employees.where((doc) => doc.data()['salonId'] == branch.id).length} nhân viên',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(salon.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tạo tài khoản bằng email của nhân viên và chọn hồ sơ tương ứng. '
            'Email đã dùng cho tài khoản khách hàng hoặc nhân viên sẽ không được đăng ký lại.',
          ),
          const Text(
            'Chỉ quản trị viên được tạo hoặc thay đổi trạng thái tài khoản nhân viên.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email nhân viên',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                v == null ||
                    v.trim().length > 254 ||
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                ? 'Nhập email hợp lệ.'
                : null,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'Mật khẩu ban đầu',
              helperText: 'Mật khẩu ban đầu cần từ 8–128 ký tự.',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: 'Hiện / ẩn mật khẩu',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) => v == null || v.length < 8 || v.length > 128
                ? 'Mật khẩu cần từ 8 đến 128 ký tự.'
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              '$_salonId-${branchIds.contains(_employeeId) ? _employeeId : ''}',
            ),
            initialValue: branchIds.contains(_employeeId) ? _employeeId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Nhân viên trong chi nhánh',
            ),
            hint: Text(
              branchEmployees.isEmpty
                  ? 'Chi nhánh chưa có nhân viên'
                  : 'Chọn nhân viên',
            ),
            menuMaxHeight: 320,
            items: branchEmployees
                .map(
                  (doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(
                      '${doc.data()['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _employeeId = value),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : () => _create(branchIds),
            child: Text(_saving ? 'Đang xử lý...' : 'Tạo tài khoản nhân viên'),
          ),
          const SizedBox(height: 24),
          Text(
            'Tài khoản nhân viên',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _accounts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Không thể tải tài khoản nhân viên. '
                  'Kiểm tra quyền admin và cấu hình Firestore đã triển khai.\n${snapshot.error}',
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final accounts =
                  snapshot.data!.docs
                      .where(
                        (doc) => branchIds.contains(doc.data()['employeeId']),
                      )
                      .toList()
                    ..sort(
                      (a, b) => (employeeNames[a.data()['employeeId']] ?? a.id)
                          .compareTo(
                            employeeNames[b.data()['employeeId']] ?? b.id,
                          ),
                    );
              if (accounts.isEmpty) {
                return const Text('Chi nhánh này chưa có tài khoản nhân viên.');
              }
              return Column(
                children: accounts
                    .map(
                      (doc) => SwitchListTile(
                        title: Text(
                          employeeNames[doc.data()['employeeId']] ??
                              '${doc.data()['employeeId']}',
                        ),
                        subtitle: SelectableText(
                          '${doc.data()['email'] ?? doc.id}',
                        ),
                        value: doc.data()['active'] == true,
                        onChanged: _saving
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
}
