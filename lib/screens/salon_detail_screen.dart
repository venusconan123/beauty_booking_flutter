import 'package:flutter/material.dart';
import 'salon_detail_screen.dart';

import '../models/salon.dart';

class SalonDetailScreen extends StatelessWidget {
  final Salon salon;

  const SalonDetailScreen({
    super.key,
    required this.salon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(salon.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.content_cut,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            salon.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text('${salon.rating}'),
              const SizedBox(width: 20),
              const Icon(
                Icons.location_on_outlined,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text('${salon.distance} km'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  salon.address,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Dịch vụ tại salon',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...salon.services.map(
  (service) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: const CircleAvatar(
        child: Icon(Icons.content_cut),
      ),
      title: Text(
        service.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${service.durationMinutes} phút\n'
          '${service.description}',
        ),
      ),
      isThreeLine: true,
      trailing: Text(
        '${service.price ~/ 1000}.000đ',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A5F),
        ),
      ),
    ),
  ),
),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Chức năng đặt lịch sẽ được làm ở bước tiếp theo.',
                    ),
                  ),
                );
              },
              child: const Text(
                'Đặt lịch ngay',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}