import 'hair_service.dart';

class Salon {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final double rating;
  final List<HairService> services;

  const Salon({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.rating,
    required this.services,
  });
}
