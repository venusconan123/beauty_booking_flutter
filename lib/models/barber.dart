class Barber {
  final String id;
  final String salonId;
  final String name;
  final int experienceYears;
  final double rating;
  final String? imageUrl;

  const Barber({
    required this.id,
    required this.salonId,
    required this.name,
    required this.experienceYears,
    required this.rating,
    this.imageUrl,
  });
}