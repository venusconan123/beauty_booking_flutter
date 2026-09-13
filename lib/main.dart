import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}