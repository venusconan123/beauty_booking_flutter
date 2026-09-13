import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';
import 'booking_confirmation_screen.dart';

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
  late final Stream<List<DateTime>> _bookedSlotsStream;

  DateTime? _selectedDate;
  String? _selectedTime;

  int get _totalDuration {
    return widget.selectedServices.fold(
      0,
      (total, service) {
        return total + service.durationMinutes;
      },
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

    _availableDates = List<DateTime>.generate(
      7,
      (index) {
        return today.add(
          Duration(days: index),
        );
      },
    );

    _selectedDate = _availableDates.first;

    _bookedSlotsStream = _createBookedSlotsStream();
  }

  Stream<List<DateTime>> _createBookedSlotsStream() {
    if (widget.useAnyBarber ||
        widget.selectedBarber == null) {
      return Stream<List<DateTime>>.value(
        const <DateTime>[],
      );
    }

    return FirebaseFirestore.instance
        .collection('booking_slots')
        .where(
          'barberId',
          isEqualTo: widget.selectedBarber!.id,
        )
        .snapshots()
        .map(
      (snapshot) {
        final List<DateTime> bookedSlots = [];

        for (final document in snapshot.docs) {
          final Map<String, dynamic> data =
              document.data();

          if (data['salonId'] != widget.salon.id) {
            continue;
          }

          final Timestamp? slotTimestamp =
              data['slotAt'] as Timestamp?;

          if (slotTimestamp != null) {
            bookedSlots.add(
              slotTimestamp.toDate(),
            );
          }
        }

        return bookedSlots;
      },
    );
  }

  bool _isSameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isSameMinute(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day &&
        first.hour == second.hour &&
        first.minute == second.minute;
  }

  DateTime _createDateTimeFromTime(String time) {
    final List<String> parts = time.split(':');

    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);

    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      hour,
      minute,
    );
  }

  bool _isPastTime(String time) {
    if (_selectedDate == null) {
      return false;
    }

    final DateTime slotTime =
        _createDateTimeFromTime(time);

    return slotTime.isBefore(DateTime.now());
  }

  bool _isBookedTime(
    String time,
    List<DateTime> bookedSlots,
  ) {
    if (_selectedDate == null ||
        widget.useAnyBarber ||
        widget.selectedBarber == null) {
      return false;
    }

    final DateTime appointmentStart =
        _createDateTimeFromTime(time);

    final int numberOfSlots =
        (_totalDuration / 30).ceil();

    for (int index = 0;
        index < numberOfSlots;
        index++) {
      final DateTime requiredSlot =
          appointmentStart.add(
        Duration(minutes: index * 30),
      );

      final bool slotAlreadyBooked =
          bookedSlots.any(
        (bookedSlot) {
          return _isSameMinute(
            bookedSlot,
            requiredSlot,
          );
        },
      );

      if (slotAlreadyBooked) {
        return true;
      }
    }

    return false;
  }

  bool _isUnavailableTime(
    String time,
    List<DateTime> bookedSlots,
  ) {
    return _isPastTime(time) ||
        _isBookedTime(time, bookedSlots);
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

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
  }

  void _selectTime(
    String time,
    bool isUnavailable,
  ) {
    if (isUnavailable) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
  }

  void _continueToConfirmation() {
    if (_selectedDate == null ||
        _selectedTime == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return BookingConfirmationScreen(
            salon: widget.salon,
            selectedServices: widget.selectedServices,
            selectedBarber: widget.selectedBarber,
            useAnyBarber: widget.useAnyBarber,
            selectedDate: _selectedDate!,
            selectedTime: _selectedTime!,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String barberName = widget.useAnyBarber
        ? 'Thợ bất kỳ'
        : widget.selectedBarber?.name ?? 'Chưa chọn thợ';

    return StreamBuilder<List<DateTime>>(
      stream: _bookedSlotsStream,
      builder: (context, snapshot) {
        final List<DateTime> bookedSlots =
            snapshot.data ?? const <DateTime>[];

        final bool selectedTimeUnavailable =
            _selectedTime != null &&
                _isUnavailableTime(
                  _selectedTime!,
                  bookedSlots,
                );

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
              const SizedBox(height: 6),
              Text(
                'Thợ: $barberName',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Thời gian dịch vụ: $_totalDuration phút',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
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
                            _isSameDate(
                              _selectedDate!,
                              date,
                            );

                    return InkWell(
                      borderRadius:
                          BorderRadius.circular(12),
                      onTap: () {
                        _selectDate(date);
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
              if (_selectedDate != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Ngày đã chọn: '
                  '${_formatDate(_selectedDate!)}',
                ),
              ],
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
                widget.useAnyBarber
                    ? 'Hệ thống sẽ sắp xếp một thợ còn trống.'
                    : 'Các giờ màu xám là thời gian thợ đã bận.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !widget.useAnyBarber)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Card(
                  color: Colors.red.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Không thể tải lịch bận của thợ. '
                      'Vui lòng kiểm tra kết nối.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                _buildTimeSlots(bookedSlots),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _buildLegend(
                    color: const Color(0xFF1E3A5F),
                    label: 'Đang chọn',
                  ),
                  _buildLegend(
                    color: Colors.grey.shade300,
                    label: 'Không khả dụng',
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _selectedTime == null ||
                          selectedTimeUnavailable
                      ? null
                      : _continueToConfirmation,
                  child: const Text(
                    'Tiếp tục xác nhận',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeSlots(
    List<DateTime> bookedSlots,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columnCount = 3;

        if (constraints.maxWidth >= 900) {
          columnCount = 6;
        } else if (constraints.maxWidth >= 600) {
          columnCount = 5;
        } else if (constraints.maxWidth >= 400) {
          columnCount = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableTimeSlots.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) {
            final String time =
                _availableTimeSlots[index];

            final bool isSelected =
                _selectedTime == time;

            final bool isUnavailable =
                _isUnavailableTime(
              time,
              bookedSlots,
            );

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                _selectTime(
                  time,
                  isUnavailable,
                );
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isUnavailable
                      ? Colors.grey.shade200
                      : isSelected
                          ? const Color(0xFF1E3A5F)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1E3A5F)
                        : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    color: isUnavailable
                        ? Colors.grey
                        : isSelected
                            ? Colors.white
                            : Colors.black,
                    fontWeight: FontWeight.w600,
                    decoration: isUnavailable
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegend({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}