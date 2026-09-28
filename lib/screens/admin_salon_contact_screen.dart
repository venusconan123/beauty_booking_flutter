import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../services/salon_contact_service.dart';

class AdminSalonContactScreen extends StatefulWidget {
  const AdminSalonContactScreen({super.key});

  @override
  State<AdminSalonContactScreen> createState() =>
      _AdminSalonContactScreenState();
}

class _AdminSalonContactScreenState extends State<AdminSalonContactScreen> {
  static const _ink = Color(0xFF071426);
  static const _panel = Color(0xFF10233B);
  static const _field = Color(0xFF162D49);
  static const _gold = Color(0xFFF4C567);
  static const _muted = Color(0xFFABB8C9);

  final SalonContactService _service = SalonContactService();
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final salon in sampleSalons) {
      _controllers[salon.id] = TextEditingController(text: salon.hotline);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final hotlines = await _service.getHotlines();
      for (final salon in sampleSalons) {
        _controllers[salon.id]!.text = hotlines[salon.id] ?? salon.hotline;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải hotline: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _save() async {
    final values = <String, String>{};
    for (final salon in sampleSalons) {
      final value = _controllers[salon.id]!.text.trim();
      final digits = _digits(value);
      if (!RegExp(r'^0[0-9]{9}$').hasMatch(digits)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hotline của ${salon.name} phải gồm 10 số và bắt đầu bằng 0.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      values[salon.id] = digits;
    }

    setState(() => _saving = true);
    try {
      await _service.saveHotlines(values);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hotline của 3 chi nhánh.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật hotline: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF081A30),
        foregroundColor: Colors.white,
        title: const Text('Quản lý hotline'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text(
                      'Hotline từng chi nhánh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Số mới sẽ hiển thị ngay ở trang chi nhánh và luồng đặt lịch.',
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    for (final salon in sampleSalons) ...[
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x44F4C567)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              salon.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              salon.address,
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 13),
                            TextField(
                              controller: _controllers[salon.id],
                              keyboardType: TextInputType.phone,
                              enabled: !_saving,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Số hotline',
                                labelStyle: const TextStyle(color: _gold),
                                prefixIcon: const Icon(
                                  Icons.phone_in_talk_rounded,
                                  color: _gold,
                                ),
                                filled: true,
                                fillColor: _field,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                    ],
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _ink,
                        ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _ink,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving ? 'Đang lưu...' : 'Lưu hotline',
                          style: const TextStyle(fontWeight: FontWeight.w900),
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
