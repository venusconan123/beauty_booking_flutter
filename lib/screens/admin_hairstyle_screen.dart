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
  bool _defaultsReady = false;
  String? _seedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedDefaults(showSuccess: false);
    });
  }

  Future<void> _openForm([Hairstyle? hairstyle]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HairstyleFormScreen(hairstyle: hairstyle),
      ),
    );
  }

  Future<void> _seedDefaults({bool showSuccess = true}) async {
    setState(() => _seeding = true);
    try {
      await _service.ensureDefaults();
      if (!mounted) return;
      setState(() {
        _seedError = null;
        _defaultsReady = true;
      });
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đồng bộ 6 mẫu tóc ban đầu.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _seedError = error.toString());
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đồng bộ dữ liệu mẫu: $error')),
        );
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa mẫu tóc.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa mẫu tóc: $error')));
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
        label: const Text(
          'THÊM MẪU',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<List<Hairstyle>>(
        stream: _service.watchHairstyles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildDefaultPreview(
              notice:
                  'Cần triển khai Firestore Rules để bật quyền sửa và xóa. '
                  '${snapshot.error}',
            );
          }

          final hairstyles = snapshot.data ?? const <Hairstyle>[];
          if (hairstyles.isEmpty) {
            if (_defaultsReady) return _buildManagedEmptyState();
            return _buildDefaultPreview(
              notice: _seeding
                  ? 'Đang đồng bộ 6 mẫu tóc vào hệ thống quản lý...'
                  : _seedError,
            );
          }

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
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
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
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final hairstyle = hairstyles[index];
                    return _AdminStyleCard(
                      hairstyle: hairstyle,
                      onEdit: () => _openForm(hairstyle),
                      onDelete: () => _confirmDelete(hairstyle),
                    );
                  }, childCount: hairstyles.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultPreview({String? notice}) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x66B7791F)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF9B6B24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(notice)),
                        TextButton(
                          onPressed: _seeding
                              ? null
                              : () => _seedDefaults(showSuccess: true),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  '6 MẪU TÓC CÓ SẴN',
                  style: TextStyle(
                    color: Color(0xFF9B6B24),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Bộ sưu tập mặc định của salon',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
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
              mainAxisExtent: 330,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _DefaultStyleCard(hairstyle: defaultHairstyles[index]),
              childCount: defaultHairstyles.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagedEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 66,
              color: Color(0xFF9B6B24),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thư viện mẫu tóc đang trống',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bấm “Thêm mẫu” để tải một ảnh kiểu tóc mới.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF66707C)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('THÊM MẪU TÓC'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
            ),
          ],
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
                _managedImage(hairstyle),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hairstyle.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF66707C),
                          height: 1.25,
                        ),
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

class _DefaultStyleCard extends StatelessWidget {
  const _DefaultStyleCard({required this.hairstyle});

  final Hairstyle hairstyle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(hairstyle.assetPath, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xEE090E14)],
                stops: [.42, 1],
              ),
            ),
          ),
          const Positioned(
            top: 12,
            left: 12,
            child: Chip(
              avatar: Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text('Mẫu có sẵn'),
            ),
          ),
          Positioned(
            left: 17,
            right: 17,
            bottom: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hairstyle.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hairstyle.description,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _managedImage(Hairstyle hairstyle) {
  if (hairstyle.imageUrl.isNotEmpty) {
    return Image.network(
      hairstyle.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF202A35),
        child: Icon(Icons.broken_image_outlined, color: Colors.white54),
      ),
    );
  }
  if (hairstyle.assetPath.isNotEmpty) {
    return Image.asset(hairstyle.assetPath, fit: BoxFit.cover);
  }
  return const ColoredBox(
    color: Color(0xFF202A35),
    child: Icon(Icons.image_not_supported_outlined, color: Colors.white54),
  );
}
