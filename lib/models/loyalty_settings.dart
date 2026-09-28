enum LoyaltyRewardType { visitCount, minimumOrder }

class LoyaltySettings {
  final bool isEnabled;
  final LoyaltyRewardType rewardType;
  final int requiredVisits;
  final int minimumOrderAmount;
  final int discountPercent;

  const LoyaltySettings({
    required this.isEnabled,
    required this.rewardType,
    required this.requiredVisits,
    required this.minimumOrderAmount,
    required this.discountPercent,
  });

  const LoyaltySettings.defaults()
    : isEnabled = true,
      rewardType = LoyaltyRewardType.visitCount,
      requiredVisits = 10,
      minimumOrderAmount = 500000,
      discountPercent = 25;

  factory LoyaltySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const LoyaltySettings.defaults();
    final requiredVisits = (data['requiredVisits'] as num?)?.toInt() ?? 10;
    final minimumOrderAmount =
        (data['minimumOrderAmount'] as num?)?.toInt() ?? 500000;
    final discountPercent =
        (data['discountPercent'] as num?)?.toInt() ?? 25;
    return LoyaltySettings(
      isEnabled: data['isEnabled'] as bool? ?? true,
      rewardType: data['rewardType'] == 'minimum_order'
          ? LoyaltyRewardType.minimumOrder
          : LoyaltyRewardType.visitCount,
      requiredVisits: requiredVisits < 1 ? 1 : requiredVisits,
      minimumOrderAmount: minimumOrderAmount < 1 ? 1 : minimumOrderAmount,
      discountPercent: discountPercent < 1
          ? 1
          : discountPercent > 100
          ? 100
          : discountPercent,
    );
  }

  String get rewardTypeValue => switch (rewardType) {
    LoyaltyRewardType.visitCount => 'visit_count',
    LoyaltyRewardType.minimumOrder => 'minimum_order',
  };
}
