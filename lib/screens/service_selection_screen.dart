import 'package:flutter/material.dart';

import '../models/salon.dart';
import 'package:beauty_booking_app/screens/barber_selection_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  final Salon salon;

  const ServiceSelectionScreen({
    super.key,
    required this.salon,
  });

  @override
  State<ServiceSelectionScreen> createState() {
    return _ServiceSelectionScreenState();
  }
}

class _ServiceSelectionScreenState
    extends State<ServiceSelectionScreen> {
  final Set<String> _selectedServiceIds = {};

  int get _totalPrice {
    return widget.salon.services
        .where(
          (service) => _selectedServiceIds.contains(service.id),
        )
        .fold(
          0,
          (total, service) => total + service.price,
        );
  }

  int get _totalDuration {
    return widget.salon.services
        .where(
          (service) => _selectedServiceIds.contains(service.id),
        )
        .fold(
          0,
          (total, service) => total + service.durationMinutes,
        );
  }

  void _toggleService(String serviceId) {
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
    });
  }

  String _formatPrice(int price) {
    return '${price ~/ 1000}.000đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn dịch vụ'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.salon.services.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          final service = widget.salon.services[index];

          final bool isSelected =
              _selectedServiceIds.contains(service.id);

          return Card(
            color: isSelected
                ? const Color(0xFFE8F0FE)
                : null,
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                _toggleService(service.id);
              },
              secondary: CircleAvatar(
                backgroundColor: isSelected
                    ? const Color(0xFF1E3A5F)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.content_cut,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF1E3A5F),
                ),
              ),
              title: Text(
                service.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${service.durationMinutes} phút'
                  ' • ${_formatPrice(service.price)}\n'
                  '${service.description}',
                ),
              ),
              isThreeLine: true,
              controlAffinity:
                  ListTileControlAffinity.trailing,
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đã chọn: '
                      '${_selectedServiceIds.length} dịch vụ',
                    ),
                  ),
                  Text(
                    _formatPrice(_totalPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Tổng thời gian dự kiến:'),
                  const Spacer(),
                  Text(
                    '$_totalDuration phút',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _selectedServiceIds.isEmpty
                      ? null
                      : () {
                         final selectedServices = widget.salon.services
            .where(
              (service) =>
                  _selectedServiceIds.contains(service.id),
            )
            .toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarberSelectionScreen(
              salon: widget.salon,
              selectedServices: selectedServices,
            ),
          ),
        );
      },
                  child: const Text(
                    'Tiếp tục đặt lịch',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}