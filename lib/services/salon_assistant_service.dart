import '../models/salon_assistant_reply.dart';
import 'scheduling_service.dart';

class SalonAssistantService {
  SalonAssistantService({SchedulingService? scheduling})
    : _scheduling =
          scheduling ??
          SchedulingService(requestTimeout: const Duration(seconds: 60));
  final SchedulingService _scheduling;

  Future<SalonAssistantReply> ask(
    String message,
    Map<String, dynamic> context,
    List<String> history,
  ) async {
    try {
      return SalonAssistantReply.fromMap(
        await _scheduling.call('askSalonAssistant', {
          'message': message,
          'context': Map<String, dynamic>.of(context)..remove('conversation'),
          'conversation': context['conversation'] ?? const [],
          'history': history,
        }),
      );
    } on SchedulingTimeoutException {
      throw const SchedulingRejectedException(
        'Tra cứu đang mất nhiều thời gian. Bạn thử lại sau nhé; chưa có lịch nào được đặt.',
      );
    }
  }
}
