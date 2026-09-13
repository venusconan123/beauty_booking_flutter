import 'package:flutter/material.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Salon salon;
  final List<HairService> selectedServices;
  final Barber? selectedBarber;
  final bool useAnyBarber;
  final DateTime selectedDate;
  final String selectedTime;

  const BookingConfirmationScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
    required this.selectedBarber,
    required this.useAnyBarber,
    required this.selectedDate,
    required this.selectedTime,
  });

  int get totalPrice {
    return selectedServices.fold(
      0,
      (total, service) => total + service.price,
    );
  }

  int get totalDuration {
    return selectedServices.fold(
      0,
      (total, service) => total + service.durationMinutes,
    );
  }

  String formatPrice(int price) {
    return '${price ~/ 1000}.000đ';
  }

  String formatDate(DateTime date) {
    final String day =
        date.day.toString().padLeft(2, '0');

    final String month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final String barberName = useAnyBarber
        ? 'Thợ bất kỳ'
        : selectedBarber?.name ?? 'Chưa chọn thợ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đặt lịch'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.event_available,
            size: 70,
            color: Color(0xFF1E3A5F),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kiểm tra thông tin lịch hẹn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInformationRow(
                    icon: Icons.store,
                    title: 'Chi nhánh',
                    value: salon.name,
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.location_on_outlined,
                    title: 'Địa chỉ',
                    value: salon.address,
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.person_outline,
                    title: 'Thợ',
                    value: barberName,
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.calendar_month,
                    title: 'Ngày hẹn',
                    value: formatDate(selectedDate),
                  ),
                  const Divider(height: 24),
                  _buildInformationRow(
                    icon: Icons.schedule,
                    title: 'Giờ hẹn',
                    value: selectedTime,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Dịch vụ đã chọn',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...selectedServices.map(
                    (service) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${service.durationMinutes} phút',
                                  style: TextStyle(
                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatPrice(service.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Tổng thời gian'),
                      const Spacer(),
                      Text(
                        '$totalDuration phút',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Tổng thanh toán',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatPrice(totalPrice),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                _showConfirmationDialog(context);
              },
              icon: const Icon(Icons.check),
              label: const Text(
                'Xác nhận đặt lịch',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF1E3A5F),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            size: 56,
            color: Colors.green,
          ),
          title: const Text('Đặt lịch thành công'),
          content: const Text(
            'Lịch hẹn sẽ được lưu vào hệ thống ở bước tiếp theo.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Đồng ý'),
            ),
          ],
        );
      },
    );
  }
}