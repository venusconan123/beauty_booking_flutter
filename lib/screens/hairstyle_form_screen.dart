import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/hairstyle.dart';
import '../services/hairstyle_service.dart';

class HairstyleFormScreen extends StatefulWidget {
  const HairstyleFormScreen({super.key, this.hairstyle});

  final Hairstyle? hairstyle;

  @override
  State<HairstyleFormScreen> createState() => _HairstyleFormScreenState();
}

class _HairstyleFormScreenState extends State<HairstyleFormScreen> {
  static const Color _ink = Color(0xFF090E14);
  static const Color _gold = Color(0xFFF0C36A);

  final _formKey = GlobalKey<FormState>();
  final _service = HairstyleService();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isActive = true;
  bool _saving = false;

  bool get _editing => widget.hairstyle != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hairstyle?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.hairstyle?.description ?? '',
    );
    _isActive = widget.hairstyle?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_editing && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh mẫu tóc.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editing) {
        await _service.update(
          hairstyle: widget.hairstyle!,
          name: _nameController.text,
          description: _descriptionController.text,
          isActive: _isActive,
          imageBytes: _imageBytes,
          fileName: _imageName,
        );
      } else {
        await _service.create(
          name: _nameController.text,
          description: _descriptionController.text,
          imageBytes: _imageBytes!,
          fileName: _imageName!,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu mẫu tóc: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE5),
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: Text(_editing ? 'SỬA MẪU TÓC' : 'THÊM MẪU TÓC'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên kiểu tóc',
                          prefixIcon: Icon(Icons.content_cut_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập tên kiểu tóc.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập mô tả.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Hiển thị cho khách hàng',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Tắt để tạm ẩn mẫu tóc mà không cần xóa.',
                        ),
                        activeTrackColor: _gold,
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'ĐANG LƯU...' : 'LƯU MẪU TÓC'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _ink,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    Widget preview;
    if (_imageBytes != null) {
      preview = Image.memory(_imageBytes!, fit: BoxFit.cover);
    } else if (widget.hairstyle?.imageUrl.isNotEmpty == true) {
      preview = Image.network(widget.hairstyle!.imageUrl, fit: BoxFit.cover);
    } else {
      preview = const ColoredBox(
        color: Color(0xFF111923),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: _gold, size: 54),
              SizedBox(height: 8),
              Text('Chọn ảnh từ thiết bị', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(_editing ? 'Đổi ảnh' : 'Chọn ảnh'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xE6090E14),
                    foregroundColor: Colors.white,
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
