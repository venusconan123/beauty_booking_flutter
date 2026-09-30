import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _ink = Color(0xFF08111E);
  static const _panel = Color(0xFF111B29);
  static const _field = Color(0xFF182432);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      _name.text = data?['name']?.toString() ?? user.displayName ?? '';
      _phone.text = data?['phone']?.toString() ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePhone(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final user = _user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final name = _name.text.trim();
      final phone = _normalizePhone(_phone.text);
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': user.email,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) _message('Đã cập nhật hồ sơ.');
    } on FirebaseException catch (error) {
      if (mounted) _message(error.message ?? 'Không thể cập nhật hồ sơ.', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _user?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _message('Đã gửi liên kết đổi mật khẩu tới $email.');
    } on FirebaseAuthException catch (error) {
      if (mounted) _message(error.message ?? 'Không thể gửi email.', true);
    }
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1420),
        foregroundColor: Colors.white,
        title: const Text('Hồ sơ cá nhân'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x44F6C768)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: const Color(0x22F6C768),
                              child: Text(
                                (_name.text.trim().isEmpty ? 'U' : _name.text.trim()[0]).toUpperCase(),
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _textField(
                              controller: _name,
                              label: 'Họ và tên',
                              icon: Icons.person_outline_rounded,
                              validator: (value) => (value ?? '').trim().length < 2
                                  ? 'Vui lòng nhập họ tên hợp lệ'
                                  : null,
                            ),
                            const SizedBox(height: 13),
                            _textField(
                              initialValue: user?.email ?? '',
                              label: 'Email đăng nhập',
                              icon: Icons.email_outlined,
                              enabled: false,
                            ),
                            const SizedBox(height: 13),
                            _textField(
                              controller: _phone,
                              label: 'Số điện thoại',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final phone = _normalizePhone(value ?? '');
                                return RegExp(r'^0[0-9]{9}$').hasMatch(phone)
                                    ? null
                                    : 'Số điện thoại phải gồm 10 số và bắt đầu bằng 0';
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: _ink,
                                ),
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _resetPassword,
                              icon: const Icon(Icons.lock_reset_rounded),
                              label: const Text('Gửi email đổi mật khẩu'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Số điện thoại này sẽ được lưu cùng lịch hẹn để chi nhánh có thể liên hệ khi cần.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _textField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        prefixIcon: Icon(icon, color: _gold),
        filled: true,
        fillColor: _field,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
