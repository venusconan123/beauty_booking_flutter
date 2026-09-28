class LoyaltySettings {
  final bool visitRewardEnabled;
  final int requiredVisits;
  final int visitDiscountPercent;
  final bool orderRewardEnabled;
  final int minimumOrderAmount;
  final int orderDiscountPercent;

  const LoyaltySettings({
    required this.visitRewardEnabled,
    required this.requiredVisits,
    required this.visitDiscountPercent,
    required this.orderRewardEnabled,
    required this.minimumOrderAmount,
    required this.orderDiscountPercent,
  });

  const LoyaltySettings.defaults()
    : visitRewardEnabled = true,
      requiredVisits = 10,
      visitDiscountPercent = 25,
      orderRewardEnabled = false,
      minimumOrderAmount = 500000,
      orderDiscountPercent = 10;

  factory LoyaltySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const LoyaltySettings.defaults();

    final legacyEnabled = data['isEnabled'] as bool? ?? true;
    final legacyRewardType = data['rewardType']?.toString();
    final requiredVisits = (data['requiredVisits'] as num?)?.toInt() ?? 10;
    final minimumOrderAmount =
        (data['minimumOrderAmount'] as num?)?.toInt() ?? 500000;
    final legacyDiscount =
        (data['discountPercent'] as num?)?.toInt() ?? 25;
    final visitDiscount =
        (data['visitDiscountPercent'] as num?)?.toInt() ?? legacyDiscount;
    final orderDiscount =
        (data['orderDiscountPercent'] as num?)?.toInt() ?? legacyDiscount;

    return LoyaltySettings(
      visitRewardEnabled: data['visitRewardEnabled'] as bool? ??
          (legacyEnabled && legacyRewardType != 'minimum_order'),
      requiredVisits: requiredVisits < 1 ? 1 : requiredVisits,
      visitDiscountPercent: _validPercent(visitDiscount),
      orderRewardEnabled: data['orderRewardEnabled'] as bool? ??
          (legacyEnabled && legacyRewardType == 'minimum_order'),
      minimumOrderAmount: minimumOrderAmount < 1 ? 1 : minimumOrderAmount,
      orderDiscountPercent: _validPercent(orderDiscount),
    );
  }

  static int _validPercent(int value) {
    if (value < 1) return 1;
    if (value > 100) return 100;
    return value;
  }
}
