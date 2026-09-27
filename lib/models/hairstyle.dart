import 'package:cloud_firestore/cloud_firestore.dart';

class Hairstyle {
  const Hairstyle({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl = '',
    this.assetPath = '',
    this.storagePath = '',
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String assetPath;
  final String storagePath;
  final bool isActive;
  final DateTime? createdAt;

  bool get isManaged => id.isNotEmpty && imageUrl.isNotEmpty;

  factory Hairstyle.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return Hairstyle(
      id: document.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

const List<Hairstyle> defaultHairstyles = [
  Hairstyle(
    id: '',
    name: 'Textured Crop',
    description: 'Năng động • Hiện đại • Dễ chăm sóc',
    assetPath: 'assets/images/style_textured_crop.jpg',
  ),
  Hairstyle(
    id: '',
    name: 'Korean Layer',
    description: 'Thanh lịch • Trẻ trung • Hợp nhiều khuôn mặt',
    assetPath: 'assets/images/style_korean_layer.jpg',
  ),
  Hairstyle(
    id: '',
    name: 'Modern Mullet',
    description: 'Cá tính • Thời thượng • Tạo chất riêng',
    assetPath: 'assets/images/style_modern_mullet.jpg',
  ),
  Hairstyle(
    id: '',
    name: 'Modern Side Part',
    description: 'Lịch lãm • Gọn gàng • Phù hợp công sở',
    assetPath: 'assets/images/style_modern_side_part.jpg',
  ),
  Hairstyle(
    id: '',
    name: 'Modern Quiff',
    description: 'Nam tính • Bồng bềnh • Nổi bật đường nét',
    assetPath: 'assets/images/style_modern_quiff.jpg',
  ),
  Hairstyle(
    id: '',
    name: 'Buzz Fade',
    description: 'Mạnh mẽ • Tối giản • Dễ chăm sóc',
    assetPath: 'assets/images/style_buzz_fade.jpg',
  ),
];
