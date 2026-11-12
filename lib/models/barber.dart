class Barber {
  final String id;
  final String salonId;
  final String name;
  final int experienceYears;
  final double rating;
  final String? imageUrl;
  final int age;
  final String gender;
  final List<String> skills;
  final int reviewCount;
  final String bio;
  final bool isActive;

  const Barber({
    required this.id,
    required this.salonId,
    required this.name,
    required this.experienceYears,
    required this.rating,
    this.imageUrl,
    this.age = 25,
    this.gender = 'Nam',
    this.skills = const ['Cắt tóc', 'Tạo kiểu'],
    this.reviewCount = 0,
    this.bio =
        'Chuyên gia tạo kiểu tóc nam, tư vấn phong cách phù hợp khuôn mặt.',
    this.isActive = true,
  });

  factory Barber.fromDocument(String id, Map<String, dynamic> data) {
    return Barber(
      id: id,
      salonId: data['salonId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      experienceYears: (data['experienceYears'] as num?)?.toInt() ?? 0,
      // Employee documents may still contain historical manual/demo scores.
      // Ratings are attached only from the verified review aggregation API.
      rating: 0,
      imageUrl: data['imageUrl']?.toString(),
      age: (data['age'] as num?)?.toInt() ?? 25,
      gender: data['gender']?.toString() ?? 'Nam',
      skills: (data['skills'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(),
      reviewCount: 0,
      bio: data['bio']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'salonId': salonId,
    'name': name,
    'experienceYears': experienceYears,
    'imageUrl': imageUrl ?? '',
    'age': age,
    'gender': gender,
    'skills': skills,
    'bio': bio,
    'isActive': isActive,
  };

  String get reviewSummary => reviewCount == 0
      ? 'Chưa có đánh giá'
      : '${rating.toStringAsFixed(1)} ($reviewCount đánh giá)';

  Barber withReviewStats({required double average, required int count}) =>
      Barber(
        id: id,
        salonId: salonId,
        name: name,
        experienceYears: experienceYears,
        rating: average,
        reviewCount: count,
        imageUrl: imageUrl,
        age: age,
        gender: gender,
        skills: skills,
        bio: bio,
        isActive: isActive,
      );
}
