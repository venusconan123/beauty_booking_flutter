import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/sample_barbers.dart';
import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import '../services/barber_service.dart';
import 'booking_confirmation_screen.dart';

class DateTimeSelectionScreen extends StatefulWidget {
  final Salon salon;
  final List<HairService> selectedServices;
  final Hairstyle? selectedHairstyle;
  final Barber? selectedBarber;
  final bool useAnyBarber;

  const DateTimeSelectionScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
    this.selectedHairstyle,
    required this.selectedBarber,
    required this.useAnyBarber,
  });

  @override
  State<DateTimeSelectionScreen> createState() {
    return _DateTimeSelectionScreenState();
  }
}

class _DateTimeSelectionScreenState extends State<DateTimeSelectionScreen> {
  static const _ink = Color(0xFF071426);
  static const _panel = Color(0xFF10233B);
  static const _field = Color(0xFF162D49);
  static const _gold = Color(0xFFF4C567);
  static const _muted = Color(0xFFABB8C9);

  late final List<DateTime> _availableDates;

  late final Stream<Map<String, List<DateTime>>> _bookedSlotsStream;

  DateTime? _selectedDate;
  String? _selectedTime;
  late List<Barber> _salonBarbers;

  int get _totalDuration {
    return widget.selectedServices.fold(0, (total, service) {
      return total + service.durationMinutes;
    });
  }

  int get _totalPrice {
    return widget.selectedServices.fold(0, (total, service) {
      return total + service.price;
    });
  }

  List<String> get _availableTimeSlots {
    final int openingTime = _minutesFromClock(widget.salon.openingTime);
    final int closingTime = _minutesFromClock(widget.salon.closingTime);

    final int latestStartTime = closingTime - _totalDuration;

    final List<String> slots = [];

    for (int minutes = openingTime; minutes <= latestStartTime; minutes += 30) {
      final int hour = minutes ~/ 60;
      final int minute = minutes % 60;

      final String formattedTime =
          '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';

      slots.add(formattedTime);
    }

    return slots;
  }

