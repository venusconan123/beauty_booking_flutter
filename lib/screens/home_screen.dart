import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../models/salon.dart';
import 'salon_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.logout,
            color: Color(0xFF1E3A5F),
            size: 48,
          ),
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất không?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Men Hair Booking',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () {
              _confirmLogout(context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Xin chào!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn salon và đặt lịch cắt tóc ngay hôm nay.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Dịch vụ phổ biến',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildServiceItem(
                  icon: Icons.content_cut,
                  title: 'Cắt tóc',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildServiceItem(
                  icon: Icons.shower,
                  title: 'Gội đầu',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildServiceItem(
                  icon: Icons.auto_awesome,
                  title: 'Tạo kiểu',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Salon gần bạn',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...sampleSalons.map(
            (salon) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSalonCard(
                  context,
                  salon,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String title,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF1E3A5F),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonCard(
    BuildContext context,
    Salon salon,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          radius: 26,
          child: Icon(Icons.content_cut),
        ),
        title: Text(
          salon.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                salon.services
                    .map((service) => service.name)
                    .join(' • '),
              ),
              const SizedBox(height: 4),
              Text(salon.address),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    size: 17,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text('${salon.rating}'),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text('${salon.distance} km'),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) {
                return SalonDetailScreen(
                  salon: salon,
                );
              },
            ),
          );
        },
      ),
    );
  }
}