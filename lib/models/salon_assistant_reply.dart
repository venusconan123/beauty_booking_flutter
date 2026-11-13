import 'hair_service.dart';

class SalonAssistantReply {
  const SalonAssistantReply({
    required this.message,
    required this.context,
    required this.services,
    required this.recommendations,
    required this.checkedAt,
    this.suggestedQuestions = const [],
    this.recommendationKind = 'availability',
  });
  final String message;
  final Map<String, dynamic> context;
  final List<HairService> services;
  final List<Map<String, dynamic>> recommendations;
  final DateTime checkedAt;
  final List<String> suggestedQuestions;
  final String recommendationKind;

  factory SalonAssistantReply.fromMap(Map<String, dynamic> data) {
    if (data['message'] is! String ||
        data['context'] is! Map ||
        data['source'] != 'firebase-live') {
      throw const FormatException('Phản hồi trợ lý không hợp lệ.');
    }
    return SalonAssistantReply(
      message: data['message'] as String,
      context: Map<String, dynamic>.from(data['context'] as Map),
      services: (data['services'] as List? ?? []).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return HairService.fromMap(row['id'] as String, row);
      }).toList(),
      recommendations: (data['recommendations'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      checkedAt: DateTime.parse(data['checkedAt'] as String),
      recommendationKind:
          data['recommendationKind'] as String? ?? 'availability',
      suggestedQuestions: (data['suggestedQuestions'] as List? ?? [])
          .whereType<String>()
          .take(3)
          .toList(),
    );
  }
}
