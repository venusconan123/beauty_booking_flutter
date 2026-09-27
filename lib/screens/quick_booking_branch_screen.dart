import 'package:flutter/material.dart';

import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import 'barber_selection_screen.dart';

class QuickBookingBranchScreen extends StatelessWidget {
  final HairService selectedService;
  final Hairstyle? selectedHairstyle;
  final List<Salon> salons;

  const QuickBookingBranchScreen({
    super.key,
    required this.selectedService,
    this.selectedHairstyle,
    required this.salons,
  });

  static const Color _ink = Color(0xFF08111E);
  static const Color _surface = Color(0xF2121B28);
  static const Color _field = Color(0xFF182432);
  static const Color _gold = Color(0xFFF0C36A);
  static const Color _muted = Color(0xFFB8C0CC);

  String _formatPrice(int price) => '${price ~/ 1000}.000đ';

  void _selectSalon(BuildContext context, Salon salon) {
    final HairService serviceAtSalon = salon.services.firstWhere(
      (service) => service.id == selectedService.id,
      orElse: () => selectedService,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BarberSelectionScreen(
          salon: salon,
          selectedServices: <HairService>[serviceAtSalon],
          selectedHairstyle: selectedHairstyle,
        ),
      ),
    );
  }

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
                colors: [Color(0xE608111E), Color(0xFC08111E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 34),
                        children: [
                          _buildSelectedService(),
                          const SizedBox(height: 24),
                          const Text(
                            'Chọn chi nhánh thuận tiện',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Dịch vụ đã được chọn sẵn. Hãy chọn nơi bạn muốn đến.',
                            style: TextStyle(color: _muted, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          for (final salon in salons) ...[
                            _buildSalonCard(context, salon),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 13),
      decoration: const BoxDecoration(
        color: Color(0xD90B1420),
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
            child: const Icon(Icons.storefront_rounded, color: _gold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn chi nhánh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bước 1/3 • Tiếp theo: chọn thợ',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedService() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66F0C36A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0x20F0C36A),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.content_cut_rounded, color: _gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DỊCH VỤ ĐÃ CHỌN',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  selectedService.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${selectedService.durationMinutes} phút • '
                  '${_formatPrice(selectedService.price)}',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF59D38C)),
        ],
      ),
    );
  }

  Widget _buildSalonCard(BuildContext context, Salon salon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _selectSalon(context, salon),
        child: Ink(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x3DF0C36A)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _field,
                    borderRadius: BorderRadius.circular(18),
                    image: const DecorationImage(
                      image: AssetImage(
                        'assets/images/login_barbershop_background.jpg',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: _gold,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${salon.rating}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 13),
                          const Icon(
                            Icons.location_on_outlined,
                            color: _muted,
                            size: 17,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${salon.distance} km',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        salon.address,
                        style: const TextStyle(color: _muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 17),
                  child: Icon(Icons.arrow_forward_rounded, color: _gold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
