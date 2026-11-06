import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import '../models/voucher.dart';
import 'scheduling_service.dart';

class BookingConflictException implements Exception {
  const BookingConflictException([
    this.message = 'Không còn ca hoặc giờ trống phù hợp.',
  ]);
  final String message;
  @override
  String toString() => message;
}

/// All writes share the backend's employee/day transaction guards.
class BookingService {
  final SchedulingService _service = SchedulingService();
  final Map<String, String> _requests = {};
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final key = '$name:${jsonEncode(data)}';
    final request = _requests.putIfAbsent(key, SchedulingService.requestId);
    final result = await _service.call(name, {...data, 'requestId': request});
    _requests.remove(key);
    return result;
  }

  Future<String> createBooking({
    required User user,
    required String userPhone,
    required Salon salon,
    required List<HairService> selectedServices,
    required Hairstyle? selectedHairstyle,
    required Barber? selectedBarber,
    required bool useAnyBarber,
    required DateTime appointmentAt,
    required String selectedTime,
    required String paymentChoice,
    List<Voucher> selectedVouchers = const [],
  }) async {
    final instant = DateTime.utc(
      appointmentAt.year,
      appointmentAt.month,
      appointmentAt.day,
      appointmentAt.hour,
      appointmentAt.minute,
    ).subtract(const Duration(hours: 7));
    final result = await _call('createBooking', {
      'salonId': salon.id,
      'serviceIds': selectedServices.map((s) => s.id).toList(),
      'expectedPrice': selectedServices.fold<int>(0, (sum, s) => sum + s.price),
      'expectedDuration': selectedServices.fold<int>(
        0,
        (sum, s) => sum + s.durationMinutes,
      ),
      'barberId': useAnyBarber ? null : selectedBarber?.id,
      'appointmentAt': instant.millisecondsSinceEpoch,
      'userPhone': userPhone.replaceAll(RegExp(r'[^0-9]'), ''),
      'paymentChoice': paymentChoice,
      'hairstyleId': selectedHairstyle?.id,
      'vouchers': selectedVouchers
          .map((v) => {'id': v.id, 'isPersonal': v.isPersonal})
          .toList(),
    });
    return result['bookingId'] as String;
  }

  Future<void> updateBookingServices({
    required String bookingId,
    required String userId,
    required List<HairService> selectedServices,
  }) async {
    await _call('updateBookingServices', {
      'bookingId': bookingId,
      'serviceIds': selectedServices.map((s) => s.id).toList(),
    });
  }

  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
  }) async {
    await _call('changeBookingStatus', {
      'bookingId': bookingId,
      'status': 'cancelled',
    });
  }
}
