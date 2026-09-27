import 'package:flutter/material.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import '../services/barber_service.dart';
import 'date_time_selection_screen.dart';

class BarberSelectionScreen extends StatefulWidget {
  final Salon salon;
  final List<HairService> selectedServices;
  final Hairstyle? selectedHairstyle;

  const BarberSelectionScreen({
    super.key,
    required this.salon,
    required this.selectedServices,
    this.selectedHairstyle,
  });

  @override
  State<BarberSelectionScreen> createState() =>
      _BarberSelectionScreenState();
}

class _BarberSelectionScreenState extends State<BarberSelectionScreen> {
  static const _ink = Color(0xFF071426);
  static const _panel = Color(0xFF10233B);
  static const _field = Color(0xFF162D49);
  static const _gold = Color(0xFFF4C567);
  static const _muted = Color(0xFFABB8C9);

  String? _selectedBarberId;
  List<Barber> _barbers = const [];

  void _continue() {
    if (_selectedBarberId == null) return;
    final useAnyBarber = _selectedBarberId == 'any_barber';
    final selectedBarber = useAnyBarber
        ? null
        : _barbers.firstWhere(
            (barber) => barber.id == _selectedBarberId,
          );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DateTimeSelectionScreen(
          salon: widget.salon,
          selectedServices: widget.selectedServices,
          selectedHairstyle: widget.selectedHairstyle,
          selectedBarber: selectedBarber,
          useAnyBarber: useAnyBarber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Chọn nhân viên',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Barber>>(
        stream: BarberService().watchBySalon(widget.salon.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _gold),
            );
          }
          _barbers = snapshot.data!;
          if (_barbers.isEmpty) {
            return const Center(
              child: Text(
                'Chi nhánh hiện chưa có nhân viên.',
                style: TextStyle(color: _muted),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Text(
                widget.salon.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Đã chọn ${widget.selectedServices.length} dịch vụ',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              _anyBarberCard(),
              const SizedBox(height: 18),
              const Text(
                'Đội ngũ tại chi nhánh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 680
                          ? 3
                          : constraints.maxWidth >= 460
                              ? 2
                              : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _barbers.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 1 ? 1.75 : .82,
                    ),
                    itemBuilder: (context, index) {
                      return _barberCard(_barbers[index]);
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFF081A30),
            border: Border(top: BorderSide(color: Color(0x44F4C567))),
          ),
          child: SizedBox(
            height: 51,
            child: FilledButton.icon(
              onPressed:
                  _selectedBarberId == null ? null : _continue,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              icon: const Icon(Icons.schedule_rounded),
              label: const Text(
                'Tiếp tục chọn thời gian',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _anyBarberCard() {
    final selected = _selectedBarberId == 'any_barber';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedBarberId = 'any_barber'),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: _decoration(selected),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: _field,
              foregroundColor: _gold,
              child: Icon(Icons.groups_rounded),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn thợ bất kỳ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Hệ thống sẽ chọn một nhân viên đang trống lịch.',
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _gold : _muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _barberCard(Barber barber) {
    final selected = _selectedBarberId == barber.id;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _selectedBarberId = barber.id),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: _decoration(selected),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: _field,
              backgroundImage: barber.imageUrl?.isNotEmpty == true
                  ? NetworkImage(barber.imageUrl!)
                  : null,
              child: barber.imageUrl?.isNotEmpty == true
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: _gold,
                    ),
            ),
            const SizedBox(height: 11),
            Text(
              barber.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${barber.age} tuổi • ${barber.experienceYears} năm KN',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: _gold, size: 18),
                Text(
                  ' ${barber.rating} (${barber.reviewCount})',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 7),
              const Icon(Icons.check_circle_rounded, color: _gold),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _decoration(bool selected) {
    return BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? _gold : const Color(0x445D7390),
        width: selected ? 2 : 1,
      ),
    );
  }
}

