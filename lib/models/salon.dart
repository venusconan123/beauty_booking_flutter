import 'hair_service.dart';

class Salon {
  final String id;
  final String name;
  final String address;
  final double distance;
  final double rating;
  final List<HairService> services;

  const Salon({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
    required this.services,
  });
}