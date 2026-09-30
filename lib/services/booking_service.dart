import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/barber.dart';
import '../models/hair_service.dart';
import '../models/hairstyle.dart';
import '../models/salon.dart';
import '../models/voucher.dart';
import 'barber_service.dart';

class BookingConflictException implements Exception {
  final String message;

  const BookingConflictException([
    this.message = 'Thợ đã có lịch trong khoảng thời gian này.',
  ]);

  @override
  String toString() {
    return message;
  }
}

class BookingService {
  final FirebaseFirestore _firestore;

  BookingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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
    if (paymentChoice != 'pay_now' && paymentChoice != 'pay_later') {
      throw ArgumentError.value(paymentChoice, 'paymentChoice');
    }

    final normalizedPhone = userPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^0[0-9]{9}$').hasMatch(normalizedPhone)) {
      throw ArgumentError.value(userPhone, 'userPhone');
    }

    final int originalPrice = selectedServices.fold(0, (total, service) {
      return total + service.price;
    });

    final int totalDuration = selectedServices.fold(0, (total, service) {
      return total + service.durationMinutes;
    });

    final List<Barber> candidateBarbers;

    if (useAnyBarber) {
      candidateBarbers = await BarberService().getBySalon(salon.id);
    } else if (selectedBarber != null) {
      candidateBarbers = [selectedBarber];
    } else {
      throw ArgumentError('Chưa chọn thợ cho lịch hẹn.');
    }

    if (candidateBarbers.isEmpty) {
      throw const BookingConflictException(
        'Chi nhánh này chưa có thợ để nhận lịch.',
      );
    }

    final List<DateTime> occupiedTimes = _createOccupiedTimes(
      appointmentAt: appointmentAt,
      durationMinutes: totalDuration,
    );

    final DocumentReference<Map<String, dynamic>> bookingReference = _firestore
        .collection('bookings')
        .doc();

    if (selectedVouchers.where((voucher) => !voucher.isPersonal).length > 1 ||
        (selectedVouchers.length > 1 &&
            selectedVouchers.any((voucher) => !voucher.isPersonal))) {
      throw StateError(
        'Mã khuyến mãi không thể dùng chung với voucher tích lũy.',
      );
    }
    if (selectedVouchers.map((voucher) => voucher.id).toSet().length !=
        selectedVouchers.length) {
      throw StateError('Không thể áp dụng trùng một voucher.');
    }
    final personalRewardTypes = selectedVouchers
        .where((voucher) => voucher.isPersonal)
        .map((voucher) => voucher.rewardType)
        .toList();
    if (personalRewardTypes.toSet().length != personalRewardTypes.length) {
      throw StateError(
        'Chỉ được chọn một voucher cho mỗi loại tích lũy.',
      );
    }
    final voucherReferences = selectedVouchers.map((voucher) {
      return voucher.isPersonal
          ? _firestore
                .collection('users')
                .doc(user.uid)
                .collection('vouchers')
                .doc(voucher.id)
          : _firestore.collection('voucher_templates').doc(voucher.id);
    }).toList();
    final redemptionReferences = selectedVouchers.map((voucher) {
      return voucher.isPersonal
          ? null
          : _firestore
                .collection('voucher_templates')
                .doc(voucher.id)
                .collection('redemptions')
                .doc(user.uid);
    }).toList();

    final Map<String, List<DocumentReference<Map<String, dynamic>>>>
    slotReferencesByBarber = {};

    for (final Barber barber in candidateBarbers) {
      slotReferencesByBarber[barber.id] = occupiedTimes.map((slotTime) {
        final String slotId = _createSlotId(
          salonId: salon.id,
          barberId: barber.id,
          slotTime: slotTime,
        );

        return _firestore.collection('booking_slots').doc(slotId);
      }).toList();
    }

    final bool bookingCreated = await _firestore.runTransaction<bool>((
      transaction,
    ) async {
      int discountAmount = 0;
      int totalPrice = originalPrice;
      final appliedVouchers = <Map<String, dynamic>>[];
      final voucherUsedCounts = <int>[];

      for (var index = 0; index < selectedVouchers.length; index++) {
        final selectedVoucher = selectedVouchers[index];
        final voucherReference = voucherReferences[index];
        final redemptionReference = redemptionReferences[index];
        final voucherSnapshot = await transaction.get(voucherReference);
        if (!voucherSnapshot.exists) {
          throw StateError('Voucher không còn tồn tại.');
        }
        final voucherData = voucherSnapshot.data()!;
        final isActive = voucherData['isActive'] as bool? ?? false;
        final isUsed = voucherData['isUsed'] as bool? ?? false;
        final voucherUsedCount =
            (voucherData['usedCount'] as num?)?.toInt() ?? 0;
        voucherUsedCounts.add(voucherUsedCount);
        final usageLimit =
            (voucherData['usageLimit'] as num?)?.toInt() ?? 1;
        final discountPercent =
            (voucherData['discountPercent'] as num?)?.toInt() ?? 0;
        final minOrderAmount =
            (voucherData['minOrderAmount'] as num?)?.toInt() ?? 0;
        final expiresAt = (voucherData['expiresAt'] as Timestamp?)?.toDate();
        final isExpired = expiresAt != null && !expiresAt.isAfter(DateTime.now());
        if (redemptionReference != null) {
          final redemptionSnapshot = await transaction.get(
            redemptionReference,
          );
          if (redemptionSnapshot.exists) {
            throw StateError('Bạn đã sử dụng voucher này trước đó.');
          }
        }

        if (!isActive ||
            (selectedVoucher.isPersonal && isUsed) ||
            (!selectedVoucher.isPersonal &&
                usageLimit > 0 &&
                voucherUsedCount >= usageLimit) ||
            discountPercent <= 0 ||
            discountPercent > 100 ||
            originalPrice < minOrderAmount ||
            isExpired) {
          throw StateError('Voucher không còn đủ điều kiện sử dụng.');
        }

        discountAmount += originalPrice * discountPercent ~/ 100;
        final storedCode = voucherData['code']?.toString() ?? '';
        final source = voucherData['source']?.toString() ?? 'admin';
        final storedRewardType = voucherData['rewardType']?.toString() ?? '';
        final isOrderReward = storedRewardType == 'minimum_order' ||
            voucherSnapshot.id.startsWith('loyalty_order_') ||
            source == 'loyalty_order' ||
            storedCode.toUpperCase().startsWith('DON') ||
            storedCode.toUpperCase() == 'CHITIEU';
        final rewardType = isOrderReward ? 'minimum_order' : 'visit_count';
        appliedVouchers.add({
          'id': voucherSnapshot.id,
          'code': rewardType == 'minimum_order' ? 'CHITIEU' : storedCode,
          'title': voucherData['title']?.toString() ?? 'Voucher ưu đãi',
          'discountPercent': discountPercent,
          'minOrderAmount': minOrderAmount,
          'usageLimit': usageLimit,
          'source': source,
          'isPersonal': selectedVoucher.isPersonal,
          'rewardType': rewardType,
        });
      }
      if (discountAmount > originalPrice) discountAmount = originalPrice;
      totalPrice = originalPrice - discountAmount;

      final Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>
      slotSnapshotsByBarber = {};

      // Firestore yêu cầu đọc toàn bộ dữ liệu trước khi ghi.
      for (final Barber barber in candidateBarbers) {
        final List<DocumentReference<Map<String, dynamic>>> slotReferences =
            slotReferencesByBarber[barber.id]!;

        final List<DocumentSnapshot<Map<String, dynamic>>> snapshots = [];

        for (final slotReference in slotReferences) {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(slotReference);

          snapshots.add(snapshot);
        }

        slotSnapshotsByBarber[barber.id] = snapshots;
      }

      Barber? availableBarber;

      for (final Barber barber in candidateBarbers) {
        final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
            slotSnapshotsByBarber[barber.id]!;

        final bool allSlotsAreAvailable = snapshots.every(
          (snapshot) => !snapshot.exists,
        );

        if (allSlotsAreAvailable) {
          availableBarber = barber;
          break;
        }
      }

      if (availableBarber == null) {
        return false;
      }

      final Barber assignedBarber = availableBarber;

      final List<DocumentReference<Map<String, dynamic>>>
      selectedSlotReferences = slotReferencesByBarber[assignedBarber.id]!;

      final List<String> slotIds = selectedSlotReferences
          .map((reference) => reference.id)
          .toList();

      transaction.set(bookingReference, {
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? '',
        'userPhone': normalizedPhone,
        'salonId': salon.id,
        'salonName': salon.name,
        'salonAddress': salon.address,
        'salonHotline': salon.hotline,
        'barberId': assignedBarber.id,
        'barberName': assignedBarber.name,
        'useAnyBarber': useAnyBarber,
        'autoAssignedBarber': useAnyBarber,
        'serviceIds': selectedServices.map((service) => service.id).toList(),
        'services': selectedServices.map((service) {
          return {
            'id': service.id,
            'name': service.name,
            'price': service.price,
            'durationMinutes': service.durationMinutes,
          };
        }).toList(),
        'hairstyle': selectedHairstyle == null
            ? null
            : {
                'id': selectedHairstyle.id,
                'name': selectedHairstyle.name,
                'description': selectedHairstyle.description,
                'imageUrl': selectedHairstyle.imageUrl,
                'assetPath': selectedHairstyle.assetPath,
              },
        'appointmentAt': Timestamp.fromDate(appointmentAt),
        'selectedTime': selectedTime,
        'originalPrice': originalPrice,
        'discountAmount': discountAmount,
        'totalPrice': totalPrice,
        'voucher': appliedVouchers.isEmpty ? null : appliedVouchers.first,
        'vouchers': appliedVouchers,
        'voucherIds': appliedVouchers
            .map((voucher) => voucher['id'].toString())
            .toList(),
        'totalDurationMinutes': totalDuration,
        'slotIds': slotIds,
        // Thanh toán sau được áp dụng lịch ngay. Thanh toán VNPAY chỉ ở trạng
        // thái chờ trong thời gian cổng thanh toán xử lý và sẽ được IPN xác
        // nhận tự động sau khi giao dịch thành công.
        'status': paymentChoice == 'pay_later' ? 'confirmed' : 'pending',
        'payment': {
          'provider': 'vnpay',
          'environment': 'sandbox',
          'status': 'unpaid',
          'choice': paymentChoice,
          'amount': totalPrice,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var index = 0; index < selectedVouchers.length; index++) {
        final selectedVoucher = selectedVouchers[index];
        final voucherReference = voucherReferences[index];
        final redemptionReference = redemptionReferences[index];
        if (selectedVoucher.isPersonal) {
          transaction.update(voucherReference, {
            'isUsed': true,
            'usedBookingId': bookingReference.id,
            'usedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (redemptionReference != null) {
          transaction.update(voucherReference, {
            'usedCount': voucherUsedCounts[index] + 1,
            'lastBookingId': bookingReference.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(redemptionReference, {
            'userId': user.uid,
            'bookingId': bookingReference.id,
            'usedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      for (int index = 0; index < selectedSlotReferences.length; index++) {
        transaction.set(selectedSlotReferences[index], {
          'bookingId': bookingReference.id,
          'userId': user.uid,
          'salonId': salon.id,
          'barberId': assignedBarber.id,
          'slotAt': Timestamp.fromDate(occupiedTimes[index]),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    });

    if (!bookingCreated) {
      if (useAnyBarber) {
        throw const BookingConflictException(
          'Tất cả thợ tại chi nhánh đều đã bận '
          'trong khoảng thời gian này.',
        );
      }

      throw const BookingConflictException(
        'Thợ bạn chọn đã có lịch trong '
        'khoảng thời gian này.',
      );
    }

    return bookingReference.id;
  }

  Future<void> updateBookingServices({
    required String bookingId,
    required String userId,
    required List<HairService> selectedServices,
  }) async {
    if (selectedServices.isEmpty) {
      throw ArgumentError('Lịch hẹn phải có ít nhất một dịch vụ.');
    }
    if (selectedServices.map((service) => service.id).toSet().length !=
        selectedServices.length) {
      throw ArgumentError('Danh sách dịch vụ bị trùng.');
    }
    if (selectedServices.any(
      (service) =>
          service.name.isEmpty ||
          service.price < 0 ||
          service.durationMinutes <= 0,
    )) {
      throw ArgumentError('Thông tin dịch vụ không hợp lệ.');
    }

    final bookingReference = _firestore.collection('bookings').doc(bookingId);
    await _firestore.runTransaction<void>((transaction) async {
      final bookingSnapshot = await transaction.get(bookingReference);
      if (!bookingSnapshot.exists) {
        throw StateError('Không tìm thấy lịch hẹn.');
      }

      final booking = bookingSnapshot.data()!;
      if (booking['userId'] != userId) {
        throw StateError('Bạn không có quyền sửa lịch hẹn này.');
      }
      final status = booking['status']?.toString() ?? 'pending';
      if (status != 'pending' && status != 'confirmed') {
        throw StateError('Lịch đã kết thúc hoặc bị hủy nên không thể sửa.');
      }
      final payment = Map<String, dynamic>.from(
        booking['payment'] as Map? ?? const <String, dynamic>{},
      );
      if (payment['status'] != 'unpaid') {
        throw StateError(
          'Không thể đổi dịch vụ sau khi đã bắt đầu hoặc hoàn tất thanh toán.',
        );
      }
      final voucherIds = booking['voucherIds'] as List<dynamic>? ?? const [];
      if (voucherIds.isNotEmpty) {
        throw StateError(
          'Lịch đã dùng voucher nên không thể đổi dịch vụ. '
          'Hãy hủy lịch và đặt lại để voucher được tính chính xác.',
        );
      }

      final appointmentAt = (booking['appointmentAt'] as Timestamp?)?.toDate();
      final salonId = booking['salonId']?.toString() ?? '';
      final barberId = booking['barberId']?.toString() ?? '';
      if (appointmentAt == null || salonId.isEmpty || barberId.isEmpty) {
        throw StateError('Lịch hẹn thiếu thông tin thời gian hoặc thợ.');
      }
      if (!appointmentAt.isAfter(DateTime.now())) {
        throw StateError('Lịch đã đến giờ nên không thể đổi dịch vụ.');
      }

      final originalPrice = selectedServices.fold<int>(
        0,
        (total, service) => total + service.price,
      );
      final totalDuration = selectedServices.fold<int>(
        0,
        (total, service) => total + service.durationMinutes,
      );
      final occupiedTimes = _createOccupiedTimes(
        appointmentAt: appointmentAt,
        durationMinutes: totalDuration,
      );
      final newSlotReferences = occupiedTimes.map((slotTime) {
        final slotId = _createSlotId(
          salonId: salonId,
          barberId: barberId,
          slotTime: slotTime,
        );
        return _firestore.collection('booking_slots').doc(slotId);
      }).toList();

      // Firestore yêu cầu hoàn tất tất cả lượt đọc trước khi ghi.
      final newSlotSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final slotReference in newSlotReferences) {
        newSlotSnapshots.add(await transaction.get(slotReference));
      }
      final hasConflict = newSlotSnapshots.any(
        (slot) =>
            slot.exists && slot.data()?['bookingId']?.toString() != bookingId,
      );
      if (hasConflict) {
        throw const BookingConflictException(
          'Không đủ thời gian trống để thêm dịch vụ. '
          'Vui lòng chọn lịch khác hoặc bỏ bớt dịch vụ.',
        );
      }

      final oldSlotIds = (booking['slotIds'] as List<dynamic>? ?? const [])
          .map((slotId) => slotId.toString())
          .toSet();
      final newSlotIds = newSlotReferences
          .map((reference) => reference.id)
          .toSet();

      transaction.update(bookingReference, {
        'serviceIds': selectedServices.map((service) => service.id).toList(),
        'services': selectedServices
            .map(
              (service) => {
                'id': service.id,
                'name': service.name,
                'price': service.price,
                'durationMinutes': service.durationMinutes,
              },
            )
            .toList(),
        'originalPrice': originalPrice,
        'discountAmount': 0,
        'totalPrice': originalPrice,
        'totalDurationMinutes': totalDuration,
        'slotIds': newSlotIds.toList(),
        'payment': {...payment, 'amount': originalPrice},
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final oldSlotId in oldSlotIds.difference(newSlotIds)) {
        transaction.delete(
          _firestore.collection('booking_slots').doc(oldSlotId),
        );
      }
      for (var index = 0; index < newSlotReferences.length; index++) {
        if (!newSlotSnapshots[index].exists) {
          transaction.set(newSlotReferences[index], {
            'bookingId': bookingId,
            'userId': userId,
            'salonId': salonId,
            'barberId': barberId,
            'slotAt': Timestamp.fromDate(occupiedTimes[index]),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
  }) async {
    final DocumentReference<Map<String, dynamic>> bookingReference = _firestore
        .collection('bookings')
        .doc(bookingId);
    final staleSlotSnapshot = await _firestore
        .collection('booking_slots')
        .where('bookingId', isEqualTo: bookingId)
        .get();
    final discoveredSlotIds = staleSlotSnapshot.docs
        .map((document) => document.id)
        .toSet();

    await _firestore.runTransaction<void>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnapshot =
          await transaction.get(bookingReference);

      if (!bookingSnapshot.exists) {
        throw StateError('Không tìm thấy lịch hẹn.');
      }

      final Map<String, dynamic> bookingData = bookingSnapshot.data()!;

      if (bookingData['userId'] != userId) {
        throw StateError('Bạn không có quyền hủy lịch hẹn này.');
      }

      final bool alreadyCancelled = bookingData['status'] == 'cancelled';
      final List<dynamic> rawSlotIds =
          bookingData['slotIds'] as List<dynamic>? ?? [];

      final Set<String> slotIds = {
        ...rawSlotIds.map((slotId) => slotId.toString()),
        ...discoveredSlotIds,
      };

      if (!alreadyCancelled) {
        transaction.update(bookingReference, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Query by bookingId as well as using slotIds so older bookings or
      // bookings whose services changed cannot leave ghost time slots behind.
      for (final String slotId in slotIds) {
        final DocumentReference<Map<String, dynamic>> slotReference = _firestore
            .collection('booking_slots')
            .doc(slotId);

        transaction.delete(slotReference);
      }
    });
  }

  List<DateTime> _createOccupiedTimes({
    required DateTime appointmentAt,
    required int durationMinutes,
  }) {
    final int numberOfSlots = (durationMinutes / 30).ceil();

    return List<DateTime>.generate(numberOfSlots, (index) {
      return appointmentAt.add(Duration(minutes: index * 30));
    });
  }

  String _createSlotId({
    required String salonId,
    required String barberId,
    required DateTime slotTime,
  }) {
    final String year = slotTime.year.toString().padLeft(4, '0');

    final String month = slotTime.month.toString().padLeft(2, '0');

    final String day = slotTime.day.toString().padLeft(2, '0');

    final String hour = slotTime.hour.toString().padLeft(2, '0');

    final String minute = slotTime.minute.toString().padLeft(2, '0');

    return '${salonId}_${barberId}_'
        '$year$month$day$hour$minute';
  }
}
