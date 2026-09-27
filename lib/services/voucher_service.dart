import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/voucher.dart';

class VoucherService {
  final FirebaseFirestore _firestore;

  VoucherService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Voucher>> getAvailableVouchers({
    required String userId,
    required int orderAmount,
  }) async {
    final results = await Future.wait([
      _firestore.collection('users').doc(userId).collection('vouchers').get(),
      _firestore.collection('voucher_templates').get(),
    ]);

    final vouchers = <Voucher>[
      ...results[0].docs.map(
        (document) => Voucher.fromDocument(document, isPersonal: true),
      ),
      ...results[1].docs.map(
        (document) => Voucher.fromDocument(document, isPersonal: false),
      ),
    ];

    vouchers.sort((first, second) {
      final discountCompare = second.discountPercent.compareTo(
        first.discountPercent,
      );
      if (discountCompare != 0) return discountCompare;
      return first.minOrderAmount.compareTo(second.minOrderAmount);
    });
    return vouchers.where((voucher) => voucher.canApply(orderAmount)).toList();
  }

  Future<void> awardLoyaltyVoucherIfEligible(String userId) async {
    if (userId.isEmpty) return;

    final bookings = await _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .get();
    final completedCount = bookings.docs.where((document) {
      return document.data()['status'] == 'completed';
    }).length;

    if (completedCount < 10) return;

    final milestone = completedCount ~/ 10;
    final qualifyingCount = milestone * 10;
    final voucherId = 'loyalty_$milestone';
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
        'code': 'TRI_AN${qualifyingCount}LAN',
        'title': 'Tri ân $qualifyingCount lần sử dụng dịch vụ',
        'description': 'Giảm 25% cho lần đặt lịch tiếp theo.',
        'discountPercent': 25,
        'minOrderAmount': 0,
        'isActive': true,
        'isUsed': false,
        'source': 'loyalty',
        'milestone': qualifyingCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'type': 'voucher_received',
        'title': 'Bạn vừa nhận voucher giảm 25%',
        'message':
            'Cảm ơn bạn đã sử dụng dịch vụ $qualifyingCount lần. '
            'Voucher đã sẵn sàng cho lần đặt lịch tiếp theo.',
        'voucherId': voucherId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
