import 'package:flutter/material.dart';

import '../models/salon.dart';
import '../services/salon_directions.dart';

class SalonMapInformation extends StatefulWidget {
  const SalonMapInformation({
    super.key,
    required this.salon,
    required this.onDetails,
    this.openDirections = openSalonDirections,
  });

  final Salon salon;
  final VoidCallback onDetails;
  final Future<bool> Function(Uri) openDirections;

  @override
  State<SalonMapInformation> createState() => _SalonMapInformationState();
}

class _SalonMapInformationState extends State<SalonMapInformation> {
  bool _opening = false;
  String? _error;

  Future<void> _showDirections() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await widget.openDirections(salonDirectionsUri(widget.salon));
    } catch (_) {
      // Keep the branch information open so the user can retry.
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!opened) {
        _error =
            'Không thể mở Google Maps. Hãy kiểm tra trình duyệt và thử lại.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final salon = widget.salon;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFE1ECFF),
                  child: Icon(Icons.content_cut, color: Color(0xFF1E3A5F)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    salon.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF1E3A5F),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(salon.address)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 6),
                Text('${salon.rating}'),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final details = FilledButton.icon(
                  onPressed: widget.onDetails,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Xem chi tiết salon'),
                );
                final directions = OutlinedButton.icon(
                  onPressed: _opening ? null : _showDirections,
                  icon: const Icon(Icons.directions_outlined),
                  label: Text(_opening ? 'Đang mở…' : 'Chỉ đường'),
                );
                if (constraints.maxWidth < 440 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [details, const SizedBox(height: 10), directions],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    Expanded(child: directions),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
