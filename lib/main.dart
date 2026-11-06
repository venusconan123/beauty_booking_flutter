import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/staff_account_service.dart';

Future<void> main() async {
  debugPrint('[startup] dart-main');
  WidgetsFlutterBinding.ensureInitialized();

  if (StaffAccountService.emulatorEnabled) {
    // A demo project is deliberate: emulator tests cannot address production.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:123:web:demo',
        messagingSenderId: '123',
        projectId: 'demo-men-hair-booking',
      ),
    );
    debugPrint('[startup] firebase-ready (demo)');
    const host = StaffAccountService.emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    debugPrint('[startup] auth-emulator-ready');
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    debugPrint('[startup] firestore-emulator-ready');
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint('[startup] run-app');
  runApp(const MenHairBookingApp());
}

class MenHairBookingApp extends StatelessWidget {
  const MenHairBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Men Hair Booking',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A5F)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      builder: (context, child) => StaffAccountService.emulatorEnabled
          ? Padding(padding: const EdgeInsets.only(bottom: 48), child: child)
          : child ?? const SizedBox.shrink(),
    );
  }
}
