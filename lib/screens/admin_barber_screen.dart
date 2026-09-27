import 'package:flutter/material.dart';

import '../data/sample_salons.dart';
import '../models/barber.dart';
import '../services/barber_service.dart';

class AdminBarberScreen extends StatefulWidget {
  const AdminBarberScreen({super.key});

  @override
  State<AdminBarberScreen> createState() => _AdminBarberScreenState();
}

class _AdminBarberScreenState extends State<AdminBarberScreen> {
  static const _ink = Color(0xFF071426);
  static const _panel = Color(0xFF10233B);
  static const _field = Color(0xFF162D49);
  static const _gold = Color(0xFFF4C567);
  static const _muted = Color(0xFFABB8C9);

  final BarberService _service = BarberService();
  String _selectedSalonId = sampleSalons.first.id;
  bool _initializing = true;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _service.ensureDefaults();
    } catch (error) {
      _initializationError = '$error';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _openForm([Barber? barber]) async {
    final name = TextEditingController(text: barber?.name ?? '');
    final age = TextEditingController(text: '${barber?.age ?? 25}');
    final experience =
        TextEditingController(text: '${barber?.experienceYears ?? 1}');
    final rating = TextEditingController(text: '${barber?.rating ?? 5}');
    final reviewCount =
        TextEditingController(text: '${barber?.reviewCount ?? 0}');
    final imageUrl = TextEditingController(text: barber?.imageUrl ?? '');
    final skills = TextEditingController(
      text: barber?.skills.join(', ') ?? 'Cắt tóc, Tạo kiểu',
    );
    final bio = TextEditingController(text: barber?.bio ?? '');
    String salonId = barber?.salonId ?? _selectedSalonId;
    String gender = barber?.gender ?? 'Nam';
    bool isActive = barber?.isActive ?? true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          title: Text(
            barber == null ? 'Thêm nhân viên' : 'Chỉnh sửa nhân viên',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 540,
              child: Column(
                children: [
                  _input(name, 'Họ và tên', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: salonId,
                    dropdownColor: _field,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration(
                      'Chi nhánh',
                      Icons.storefront_rounded,
                    ),
                    items: sampleSalons
                        .map(
                          (salon) => DropdownMenuItem(
                            value: salon.id,
                            child: Text(salon.name),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(
                            () => salonId = value ?? salonId,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          age,
                          'Tuổi',
                          Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: gender,
                          dropdownColor: _field,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration(
                            'Giới tính',
                            Icons.person_outline,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                            DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                            DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                          ],
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(
                                  () => gender = value ?? gender,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          experience,
                          'Năm kinh nghiệm',
                          Icons.workspace_premium_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _input(
                          rating,
                          'Điểm đánh giá',
                          Icons.star_outline_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _input(
                    reviewCount,
                    'Số lượt đánh giá',
                    Icons.reviews_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    skills,
                    'Chuyên môn (ngăn cách bằng dấu phẩy)',
                    Icons.auto_awesome_outlined,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    imageUrl,
                    'Đường dẫn ảnh đại diện',
                    Icons.image_outlined,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    bio,
                    'Giới thiệu',
                    Icons.notes_rounded,
                    maxLines: 4,
                  ),
                  SwitchListTile.adaptive(
                    value: isActive,
                    activeTrackColor: _gold,
                    title: const Text(
                      'Đang làm việc',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Tắt để ẩn nhân viên khỏi phía khách hàng.',
                      style: TextStyle(color: _muted),
                    ),
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(
                            () => isActive = value,
                          ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy', style: TextStyle(color: _muted)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập tên nhân viên.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final value = Barber(
                        id: barber?.id ?? '',
                        salonId: salonId,
                        name: name.text.trim(),
                        age: int.tryParse(age.text) ?? 25,
                        gender: gender,
                        experienceYears: int.tryParse(experience.text) ?? 0,
                        rating: double.tryParse(rating.text) ?? 5,
                        reviewCount: int.tryParse(reviewCount.text) ?? 0,
                        imageUrl: imageUrl.text.trim().isEmpty
                            ? null
                            : imageUrl.text.trim(),
                        skills: skills.text
                            .split(',')
                            .map((item) => item.trim())
                            .where((item) => item.isNotEmpty)
                            .toList(),
                        bio: bio.text.trim(),
                        isActive: isActive,
                      );
                      try {
                        if (barber == null) {
                          await _service.create(value);
                        } else {
                          await _service.update(value);
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Không thể lưu: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Đang lưu...' : 'Lưu nhân viên'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      name,
      age,
      experience,
      rating,
      reviewCount,
      imageUrl,
      skills,
      bio,
    ]) {
      controller.dispose();
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _gold),
      filled: true,
      fillColor: _field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x44F4C567)),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label, icon),
    );
  }

  Future<void> _delete(Barber barber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'Xóa nhân viên',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Bạn có chắc muốn xóa ${barber.name} khỏi hệ thống?',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD94B4B),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.delete(barber.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'Quản lý nhân viên',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _initializing ? null : () => _openForm(),
        backgroundColor: _gold,
        foregroundColor: _ink,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Thêm nhân viên',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: sampleSalons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final salon = sampleSalons[index];
                return ChoiceChip(
                  label: Text(salon.name),
                  selected: salon.id == _selectedSalonId,
                  selectedColor: _gold,
                  backgroundColor: _field,
                  labelStyle: TextStyle(
                    color: salon.id == _selectedSalonId ? _ink : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedSalonId = salon.id);
                  },
                );
              },
            ),
          ),
          if (_initializing)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _gold),
              ),
            )
          else if (_initializationError != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không thể khởi tạo danh sách nhân viên.\n$_initializationError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: StreamBuilder<List<Barber>>(
                stream: _service.watchAll(),
                builder: (context, snapshot) {
                  final employees = (snapshot.data ?? const <Barber>[])
                      .where(
                        (barber) => barber.salonId == _selectedSalonId,
                      )
                      .toList();
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _gold),
                    );
                  }
                  if (employees.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chi nhánh chưa có nhân viên.',
                        style: TextStyle(color: _muted),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 680
                              ? 2
                              : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: employees.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: columns == 1 ? 2.35 : 2.05,
                        ),
                        itemBuilder: (context, index) {
                          return _employeeCard(employees[index]);
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _employeeCard(Barber barber) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x44F4C567)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 39,
            backgroundColor: _field,
            backgroundImage: barber.imageUrl?.isNotEmpty == true
                ? NetworkImage(barber.imageUrl!)
                : null,
            child: barber.imageUrl?.isNotEmpty == true
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: _gold,
                    size: 42,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  barber.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${barber.age} tuổi • ${barber.gender} • '
                  '${barber.experienceYears} năm KN',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: _gold,
                      size: 18,
                    ),
                    Text(
                      ' ${barber.rating}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    Icon(
                      barber.isActive
                          ? Icons.check_circle_rounded
                          : Icons.visibility_off_rounded,
                      color: barber.isActive ? Colors.greenAccent : _muted,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: _field,
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'edit') {
                _openForm(barber);
              } else {
                _delete(barber);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text(
                  'Chỉnh sửa',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Xóa',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

