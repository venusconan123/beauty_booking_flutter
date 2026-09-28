import 'package:flutter/material.dart';

import '../models/salon.dart';
import 'salon_detail_screen.dart';

class BookingBranchSelectionScreen extends StatelessWidget {
  final List<Salon> salons;

  const BookingBranchSelectionScreen({
    super.key,
    required this.salons,
  });

  static const _ink = Color(0xFF08111E);
  static const _surface = Color(0xF2121B28);
  static const _gold = Color(0xFFF0C36A);
  static const _muted = Color(0xFFB8C0CC);

  void _selectSalon(BuildContext context, Salon salon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalonDetailScreen(salon: salon),
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
                _header(context),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
                        children: [
                          const Text(
                            'Chọn chi nhánh thuận tiện',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Chọn một chi nhánh để xem thông tin, dịch vụ, nhân viên và đánh giá.',
                            style: TextStyle(color: _muted, height: 1.45),
                          ),
                          const SizedBox(height: 20),
                          for (final salon in salons) ...[
                            _salonCard(context, salon),
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

  Widget _header(BuildContext context) {
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
                  'Bước 1/4 • Tiếp theo: thông tin chi nhánh',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salonCard(BuildContext context, Salon salon) {
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
            padding: const EdgeInsets.all(17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
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
                      Wrap(
                        spacing: 13,
                        runSpacing: 5,
                        children: [
                          _meta(Icons.star_rounded, '${salon.rating}'),
                          _meta(
                            Icons.location_on_outlined,
                            '${salon.distance} km',
                          ),
                          _meta(
                            Icons.schedule_rounded,
                            '${salon.openingTime}–${salon.closingTime}',
                          ),
                          _meta(Icons.phone_in_talk_rounded, salon.hotline),
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
                  padding: EdgeInsets.only(top: 20),
                  child: Icon(Icons.arrow_forward_rounded, color: _gold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _gold, size: 17),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }
}
