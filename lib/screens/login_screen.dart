import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _backgroundAsset =
      'assets/images/login_barbershop_background.jpg';
  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xDD101925);
  static const _field = Color(0xD9182230);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập thành công.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Không thể đăng nhập.';

      switch (error.code) {
        case 'invalid-email':
          message = 'Địa chỉ email không hợp lệ.';
          break;
        case 'user-disabled':
          message = 'Tài khoản này đã bị vô hiệu hóa.';
          break;
        case 'user-not-found':
          message = 'Không tìm thấy tài khoản với email này.';
          break;
        case 'wrong-password':
          message = 'Mật khẩu không chính xác.';
          break;
        case 'invalid-credential':
          message = 'Email hoặc mật khẩu không chính xác.';
          break;
        case 'too-many-requests':
          message =
              'Bạn đã thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.';
          break;
        case 'network-request-failed':
          message = 'Không có kết nối mạng.';
          break;
        default:
          message = error.message ?? message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
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

  Future<void> _openRegisterScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final dialogFormKey = GlobalKey<FormState>();
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          if (dialogFormKey.currentState!.validate()) {
            Navigator.of(dialogContext).pop(
              resetEmailController.text.trim(),
            );
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF111A27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0x66F6C768)),
          ),
          icon: const Icon(
            Icons.lock_reset_rounded,
            color: _gold,
            size: 48,
          ),
          title: const Text(
            'Lấy lại mật khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập email đã đăng ký để nhận liên kết đặt lại mật khẩu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: resetEmailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  cursorColor: _gold,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration(
                    label: 'Email',
                    hint: 'Nhập email của bạn',
                    icon: Icons.mail_outline_rounded,
                  ),
                  onFieldSubmitted: (_) => submit(),
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) {
                      return 'Vui lòng nhập email.';
                    }
                    if (!input.contains('@') || !input.contains('.')) {
                      return 'Email không đúng định dạng.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: _muted),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: submit,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Gửi liên kết'),
            ),
          ],
        );
      },
    );

    resetEmailController.dispose();

    if (email == null || !mounted) {
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111A27),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0x66F6C768)),
            ),
            icon: const Icon(
              Icons.mark_email_read_rounded,
              color: _gold,
              size: 52,
            ),
            title: const Text(
              'Đã gửi email',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Hướng dẫn đặt lại mật khẩu đã được gửi đến $email.',
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
                child: const Text('Đồng ý'),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Không thể gửi email đặt lại mật khẩu.';
      if (error.code == 'invalid-email') {
        message = 'Địa chỉ email không hợp lệ.';
      } else if (error.code == 'network-request-failed') {
        message = 'Không có kết nối mạng.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                        constraints: const BoxConstraints(maxWidth: 520),
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
                                      const _BrandHeader(),
                                      const SizedBox(height: 30),
                                      const Text(
                                        'Chào mừng trở lại',
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
                                        'Đăng nhập để tiếp tục đặt lịch',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
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
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        cursorColor: _gold,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        onFieldSubmitted: (_) {
                                          if (!_isLoading) {
                                            _login();
                                          }
                                        },
                                        decoration: _fieldDecoration(
                                          label: 'Mật khẩu',
                                          hint: 'Nhập mật khẩu',
                                          icon: Icons.lock_outline_rounded,
                                          suffixIcon: IconButton(
                                            tooltip: _obscurePassword
                                                ? 'Hiện mật khẩu'
                                                : 'Ẩn mật khẩu',
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_off_rounded,
                                              color: _muted,
                                            ),
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
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _resetPassword,
                                          style: TextButton.styleFrom(
                                            foregroundColor: _gold,
                                          ),
                                          child: const Text('Quên mật khẩu?'),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        height: 58,
                                        child: FilledButton(
                                          onPressed:
                                              _isLoading ? null : _login,
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
                                                        'Đăng nhập',
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      SizedBox(width: 10),
                                                      Icon(
                                                        Icons.arrow_forward_rounded,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 2,
                                        children: [
                                          const Text(
                                            'Chưa có tài khoản?',
                                            style: TextStyle(color: _muted),
                                          ),
                                          TextButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _openRegisterScreen,
                                            style: TextButton.styleFrom(
                                              foregroundColor: _gold,
                                            ),
                                            child: const Text(
                                              'Đăng ký ngay',
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0x1AF6C768),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x99F6C768)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40F6C768),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(
            Icons.content_cut_rounded,
            color: _LoginScreenState._gold,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'MEN HAIR BOOKING',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _LoginScreenState._gold,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.1,
          ),
        ),
      ],
    );
  }
}
