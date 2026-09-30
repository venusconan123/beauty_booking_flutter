class HairService {
  final String id;
  final String name;
  final int price;
  final int durationMinutes;
  final String description;

  const HairService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.description,
  });

  factory HairService.fromMap(String id, Map<String, dynamic> data) {
    return HairService(
      id: id,
      name: data['name']?.toString() ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      description: data['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'durationMinutes': durationMinutes,
      'description': description,
    };
  }

  HairService copyWith({
    String? name,
    int? price,
    int? durationMinutes,
    String? description,
  }) {
    return HairService(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      description: description ?? this.description,
    );
  }
}
