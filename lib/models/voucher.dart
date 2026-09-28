import 'package:cloud_firestore/cloud_firestore.dart';

class Voucher {
  final String id;
  final String code;
  final String title;
  final String description;
  final int discountPercent;
  final int minOrderAmount;
  final int usageLimit;
  final int usedCount;
  final bool isActive;
  final bool isUsed;
  final bool isPersonal;
  final String source;
  final String rewardType;
  final DateTime? expiresAt;

  const Voucher({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.minOrderAmount,
    required this.usageLimit,
    required this.usedCount,
    required this.isActive,
    required this.isUsed,
    required this.isPersonal,
    required this.source,
    required this.rewardType,
    required this.expiresAt,
  });

  factory Voucher.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document, {
    required bool isPersonal,
  }) {
    final data = document.data() ?? <String, dynamic>{};
    final storedCode = data['code']?.toString() ?? '';
    final source = data['source']?.toString() ?? (isPersonal ? 'loyalty' : 'admin');
    final rewardType = data['rewardType']?.toString() ??
        (source == 'loyalty_order' || storedCode.toUpperCase().startsWith('DON')
            ? 'minimum_order'
            : 'visit_count');
    return Voucher(
      id: document.id,
      code: rewardType == 'minimum_order' ? 'CHITIEU' : storedCode,
      title: data['title']?.toString() ?? 'Voucher ưu đãi',
      description: data['description']?.toString() ?? '',
      discountPercent: (data['discountPercent'] as num?)?.toInt() ?? 0,
      minOrderAmount: (data['minOrderAmount'] as num?)?.toInt() ?? 0,
      usageLimit:
          (data['usageLimit'] as num?)?.toInt() ?? (isPersonal ? 0 : 1),
      usedCount: (data['usedCount'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? false,
      isUsed: data['isUsed'] as bool? ?? false,
      isPersonal: isPersonal,
      source: source,
      rewardType: rewardType,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  bool canApply(int orderAmount) {
    final now = DateTime.now();
    final hasRemainingUses = isPersonal ||
        usageLimit <= 0 ||
        usedCount < usageLimit;
    return isActive &&
        !isUsed &&
        hasRemainingUses &&
        discountPercent > 0 &&
        discountPercent <= 100 &&
        orderAmount >= minOrderAmount &&
        (expiresAt == null || expiresAt!.isAfter(now));
  }

  int? get remainingUses {
    if (isPersonal || usageLimit <= 0) return null;
    final remaining = usageLimit - usedCount;
    return remaining < 0 ? 0 : remaining;
  }

  int discountFor(int orderAmount) {
    if (!canApply(orderAmount)) return 0;
    return orderAmount * discountPercent ~/ 100;
  }
}
