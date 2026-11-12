import 'package:flutter/material.dart';

/// Shared page header for the Firebase-backed customer and staff screens.
class SalonPageIntro extends StatelessWidget {
  const SalonPageIntro({
    super.key,
    required this.label,
    required this.title,
    required this.description,
    this.icon = Icons.content_cut,
  });
  final String label, title, description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff0b1623), Color(0xff263e50)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x33d9ad60)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xffd9ad60),
                    letterSpacing: 1.8,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xffc4cfd9), height: 1.5),
                ),
              ],
            ),
          ),
          if (constraints.maxWidth >= 650) ...[
            const SizedBox(width: 30),
            Icon(icon, size: 56, color: const Color(0xffd9ad60)),
          ],
        ],
      ),
    ),
  );
}
