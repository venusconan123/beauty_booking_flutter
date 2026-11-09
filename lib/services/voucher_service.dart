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
}
