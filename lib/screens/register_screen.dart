import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _backgroundAsset =
      'assets/images/login_barbershop_background.jpg';
  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xE6101925);
  static const _field = Color(0xD9182230);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final user = credential.user;
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _normalizePhone(_phoneController.text);

      await user?.updateDisplayName(name);
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111A27),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0x66F6C768)),
            ),
            icon: const Icon(
              Icons.check_circle_rounded,
              color: _gold,
              size: 56,
            ),
            title: const Text(
              'Đăng ký thành công',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Chào mừng ${_nameController.text.trim()} '
              'đến với Men Hair Booking.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _ink,
                ),
                child: const Text('Tiếp tục'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Không thể đăng ký tài khoản.';
      switch (error.code) {
        case 'email-already-in-use':
          message = 'Email này đã được sử dụng.';
          break;
        case 'invalid-email':
          message = 'Địa chỉ email không hợp lệ.';
          break;
        case 'weak-password':
          message = 'Mật khẩu chưa đủ mạnh.';
          break;
        case 'network-request-failed':
          message = 'Không có kết nối mạng.';
          break;
        default:
          message = error.message ?? message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xảy ra lỗi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _validatePhone(String? value) {
    final phone = _normalizePhone(value ?? '');
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại.';
    if (!RegExp(r'^0[0-9]{9}$').hasMatch(phone)) {
      return 'Số điện thoại phải gồm 10 số và bắt đầu bằng 0.';
    }
    return null;
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)),
      borderSide: BorderSide(color: Color(0x66F6C768)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _gold),
      hintStyle: const TextStyle(color: Color(0xFF818B99)),
      prefixIcon: Icon(icon, color: _gold),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _field,
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide(color: _gold, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide(color: Color(0xFFFF8A80)),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide(color: Color(0xFFFF8A80), width: 1.6),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
    );
  }

  Widget _visibilityButton({
    required bool obscure,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: onPressed,
      icon: Icon(
        obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        color: _muted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x26000000),
                  Color(0x5C02070D),
                  Color(0xB3070D15),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final horizontalPadding = isWide ? 64.0 : 20.0;

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(36),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isWide ? 40 : 24),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: const Color(0x59F6C768),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x73000000),
                                    blurRadius: 32,
                                    offset: Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: AutofillGroup(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton.filledTonal(
                                            tooltip: 'Quay lại đăng nhập',
                                            onPressed: _isLoading
                                                ? null
                                                : () => Navigator.of(
                                                    context,
                                                  ).pop(),
                                            style: IconButton.styleFrom(
                                              backgroundColor: const Color(
                                                0x1AF6C768,
                                              ),
                                              foregroundColor: _gold,
                                            ),
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            Icons.content_cut_rounded,
                                            color: _gold,
                                            size: 34,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 22),
                                      const Text(
                                        'Tạo tài khoản',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          height: 1.15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Đăng ký để đặt lịch cắt tóc thuận tiện hơn',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 26),
                                      TextFormField(
                                        controller: _nameController,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.name,
                                        ],
                                        cursorColor: _gold,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: _fieldDecoration(
                                          label: 'Họ và tên',
                                          hint: 'Nhập họ và tên',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                        validator: (value) {
                                          final name = value?.trim() ?? '';
                                          if (name.isEmpty) {
                                            return 'Vui lòng nhập họ và tên.';
                                          }
                                          if (name.length < 2) {
                                            return 'Họ và tên phải có ít nhất 2 ký tự.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email,
                                        ],
                                        cursorColor: _gold,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: _fieldDecoration(
                                          label: 'Email',
                                          hint: 'Nhập email của bạn',
                                          icon: Icons.mail_outline_rounded,
                                        ),
                                        validator: (value) {
                                          final email = value?.trim() ?? '';
                                          if (email.isEmpty) {
                                            return 'Vui lòng nhập email.';
                                          }
                                          if (!email.contains('@') ||
                                              !email.contains('.')) {
                                            return 'Email không đúng định dạng.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.telephoneNumber,
                                        ],
                                        cursorColor: _gold,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: _fieldDecoration(
                                          label: 'Số điện thoại',
                                          hint: 'Ví dụ: 0905123456',
                                          icon: Icons.phone_outlined,
                                        ),
                                        validator: _validatePhone,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        cursorColor: _gold,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: _fieldDecoration(
                                          label: 'Mật khẩu',
                                          hint: 'Tối thiểu 6 ký tự',
                                          icon: Icons.lock_outline_rounded,
                                          suffixIcon: _visibilityButton(
                                            obscure: _obscurePassword,
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Vui lòng nhập mật khẩu.';
                                          }
                                          if (value.length < 6) {
                                            return 'Mật khẩu phải có ít nhất 6 ký tự.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        cursorColor: _gold,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        onFieldSubmitted: (_) {
                                          if (!_isLoading) {
                                            _register();
                                          }
                                        },
                                        decoration: _fieldDecoration(
                                          label: 'Nhập lại mật khẩu',
                                          hint: 'Xác nhận mật khẩu',
                                          icon: Icons.lock_reset_rounded,
                                          suffixIcon: _visibilityButton(
                                            obscure: _obscureConfirmPassword,
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Vui lòng nhập lại mật khẩu.';
                                          }
                                          if (value !=
                                              _passwordController.text) {
                                            return 'Hai mật khẩu không giống nhau.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        height: 58,
                                        child: FilledButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _register,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _gold,
                                            foregroundColor: _ink,
                                            disabledBackgroundColor:
                                                const Color(0xFF9A8050),
                                            disabledForegroundColor: _ink,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                            ),
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    key: ValueKey('loading'),
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.4,
                                                          color: _ink,
                                                        ),
                                                  )
                                                : const Row(
                                                    key: ValueKey('label'),
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Đăng ký',
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      SizedBox(width: 10),
                                                      Icon(
                                                        Icons
                                                            .person_add_rounded,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 2,
                                        children: [
                                          const Text(
                                            'Đã có tài khoản?',
                                            style: TextStyle(color: _muted),
                                          ),
                                          TextButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () => Navigator.of(
                                                    context,
                                                  ).pop(),
                                            style: TextButton.styleFrom(
                                              foregroundColor: _gold,
                                            ),
                                            child: const Text(
                                              'Đăng nhập',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
