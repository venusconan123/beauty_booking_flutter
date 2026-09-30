import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({required this.user, super.key});

  final User user;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const _ink = Color(0xFF08111E);
  static const _panel = Color(0xFF101925);
  static const _gold = Color(0xFFF6C768);
  static const _muted = Color(0xFFB8C0CC);

  Timer? _timer;
  int _resendSeconds = 0;
  bool _checking = false;
  bool _sending = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _checkVerification() async {
    if (_checking) {
      return;
    }
    setState(() => _checking = true);

    try {
      await widget.user.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await user.getIdToken(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác minh email thành công.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email chưa được xác minh. Hãy mở liên kết trong hộp thư rồi thử lại.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      _showError(_authMessage(error, 'Không thể kiểm tra trạng thái xác minh.'));
    } catch (_) {
      _showError('Không thể kiểm tra trạng thái xác minh. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_sending || _resendSeconds > 0) {
      return;
    }
    setState(() => _sending = true);

    try {
      await FirebaseAuth.instance.setLanguageCode('vi');
      await widget.user.sendEmailVerification();
      if (!mounted) {
        return;
      }
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi lại liên kết đến ${widget.user.email ?? ''}.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (error) {
      _showError(_authMessage(error, 'Không thể gửi lại email xác minh.'));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _authMessage(FirebaseAuthException error, String fallback) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Không có kết nối mạng.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      default:
        return error.message ?? fallback;
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0x66F6C768)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 30,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        color: Color(0x1FF6C768),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        color: _gold,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Xác minh email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chúng tôi đã gửi liên kết xác minh đến',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.user.email ?? 'email của bạn',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hãy kiểm tra cả hộp thư chính và thư rác, sau đó bấm nút bên dưới.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _checking ? null : _checkVerification,
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _ink,
                        ),
                        icon: _checking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: _ink,
                                ),
                              )
                            : const Icon(Icons.verified_rounded),
                        label: Text(
                          _checking ? 'Đang kiểm tra...' : 'Tôi đã xác minh',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _sending || _resendSeconds > 0
                          ? null
                          : _resendEmail,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        _resendSeconds > 0
                            ? 'Gửi lại sau $_resendSeconds giây'
                            : 'Gửi lại email xác minh',
                      ),
                      style: TextButton.styleFrom(foregroundColor: _gold),
                    ),
                    const Divider(height: 30, color: Color(0x334F5B69)),
                    TextButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Đăng xuất'),
                      style: TextButton.styleFrom(foregroundColor: _muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
