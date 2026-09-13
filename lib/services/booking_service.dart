import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/salon.dart';

class BookingConflictException implements Exception {
  final String message;

  const BookingConflictException([
    this.message =
        'Thợ đã có lịch trong khoảng thời gian này.',
  ]);

  @override
  String toString() {
    return message;
  }
}

class BookingService {
  final FirebaseFirestore _firestore;

  BookingService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createBooking({
    required User user,
    required Salon salon,
    required List<HairService> selectedServices,
    required Barber? selectedBarber,
    required bool useAnyBarber,
    required DateTime appointmentAt,
    required String selectedTime,
  }) async {
    final int totalPrice = selectedServices.fold(
      0,
      (total, service) => total + service.price,
    );

    final int totalDuration = selectedServices.fold(
      0,
      (total, service) => total + service.durationMinutes,
    );

    final DocumentReference<Map<String, dynamic>>
        bookingReference =
        _firestore.collection('bookings').doc();

    final List<DateTime> occupiedTimes =
        _createOccupiedTimes(
      appointmentAt: appointmentAt,
      durationMinutes: totalDuration,
      shouldCreateSlots:
          !useAnyBarber && selectedBarber != null,
    );

    final List<
            DocumentReference<Map<String, dynamic>>>
        slotReferences = occupiedTimes.map(
      (slotTime) {
        final String slotId = _createSlotId(
          salonId: salon.id,
          barberId: selectedBarber!.id,
          slotTime: slotTime,
        );

        return _firestore
            .collection('booking_slots')
            .doc(slotId);
      },
    ).toList();

    await _firestore.runTransaction<void>(
      (transaction) async {
        final List<
                DocumentSnapshot<Map<String, dynamic>>>
            slotSnapshots = [];

        // Firestore yêu cầu đọc dữ liệu trước khi ghi.
        for (final slotReference in slotReferences) {
          final slotSnapshot =
              await transaction.get(slotReference);

          slotSnapshots.add(slotSnapshot);
        }

        final bool hasConflict = slotSnapshots.any(
          (snapshot) => snapshot.exists,
        );

        if (hasConflict) {
          throw const BookingConflictException();
        }

        final String barberName = useAnyBarber
            ? 'Thợ bất kỳ'
            : selectedBarber?.name ?? 'Chưa chọn thợ';

        final List<String> slotIds = slotReferences
            .map((reference) => reference.id)
            .toList();

        transaction.set(
          bookingReference,
          {
            'userId': user.uid,
            'userEmail': user.email,
            'userName': user.displayName ?? '',
            'salonId': salon.id,
            'salonName': salon.name,
            'salonAddress': salon.address,
            'barberId':
                useAnyBarber ? null : selectedBarber?.id,
            'barberName': barberName,
            'useAnyBarber': useAnyBarber,
            'serviceIds': selectedServices
                .map((service) => service.id)
                .toList(),
            'services': selectedServices.map(
              (service) {
                return {
                  'id': service.id,
                  'name': service.name,
                  'price': service.price,
                  'durationMinutes':
                      service.durationMinutes,
                };
              },
            ).toList(),
            'appointmentAt':
                Timestamp.fromDate(appointmentAt),
            'selectedTime': selectedTime,
            'totalPrice': totalPrice,
            'totalDurationMinutes': totalDuration,
            'slotIds': slotIds,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        for (int index = 0;
            index < slotReferences.length;
            index++) {
          transaction.set(
            slotReferences[index],
            {
              'bookingId': bookingReference.id,
              'userId': user.uid,
              'salonId': salon.id,
              'barberId': selectedBarber!.id,
              'slotAt': Timestamp.fromDate(
                occupiedTimes[index],
              ),
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      },
    );
  }

  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
  }) async {
    final DocumentReference<Map<String, dynamic>>
        bookingReference =
        _firestore.collection('bookings').doc(bookingId);

    await _firestore.runTransaction<void>(
      (transaction) async {
        final DocumentSnapshot<Map<String, dynamic>>
            bookingSnapshot =
            await transaction.get(bookingReference);

        if (!bookingSnapshot.exists) {
          throw StateError('Không tìm thấy lịch hẹn.');
        }

        final Map<String, dynamic> bookingData =
            bookingSnapshot.data()!;

        if (bookingData['userId'] != userId) {
          throw StateError(
            'Bạn không có quyền hủy lịch hẹn này.',
          );
        }

        if (bookingData['status'] == 'cancelled') {
          return;
        }

        final List<dynamic> rawSlotIds =
            bookingData['slotIds'] as List<dynamic>? ?? [];

        final List<String> slotIds = rawSlotIds
            .map((slotId) => slotId.toString())
            .toList();

        transaction.update(
          bookingReference,
          {
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        for (final String slotId in slotIds) {
          final slotReference = _firestore
              .collection('booking_slots')
              .doc(slotId);

          transaction.delete(slotReference);
        }
      },
    );
  }

  List<DateTime> _createOccupiedTimes({
    required DateTime appointmentAt,
    required int durationMinutes,
    required bool shouldCreateSlots,
  }) {
    if (!shouldCreateSlots) {
      return [];
    }

    final int numberOfSlots =
        (durationMinutes / 30).ceil();

    return List<DateTime>.generate(
      numberOfSlots,
      (index) {
        return appointmentAt.add(
          Duration(minutes: index * 30),
        );
      },
    );
  }

  String _createSlotId({
    required String salonId,
    required String barberId,
    required DateTime slotTime,
  }) {
    final String year =
        slotTime.year.toString().padLeft(4, '0');
    final String month =
        slotTime.month.toString().padLeft(2, '0');
    final String day =
        slotTime.day.toString().padLeft(2, '0');
    final String hour =
        slotTime.hour.toString().padLeft(2, '0');
    final String minute =
        slotTime.minute.toString().padLeft(2, '0');

    return '${salonId}_${barberId}_'
        '$year$month$day$hour$minute';
  }
}