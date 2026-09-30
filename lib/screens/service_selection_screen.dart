import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hair_service.dart';
import '../models/salon.dart';
import '../services/hair_service_catalog.dart';
import 'barber_selection_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  final Salon salon;

  const ServiceSelectionScreen({super.key, required this.salon});

  @override
  State<ServiceSelectionScreen> createState() =>
      _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xF2121B28);
  static const _field = Color(0xFF182432);
  static const _gold = Color(0xFFF0C36A);
  static const _muted = Color(0xFFB8C0CC);

  final Set<String> _selectedServiceIds = {};
  final HairServiceCatalog _catalog = HairServiceCatalog();
  StreamSubscription<List<HairService>>? _serviceSubscription;
  late List<HairService> _availableServices;

  @override
  void initState() {
    super.initState();
    _availableServices = widget.salon.services;
    _serviceSubscription = _catalog.watchActive().listen((services) {
      if (!mounted) return;
      setState(() {
        _availableServices = services;
        final availableIds = services.map((service) => service.id).toSet();
        _selectedServiceIds.removeWhere((id) => !availableIds.contains(id));
      });
    });
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  List<HairService> get _selectedServices => _availableServices
      .where((service) => _selectedServiceIds.contains(service.id))
      .toList();

  int get _totalPrice => _selectedServices.fold(
        0,
        (total, service) => total + service.price,
      );

  int get _totalDuration => _selectedServices.fold(
        0,
        (total, service) => total + service.durationMinutes,
      );

  void _toggleService(String serviceId) {
    setState(() {
      if (!_selectedServiceIds.add(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      }
    });
  }

  void _continue() {
    if (_selectedServices.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BarberSelectionScreen(
          salon: widget.salon,
          selectedServices: _selectedServices,
        ),
      ),
    );
  }

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_barbershop_background.jpg',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xEE08111E), Color(0xFF08111E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(child: _content()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 13),
      decoration: const BoxDecoration(
        color: Color(0xF20B1420),
        border: Border(bottom: BorderSide(color: Color(0x33F0C36A))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0x1FF0C36A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66F0C36A)),
            ),
            child: const Icon(Icons.content_cut_rounded, color: _gold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn dịch vụ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bước 2/4 • Có thể chọn nhiều dịch vụ',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
          children: [
            _salonSummary(),
            const SizedBox(height: 24),
            const Text(
              'Dịch vụ dành cho bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chạm vào dịch vụ để thêm hoặc bỏ khỏi lịch hẹn.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 17),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 820 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availableServices.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: columns == 1 ? 2.85 : 2.45,
                  ),
                  itemBuilder: (context, index) {
                    return _serviceCard(_availableServices[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _salonSummary() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66F0C36A)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0x1FF0C36A),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.storefront_rounded, color: _gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHI NHÁNH ĐÃ CHỌN',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.salon.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.salon.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, height: 1.35),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đổi'),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(HairService service) {
    final selected = _selectedServiceIds.contains(service.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleService(service.id),
        borderRadius: BorderRadius.circular(21),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1D3047) : _surface,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: selected ? _gold : const Color(0x3DF0C36A),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x29F0C36A),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: selected ? const Color(0x2FF0C36A) : _field,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _serviceIcon(service.id),
                  color: _gold,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${service.durationMinutes} phút • '
                      '${_formatPrice(service.price)}',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: selected ? _gold : _muted,
                size: 27,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _serviceIcon(String id) {
    if (id.contains('combo')) return Icons.workspace_premium_rounded;
    if (id.contains('wash')) return Icons.shower_rounded;
    if (id.contains('perm')) return Icons.waves_rounded;
    if (id.contains('dye')) return Icons.colorize_rounded;
    if (id.contains('care')) return Icons.spa_rounded;
    if (id.contains('styling')) return Icons.auto_awesome_rounded;
    return Icons.content_cut_rounded;
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: Color(0xFF0B1420),
          border: Border(top: BorderSide(color: Color(0x44F0C36A))),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1088),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final summary = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedServiceIds.length} dịch vụ • '
                      '$_totalDuration phút',
                      style: const TextStyle(color: _muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(_totalPrice),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
                final button = SizedBox(
                  height: 52,
                  width: compact ? double.infinity : 270,
                  child: FilledButton.icon(
                    onPressed: _selectedServiceIds.isEmpty ? null : _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      disabledBackgroundColor: const Color(0xFF263342),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Tiếp tục chọn nhân viên',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                );
                if (compact) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summary,
                      const SizedBox(height: 9),
                      button,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
