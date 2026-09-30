import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'email_verification_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _verificationUid;
  Future<bool>? _verificationFuture;

  Future<bool> _requiresVerification(User user) {
    if (_verificationUid != user.uid || _verificationFuture == null) {
      _verificationUid = user.uid;
      _verificationFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then(
            (document) =>
                document.data()?['requiresEmailVerification'] == true,
          );
    }
    return _verificationFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không thể kiểm tra trạng thái đăng nhập.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          _verificationUid = null;
          _verificationFuture = null;
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          future: _requiresVerification(user),
          builder: (context, verificationSnapshot) {
            if (verificationSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (verificationSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Không thể kiểm tra trạng thái xác minh email.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _verificationFuture = null;
                            });
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final requiresVerification = verificationSnapshot.data ?? false;
            if (requiresVerification && !user.emailVerified) {
              return EmailVerificationScreen(user: user);
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
