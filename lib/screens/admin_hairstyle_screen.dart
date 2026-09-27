import 'package:flutter/material.dart';

import '../models/hairstyle.dart';
import '../services/hairstyle_service.dart';
import 'hairstyle_form_screen.dart';

class AdminHairstyleScreen extends StatefulWidget {
  const AdminHairstyleScreen({super.key});

  @override
  State<AdminHairstyleScreen> createState() => _AdminHairstyleScreenState();
}

class _AdminHairstyleScreenState extends State<AdminHairstyleScreen> {
  static const Color _ink = Color(0xFF090E14);
  static const Color _cream = Color(0xFFF5EFE5);
  static const Color _gold = Color(0xFFF0C36A);

  final _service = HairstyleService();
  bool _seeding = false;

  Future<void> _openForm([Hairstyle? hairstyle]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HairstyleFormScreen(hairstyle: hairstyle),
      ),
    );
  }

  Future<void> _seedDefaults() async {
    setState(() => _seeding = true);
    try {
      await _service.seedDefaults();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo 6 mẫu tóc ban đầu.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tạo dữ liệu mẫu: $error')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _confirmDelete(Hairstyle hairstyle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa mẫu tóc?'),
        content: Text(
          'Ảnh “${hairstyle.name}” sẽ bị xóa khỏi thư viện và không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(hairstyle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa mẫu tóc.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa mẫu tóc: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'QUẢN LÝ MẪU TÓC',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: _ink,
        onPressed: _openForm,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('THÊM MẪU', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<List<Hairstyle>>(
        stream: _service.watchHairstyles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              title: 'Không tải được dữ liệu',
              message: '${snapshot.error}',
            );
          }

          final hairstyles = snapshot.data ?? const <Hairstyle>[];
          if (hairstyles.isEmpty) return _buildEmptyState();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BỘ SƯU TẬP CỦA SALON',
                              style: TextStyle(
                                color: Color(0xFF9B6B24),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Thêm, sửa hoặc xóa mẫu tóc',
                              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${hairstyles.length} mẫu',
                        style: const TextStyle(
                          color: Color(0xFF9B6B24),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 430,
                    mainAxisExtent: 354,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final hairstyle = hairstyles[index];
                      return _AdminStyleCard(
                        hairstyle: hairstyle,
                        onEdit: () => _openForm(hairstyle),
                        onDelete: () => _confirmDelete(hairstyle),
                      );
                    },
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

  Widget _buildEmptyState() {
    return _MessageState(
      icon: Icons.photo_library_outlined,
      title: 'Chưa có mẫu tóc được quản lý',
      message:
          'Tạo nhanh bộ 6 ảnh mẫu có sẵn, sau đó admin có thể sửa hoặc xóa từng mẫu.',
      action: FilledButton.icon(
        onPressed: _seeding ? null : _seedDefaults,
        icon: _seeding
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(_seeding ? 'ĐANG TẠO...' : 'TẠO 6 ẢNH MẪU'),
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _ink,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _AdminStyleCard extends StatelessWidget {
  const _AdminStyleCard({
    required this.hairstyle,
    required this.onEdit,
    required this.onDelete,
  });

  final Hairstyle hairstyle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  hairstyle.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF202A35),
                    child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hairstyle.isActive
                          ? const Color(0xE61B5E3A)
                          : const Color(0xE65B6470),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hairstyle.isActive ? 'Đang hiển thị' : 'Đang ẩn',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hairstyle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hairstyle.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF66707C), height: 1.25),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sửa mẫu tóc',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Xóa mẫu tóc',
                  color: Colors.red.shade700,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 66, color: const Color(0xFF9B6B24)),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF66707C), height: 1.5),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}
