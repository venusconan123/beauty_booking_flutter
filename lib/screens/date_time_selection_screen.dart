import 'package:flutter/material.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';

class DateTimeSelectionScreen extends StatefulWidget {
  final Salon salon;
  final List<HairService> selectedServices;
  final Barber? selectedBarber;
  final bool useAnyBarber;

  const DateTimeSelectionScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
    required this.selectedBarber,
    required this.useAnyBarber,
  });

  @override
  State<DateTimeSelectionScreen> createState() {
    return _DateTimeSelectionScreenState();
  }
}

class _DateTimeSelectionScreenState
    extends State<DateTimeSelectionScreen> {
  late final List<DateTime> _availableDates;

  DateTime? _selectedDate;
  String? _selectedTime;

  int get _totalDuration {
    return widget.selectedServices.fold(
      0,
      (total, service) => total + service.durationMinutes,
    );
  }

  List<String> get _availableTimeSlots {
    const int openingTime = 8 * 60;
    const int closingTime = 20 * 60;

    final int latestStartTime =
        closingTime - _totalDuration;

    final List<String> slots = [];

    for (
      int minutes = openingTime;
      minutes <= latestStartTime;
      minutes += 30
    ) {
      final int hour = minutes ~/ 60;
      final int minute = minutes % 60;

      final String formattedTime =
          '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';

      slots.add(formattedTime);
    }

    return slots;
  }

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _availableDates = List.generate(
      7,
      (index) => today.add(
        Duration(days: index),
      ),
    );

    _selectedDate = _availableDates.first;
  }

  bool _isSameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isPastTime(String time) {
    if (_selectedDate == null) {
      return false;
    }

    final DateTime now = DateTime.now();

    if (!_isSameDate(_selectedDate!, now)) {
      return false;
    }

    final List<String> parts = time.split(':');

    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);

    final DateTime slotTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    return slotTime.isBefore(now);
  }

  bool _isDemoBookedTime(String time) {
    if (_selectedDate == null) {
      return false;
    }

    final DateTime today = DateTime.now();

    if (!_isSameDate(_selectedDate!, today)) {
      return false;
    }

    const Set<String> bookedTimes = {
      '09:00',
      '14:30',
    };

    return bookedTimes.contains(time);
  }

  String _weekdayName(DateTime date) {
    const List<String> weekdays = [
      'T2',
      'T3',
      'T4',
      'T5',
      'T6',
      'T7',
      'CN',
    ];

    return weekdays[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    final String day =
        date.day.toString().padLeft(2, '0');

    final String month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final String barberName = widget.useAnyBarber
        ? 'Thợ bất kỳ'
        : widget.selectedBarber?.name ?? 'Chưa chọn thợ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn ngày và giờ'),
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Thợ: $barberName'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule),
              const SizedBox(width: 8),
              Text(
                'Thời lượng dịch vụ: $_totalDuration phút',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Chọn ngày',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableDates.length,
              separatorBuilder: (context, index) {
                return const SizedBox(width: 10);
              },
              itemBuilder: (context, index) {
                final DateTime date =
                    _availableDates[index];

                final bool isSelected =
                    _selectedDate != null &&
                    _isSameDate(_selectedDate!, date);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTime = null;
                    });
                  },
                  child: Container(
                    width: 76,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1E3A5F)
                          : Colors.grey.shade100,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdayName(date),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${date.day.toString().padLeft(2, '0')}/'
                          '${date.month.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Chọn giờ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Giờ làm việc: 08:00–20:00',
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _availableTimeSlots.map((time) {
              final bool isUnavailable =
                  _isPastTime(time) ||
                  _isDemoBookedTime(time);

              return ChoiceChip(
                label: Text(time),
                selected: _selectedTime == time,
                onSelected: isUnavailable
                    ? null
                    : (selected) {
                        setState(() {
                          _selectedTime =
                              selected ? time : null;
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Khung giờ màu xám đã qua hoặc không khả dụng.',
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _selectedTime == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã chọn '
                            '${_formatDate(_selectedDate!)} '
                            'lúc $_selectedTime',
                          ),
                        ),
                      );
                    },
              child: const Text(
                'Tiếp tục xác nhận',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}