import 'package:flutter/material.dart';

import '../data/sample_barbers.dart';
import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';

class BarberSelectionScreen extends StatefulWidget {
  final Salon salon;
  final List<HairService> selectedServices;

  const BarberSelectionScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
  });

  @override
  State<BarberSelectionScreen> createState() {
    return _BarberSelectionScreenState();
  }
}

class _BarberSelectionScreenState
    extends State<BarberSelectionScreen> {
  String? _selectedBarberId;

  late final List<Barber> _barbers;

  @override
  void initState() {
    super.initState();

    _barbers = getBarbersBySalonId(widget.salon.id);
  }

  void _selectBarber(String barberId) {
    setState(() {
      _selectedBarberId = barberId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn thợ cắt tóc'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.salon.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đã chọn ${widget.selectedServices.length} dịch vụ',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 20),
          _buildAnyBarberOption(),
          const SizedBox(height: 20),
          const Text(
            'Danh sách thợ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              int columnCount = 2;

              if (constraints.maxWidth >= 900) {
                columnCount = 4;
              } else if (constraints.maxWidth >= 600) {
                columnCount = 3;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _barbers.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  return _buildBarberCard(_barbers[index]);
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _selectedBarberId == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Bước tiếp theo: chọn ngày và giờ.',
                          ),
                        ),
                      );
                    },
              child: const Text(
                'Tiếp tục chọn thời gian',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnyBarberOption() {
  final bool isSelected =
      _selectedBarberId == 'any_barber';

  return Card(
    color: isSelected
        ? const Color(0xFFE8F0FE)
        : null,
    child: ListTile(
      onTap: () {
        _selectBarber('any_barber');
      },
      leading: const CircleAvatar(
        child: Icon(Icons.people),
      ),
      title: const Text(
        'Chọn thợ bất kỳ',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text(
        'Hệ thống sẽ chọn một thợ đang trống lịch.',
      ),
      trailing: Icon(
        isSelected
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        color: isSelected
            ? const Color(0xFF1E3A5F)
            : Colors.grey,
      ),
    ),
  );
}

  Widget _buildBarberCard(Barber barber) {
    final bool isSelected =
        _selectedBarberId == barber.id;

    return Card(
      color: isSelected
          ? const Color(0xFFE8F0FE)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF1E3A5F)
              : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _selectBarber(barber.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: barber.imageUrl != null
                    ? NetworkImage(barber.imageUrl!)
                    : null,
                child: barber.imageUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 48,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                barber.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${barber.experienceYears} năm kinh nghiệm',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star,
                    size: 18,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text('${barber.rating}'),
                ],
              ),
              const SizedBox(height: 6),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF1E3A5F),
                ),
            ],
          ),
        ),
      ),
    );
  }
}