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
  final String openingTime;
  final String closingTime;
  final String hotline;

  const Salon({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.rating,
    required this.services,
    required this.hotline,
    this.openingTime = '07:00',
    this.closingTime = '22:00',
  });

  Salon copyWith({String? hotline}) {
    return Salon(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distance: distance,
      rating: rating,
      services: services,
      hotline: hotline ?? this.hotline,
      openingTime: openingTime,
      closingTime: closingTime,
    );
  }
}
