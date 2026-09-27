import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../services/hairstyle_service.dart';
import 'quick_booking_branch_screen.dart';

class HairstyleGalleryScreen extends StatelessWidget {
  const HairstyleGalleryScreen({super.key});

  static const Color _ink = Color(0xFF090E14);
  static const Color _panel = Color(0xFF111923);
  static const Color _cream = Color(0xFFF5EFE5);
  static const Color _gold = Color(0xFFF0C36A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'THƯ VIỆN KIỂU TÓC',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
      ),
      body: StreamBuilder<List<Hairstyle>>(
        stream: HairstyleService().watchHairstyles(activeOnly: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }

          final hairstyles = snapshot.data?.isNotEmpty == true
              ? snapshot.data!
              : defaultHairstyles;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildIntro(hairstyles.length)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 410,
                    mainAxisExtent: 330,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _StyleCard(
                      hairstyle: hairstyles[index],
                      onTap: () => _showDetails(context, hairstyles[index]),
                    ),
                    childCount: hairstyles.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntro(int total) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TÌM DIỆN MẠO CỦA BẠN',
                      style: TextStyle(
                        color: Color(0xFF9B6B24),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Mẫu tóc thịnh hành',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Chọn một mẫu để xem chi tiết và đặt lịch với stylist.',
                      style: TextStyle(color: Color(0xFF66707C), height: 1.4),
                    ),
                  ],
                ),
              ),
              Text(
                '$total mẫu',
                style: const TextStyle(
                  color: Color(0xFF9B6B24),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Hairstyle hairstyle) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _hairstyleImage(hairstyle),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hairstyle.name,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hairstyle.description,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: sampleSalons.isEmpty
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => QuickBookingBranchScreen(
                                selectedService: hairStyling,
                                selectedHairstyle: hairstyle,
                                salons: sampleSalons,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('ĐẶT LỊCH VỚI KIỂU TÓC NÀY'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.hairstyle, required this.onTap});

  final Hairstyle hairstyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF111923),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 20,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _hairstyleImage(hairstyle),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xF2090E14)],
                      stops: [.42, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hairstyle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFF5E4),
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hairstyle.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _hairstyleImage(Hairstyle hairstyle) {
  if (hairstyle.imageUrl.isNotEmpty) {
    return Image.network(
      hairstyle.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF202A35),
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
  return Image.asset(hairstyle.assetPath, fit: BoxFit.cover);
}
