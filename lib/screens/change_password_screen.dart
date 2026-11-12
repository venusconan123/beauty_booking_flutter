import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/password_change_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.onChangePassword});

  final Future<void> Function(String currentPassword, String newPassword)?
  onChangePassword;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  final _hidden = [true, true, true];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final change =
          widget.onChangePassword ?? PasswordChangeService().changePassword;
      await change(_current.text, _next.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirmation.clear();
      // Unlock PopScope before closing the route after a successful update.
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = passwordChangeErrorText(error));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể đổi mật khẩu lúc này. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Widget _passwordField({
    required int index,
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    String? helperText,
  }) => TextFormField(
    key: ValueKey('password-$index'),
    controller: controller,
    enabled: !_busy,
    obscureText: _hidden[index],
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
    autofillHints: [
      index == 0 ? AutofillHints.password : AutofillHints.newPassword,
    ],
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 2,
      errorMaxLines: 3,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: '${_hidden[index] ? 'Hiện' : 'Ẩn'} $label',
        onPressed: _busy
            ? null
            : () => setState(() => _hidden[index] = !_hidden[index]),
        icon: Icon(
          _hidden[index]
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: validator,
    onFieldSubmitted: index == 2 ? (_) => _submit() : null,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Nhập mật khẩu hiện tại để xác nhận và đặt mật khẩu mới cho tài khoản của bạn.',
                ),
                const SizedBox(height: 24),
                _passwordField(
                  index: 0,
                  label: 'Mật khẩu hiện tại',
                  controller: _current,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập mật khẩu hiện tại.'
                      : null,
                ),
                const SizedBox(height: 20),
                _passwordField(
                  index: 1,
                  label: 'Mật khẩu mới',
                  controller: _next,
                  helperText: '8–128 ký tự và khác mật khẩu hiện tại.',
                  validator: (value) {
                    if (value == null ||
                        value.length < 8 ||
                        value.length > 128) {
                      return 'Mật khẩu mới phải từ 8–128 ký tự.';
                    }
                    if (value == _current.text) {
                      return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _passwordField(
                  index: 2,
                  label: 'Xác nhận mật khẩu mới',
                  controller: _confirmation,
                  validator: (value) =>
                      value == null || value.isEmpty || value != _next.text
                      ? 'Mật khẩu xác nhận chưa khớp.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset),
                  label: Text(
                    _busy ? 'Đang đổi mật khẩu...' : 'Lưu mật khẩu mới',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
