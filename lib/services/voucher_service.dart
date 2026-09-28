import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/loyalty_settings.dart';
import '../models/voucher.dart';

class VoucherService {
  final FirebaseFirestore _firestore;

  VoucherService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Voucher>> getAvailableLoyaltyVouchers({
    required String userId,
    required int orderAmount,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('vouchers')
        .get();
    final vouchers = snapshot.docs
        .map((document) => Voucher.fromDocument(document, isPersonal: true))
        .toList();

    vouchers.sort((first, second) {
      final discountCompare = second.discountPercent.compareTo(
        first.discountPercent,
      );
      if (discountCompare != 0) return discountCompare;
      return first.minOrderAmount.compareTo(second.minOrderAmount);
    });
    return vouchers.where((voucher) => voucher.canApply(orderAmount)).toList();
  }

  Future<Voucher> validatePromotionCode({
    required String userId,
    required String code,
    required int orderAmount,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw StateError('Vui lòng nhập mã khuyến mãi.');
    }

    final snapshot = await _firestore
        .collection('voucher_templates')
        .where('code', isEqualTo: normalizedCode)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Mã khuyến mãi không tồn tại.');
    }

    final document = snapshot.docs.first;
    final voucher = Voucher.fromDocument(document, isPersonal: false);
    if (!voucher.isActive) {
      throw StateError('Mã khuyến mãi đang tạm dừng.');
    }
    if (voucher.expiresAt != null &&
        !voucher.expiresAt!.isAfter(DateTime.now())) {
      throw StateError('Mã khuyến mãi đã hết hạn.');
    }
    if (voucher.remainingUses == 0) {
      throw StateError('Mã khuyến mãi đã hết lượt sử dụng.');
    }
    if (orderAmount < voucher.minOrderAmount) {
      throw StateError(
        'Đơn hàng chưa đạt giá trị tối thiểu của mã khuyến mãi.',
      );
    }

    final redemption = await document.reference
        .collection('redemptions')
        .doc(userId)
        .get();
    if (redemption.exists) {
      throw StateError('Bạn đã sử dụng mã khuyến mãi này trước đó.');
    }
    return voucher;
  }

  Future<LoyaltySettings> getLoyaltySettings() async {
    final snapshot = await _firestore
        .collection('app_settings')
        .doc('loyalty')
        .get();
    return LoyaltySettings.fromMap(snapshot.data());
  }

  Future<void> awardLoyaltyVoucherIfEligible({
    required String userId,
    required String bookingId,
  }) async {
    if (userId.isEmpty || bookingId.isEmpty) return;

    final settings = await getLoyaltySettings();
    if (!settings.visitRewardEnabled && !settings.orderRewardEnabled) return;

    final bookingSnapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!bookingSnapshot.exists) return;
    final bookingData = bookingSnapshot.data()!;
    if (bookingData['status'] != 'completed' ||
        bookingData['userId']?.toString() != userId) {
      return;
    }

    if (settings.orderRewardEnabled) {
      final totalPrice =
          (bookingData['totalPrice'] as num?)?.toInt() ??
          (bookingData['price'] as num?)?.toInt() ??
          0;
      if (totalPrice >= settings.minimumOrderAmount) {
        final shortBookingId = bookingId.length > 6
            ? bookingId.substring(0, 6).toUpperCase()
            : bookingId.toUpperCase();
        await _awardVoucher(
          userId: userId,
          bookingId: bookingId,
          voucherId: 'loyalty_order_$bookingId',
          code: 'DON$shortBookingId',
          title: 'Ưu đãi cho đơn hàng đủ điều kiện',
          description:
              'Giảm ${settings.orderDiscountPercent}% cho lần đặt lịch tiếp theo.',
          discountPercent: settings.orderDiscountPercent,
          rewardType: 'minimum_order',
          notificationMessage:
              'Đơn hàng của bạn đã đạt ${settings.minimumOrderAmount}đ. Voucher đã sẵn sàng cho lần đặt lịch tiếp theo.',
        );
      }
    }

    if (settings.visitRewardEnabled) {
      final bookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();
      final completedCount = bookings.docs.where((document) {
        return document.data()['status'] == 'completed';
      }).length;
      if (completedCount >= settings.requiredVisits) {
        final milestone = completedCount ~/ settings.requiredVisits;
        final qualifyingCount = milestone * settings.requiredVisits;
        await _awardVoucher(
          userId: userId,
          bookingId: bookingId,
          voucherId:
              'loyalty_visit_${settings.requiredVisits}_$milestone',
          code: 'TRI_AN${qualifyingCount}LAN',
          title: 'Tri ân $qualifyingCount lần sử dụng dịch vụ',
          description:
              'Giảm ${settings.visitDiscountPercent}% cho lần đặt lịch tiếp theo.',
          discountPercent: settings.visitDiscountPercent,
          rewardType: 'visit_count',
          milestone: qualifyingCount,
          notificationMessage:
              'Cảm ơn bạn đã sử dụng dịch vụ $qualifyingCount lần. Voucher đã sẵn sàng cho lần đặt lịch tiếp theo.',
        );
      }
    }
  }

  Future<void> _awardVoucher({
    required String userId,
    required String bookingId,
    required String voucherId,
    required String code,
    required String title,
    required String description,
    required int discountPercent,
    required String rewardType,
    required String notificationMessage,
    int? milestone,
  }) async {
    final voucherReference = _firestore
        .collection('users')
        .doc(userId)
        .collection('vouchers')
        .doc(voucherId);
    final notificationReference = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc('voucher_$voucherId');

    await _firestore.runTransaction<void>((transaction) async {
      final existingVoucher = await transaction.get(voucherReference);
      if (existingVoucher.exists) return;

      transaction.set(voucherReference, {
        'code': code,
        'title': title,
        'description': description,
        'discountPercent': discountPercent,
        'minOrderAmount': 0,
        'isActive': true,
        'isUsed': false,
        'source': 'loyalty',
        if (milestone != null) 'milestone': milestone,
        'rewardType': rewardType,
        'sourceBookingId': bookingId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'type': 'voucher_received',
        'title': 'Bạn vừa nhận voucher giảm $discountPercent%',
        'message': notificationMessage,
        'voucherId': voucherId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