  int _minutesFromClock(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0);
  }

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    _availableDates = List<DateTime>.generate(7, (index) {
      return today.add(Duration(days: index));
    });

    _selectedDate = _availableDates.first;
    _salonBarbers = getBarbersBySalonId(widget.salon.id);
    BarberService().getBySalon(widget.salon.id).then((barbers) {
      if (!mounted) return;
      setState(() => _salonBarbers = barbers);
    });
    _bookedSlotsStream = _createBookedSlotsStream();
  }

  Stream<Map<String, List<DateTime>>> _createBookedSlotsStream() {
    return FirebaseFirestore.instance
        .collection('booking_slots')
        .where('salonId', isEqualTo: widget.salon.id)
        .snapshots()
        .map((snapshot) {
          final Map<String, List<DateTime>> slotsByBarber = {};

          for (final document in snapshot.docs) {
            final Map<String, dynamic> data = document.data();

            final String? barberId = data['barberId'] as String?;

            final Timestamp? slotTimestamp = data['slotAt'] as Timestamp?;

            if (barberId == null || slotTimestamp == null) {
              continue;
            }

            slotsByBarber.putIfAbsent(barberId, () => []);

            slotsByBarber[barberId]!.add(slotTimestamp.toDate());
          }

          return slotsByBarber;
        });
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isSameMinute(DateTime first, DateTime second) {
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

    final DateTime slotTime = _createDateTimeFromTime(time);

    return slotTime.isBefore(DateTime.now());
  }

  bool _barberHasConflict({
    required String barberId,
    required DateTime appointmentStart,
    required Map<String, List<DateTime>> bookedSlotsByBarber,
  }) {
    final List<DateTime> barberBookedSlots =
        bookedSlotsByBarber[barberId] ?? const <DateTime>[];

    final int numberOfSlots = (_totalDuration / 30).ceil();

    for (int index = 0; index < numberOfSlots; index++) {
      final DateTime requiredSlot = appointmentStart.add(
        Duration(minutes: index * 30),
      );

      final bool slotAlreadyBooked = barberBookedSlots.any((bookedSlot) {
        return _isSameMinute(bookedSlot, requiredSlot);
      });

      if (slotAlreadyBooked) {
        return true;
      }
    }

    return false;
  }

  bool _isBookedTime(
    String time,
    Map<String, List<DateTime>> bookedSlotsByBarber,
  ) {
    if (_selectedDate == null) {
      return false;
    }

    final DateTime appointmentStart = _createDateTimeFromTime(time);

    if (widget.useAnyBarber) {
      if (_salonBarbers.isEmpty) {
        return true;
      }

      return _salonBarbers.every((barber) {
        return _barberHasConflict(
          barberId: barber.id,
          appointmentStart: appointmentStart,
          bookedSlotsByBarber: bookedSlotsByBarber,
        );
      });
    }

    final Barber? selectedBarber = widget.selectedBarber;

    if (selectedBarber == null) {
      return true;
    }

    return _barberHasConflict(
      barberId: selectedBarber.id,
      appointmentStart: appointmentStart,
      bookedSlotsByBarber: bookedSlotsByBarber,
    );
  }

  bool _isUnavailableTime(
    String time,
    Map<String, List<DateTime>> bookedSlotsByBarber,
  ) {
    return _isPastTime(time) || _isBookedTime(time, bookedSlotsByBarber);
  }

  String _weekdayName(DateTime date) {
    const List<String> weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return weekdays[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
  }

  void _selectTime(String time, bool isUnavailable) {
    if (isUnavailable) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
  }

  void _continueToConfirmation() {
    if (_selectedDate == null || _selectedTime == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return BookingConfirmationScreen(
            salon: widget.salon,
            selectedServices: widget.selectedServices,
            selectedHairstyle: widget.selectedHairstyle,
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

    return StreamBuilder<Map<String, List<DateTime>>>(
      stream: _bookedSlotsStream,
      builder: (context, snapshot) {
        final Map<String, List<DateTime>> bookedSlotsByBarber =
            snapshot.data ?? <String, List<DateTime>>{};

        final bool selectedTimeUnavailable =
            snapshot.hasError ||
            (_selectedTime != null &&
                _isUnavailableTime(_selectedTime!, bookedSlotsByBarber));

        return Scaffold(
          backgroundColor: _ink,
          body: SafeArea(
            child: Column(
              children: [
                _header(),
                _stepper(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1050;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1500),
                              child: wide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _schedulePanel(
                                            snapshot,
                                            bookedSlotsByBarber,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        SizedBox(
                                          width: 350,
                                          child: _summaryPanel(
                                            barberName,
                                            selectedTimeUnavailable,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _schedulePanel(
                                          snapshot,
                                          bookedSlotsByBarber,
                                        ),
                                        const SizedBox(height: 14),
                                        _summaryPanel(
                                          barberName,
                                          selectedTimeUnavailable,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      height: 67,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF081A30),
        border: Border(bottom: BorderSide(color: Color(0x44F4C567))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.calendar_month_rounded, color: _gold, size: 29),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn ngày và giờ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Bước 4/4 • Hoàn tất lịch hẹn',
                  style: TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper() {
    const steps = [
      (Icons.storefront_rounded, 'Chi nhánh'),
      (Icons.content_cut_rounded, 'Dịch vụ'),
      (Icons.person_rounded, 'Nhân viên'),
      (Icons.schedule_rounded, 'Ngày giờ'),
    ];
    return SizedBox(
      height: 68,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == steps.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? _gold : _field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? _gold : const Color(0x445D7390),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  active ? steps[index].$1 : Icons.check_circle_rounded,
                  size: 18,
                  color: active ? _ink : _gold,
                ),
                const SizedBox(width: 7),
                Text(
                  steps[index].$2,
                  style: TextStyle(
                    color: active ? _ink : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _schedulePanel(
    AsyncSnapshot<Map<String, List<DateTime>>> snapshot,
    Map<String, List<DateTime>> bookedSlotsByBarber,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.calendar_today_rounded,
            title: 'Chọn ngày',
            subtitle: 'Chọn ngày phù hợp với lịch của bạn',
          ),
          const SizedBox(height: 15),
          _datePicker(),
          if (_selectedDate != null) ...[
            const SizedBox(height: 10),
            Text(
              'Ngày đã chọn: ${_formatDate(_selectedDate!)}',
              style: const TextStyle(color: _muted),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 19),
            child: Divider(color: Color(0x445D7390)),
          ),
          const _SectionTitle(
            icon: Icons.schedule_rounded,
            title: 'Chọn giờ',
            subtitle: 'Giờ màu xám là thời gian nhân viên đã bận',
          ),
          const SizedBox(height: 15),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _gold),
              ),
            )
          else if (snapshot.hasError)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x22FF5252),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'Không thể tải lịch bận. Vui lòng kiểm tra kết nối.',
                style: TextStyle(color: Colors.redAccent),
              ),
            )
          else
            _buildTimeGroups(bookedSlotsByBarber),
        ],
      ),
    );
  }

  Widget _datePicker() {
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _availableDates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final selected =
              _selectedDate != null && _isSameDate(_selectedDate!, date);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 100,
              decoration: BoxDecoration(
                color: selected ? _gold : _field,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _gold : const Color(0x445D7390),
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x44F4C567),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayName(date),
                    style: TextStyle(color: selected ? _ink : _muted),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: selected ? _ink : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeGroups(
    Map<String, List<DateTime>> bookedSlotsByBarber,
  ) {
    final morning = <String>[];
    final afternoon = <String>[];
    final evening = <String>[];
    for (final time in _availableTimeSlots) {
      final minutes = _minutesFromClock(time);
      if (minutes < 12 * 60 + 30) {
        morning.add(time);
      } else if (minutes < 17 * 60 + 30) {
        afternoon.add(time);
      } else {
        evening.add(time);
      }
    }
    final suggested = _availableTimeSlots.cast<String?>().firstWhere(
          (time) =>
              time != null &&
              !_isUnavailableTime(time, bookedSlotsByBarber),
          orElse: () => null,
        );
    return Column(
      children: [
        _timeGroup(
          icon: Icons.wb_sunny_rounded,
          title: 'Buổi sáng',
          range: '07:00 – 12:00',
          times: morning,
          suggestedTime: suggested,
          bookedSlotsByBarber: bookedSlotsByBarber,
        ),
        const SizedBox(height: 12),
        _timeGroup(
          icon: Icons.wb_twilight_rounded,
          title: 'Buổi chiều',
          range: '12:30 – 17:00',
          times: afternoon,
          suggestedTime: suggested,
          bookedSlotsByBarber: bookedSlotsByBarber,
        ),
        if (evening.isNotEmpty) ...[
          const SizedBox(height: 12),
          _timeGroup(
            icon: Icons.nightlight_round,
            title: 'Buổi tối',
            range: '17:30 – ${widget.salon.closingTime}',
            times: evening,
            suggestedTime: suggested,
            bookedSlotsByBarber: bookedSlotsByBarber,
          ),
        ],
      ],
    );
  }

  Widget _timeGroup({
    required IconData icon,
    required String title,
    required String range,
    required List<String> times,
    required String? suggestedTime,
    required Map<String, List<DateTime>> bookedSlotsByBarber,
  }) {
    if (times.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? 6
            : constraints.maxWidth >= 560
                ? 4
                : 3;
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xAA0B1D32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x335D7390)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: _gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(range, style: const TextStyle(color: _muted)),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: times.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: 2.25,
                ),
                itemBuilder: (context, index) {
                  final time = times[index];
                  final selected = _selectedTime == time;
                  final unavailable = _isUnavailableTime(
                    time,
                    bookedSlotsByBarber,
                  );
                  final suggested = time == suggestedTime;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectTime(time, unavailable),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: unavailable
                            ? const Color(0xFF263647)
                            : selected
                                ? _gold
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? _gold
                              : suggested && !unavailable
                                  ? _gold
                                  : const Color(0x66798AA0),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (unavailable)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.lock_rounded,
                                color: _muted,
                                size: 14,
                              ),
                            )
                          else if (suggested)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                color: _gold,
                                size: 15,
                              ),
                            ),
                          Text(
                            time,
                            style: TextStyle(
                              color: unavailable
                                  ? _muted
                                  : selected
                                      ? _ink
                                      : Colors.white,
                              fontWeight: FontWeight.w800,
                              decoration: unavailable
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryPanel(String barberName, bool selectedTimeUnavailable) {
    final services = widget.selectedServices.map((service) => service.name).join(', ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_rounded, color: _gold),
              SizedBox(width: 9),
              Text(
                'Thông tin đặt lịch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _summaryRow(Icons.storefront_rounded, 'Chi nhánh', widget.salon.name),
          _summaryRow(Icons.person_rounded, 'Nhân viên', barberName),
          _summaryRow(Icons.content_cut_rounded, 'Dịch vụ', services),
          _summaryRow(
            Icons.timelapse_rounded,
            'Thời gian dịch vụ',
            '$_totalDuration phút',
          ),
          _summaryRow(
            Icons.calendar_month_rounded,
            'Ngày hẹn',
            _selectedDate == null ? 'Chưa chọn' : _formatDate(_selectedDate!),
          ),
          _summaryRow(
            Icons.schedule_rounded,
            'Giờ hẹn',
            _selectedTime ?? 'Chưa chọn',
          ),
          const Divider(color: Color(0x445D7390), height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tổng giá dịch vụ',
                  style: TextStyle(color: _muted),
                ),
              ),
              Text(
                _formatPrice(_totalPrice),
                style: const TextStyle(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _selectedTime == null || selectedTimeUnavailable
                  ? null
                  : _continueToConfirmation,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
                disabledBackgroundColor: const Color(0xFF263647),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text(
                'Tiếp tục xác nhận',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _gold, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x445D7390)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _DateTimeSelectionScreenState._gold, size: 25),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _DateTimeSelectionScreenState._muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
