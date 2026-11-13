import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:men_hair_booking/models/salon_assistant_reply.dart';
import 'package:men_hair_booking/screens/salon_assistant_screen.dart';
import 'package:men_hair_booking/services/salon_assistant_service.dart';
import 'package:men_hair_booking/services/scheduling_service.dart';

Map<String, dynamic> responseData() => {
  'message': 'Uốn tóc: 250.000đ · 120 phút. Giờ trống chưa được giữ chỗ.',
  'source': 'firebase-live',
  'checkedAt': '2026-11-13T00:00:00Z',
  'context': {
    'salonId': 'salon_01',
    'dateKey': '2026-11-14',
    'serviceIds': ['perm'],
  },
  'services': [
    {'id': 'perm', 'name': 'Uốn tóc', 'price': 250000, 'durationMinutes': 120},
  ],
  'recommendations': [
    {
      'employeeId': 'perm-worker',
      'name': 'Thợ uốn',
      'experienceYears': 4,
      'rating': 4.5,
      'reviewCount': 2,
      'matchingServices': ['Uốn tóc'],
      'times': ['09:00', '09:30'],
      'periods': [
        {'start': '07:00', 'end': '15:00'},
      ],
    },
  ],
};

void main() {
  testWidgets(
    'expertise cards and follow-up suggestions never imply staff are busy or booked',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = responseData();
      data['recommendationKind'] = 'expertise';
      data['message'] =
          'Mình đã xem chuyên môn trong hồ sơ. Bạn muốn mình xem lịch vào ngày nào?';
      data['suggestedQuestions'] = ['Kiểm tra giờ trống ngày mai'];
      final person = (data['recommendations'] as List).single as Map;
      person['times'] = <String>[];
      person['periods'] = <Map>[];
      person['salonName'] = '30Shine 345 Nguyễn Văn Linh';
      final questions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SalonAssistantScreen(
            ask: (question, context, history) async {
              questions.add(question);
              return SalonAssistantReply.fromMap(data);
            },
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'Thợ nào phù hợp với uốn tóc?',
      );
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gợi ý theo chuyên môn'), findsOneWidget);
      expect(find.textContaining('Ca làm:'), findsNothing);
      expect(find.text('Chọn giờ và đặt lịch'), findsNothing);
      final followUp = find.text('Kiểm tra giờ trống ngày mai');
      await tester.ensureVisible(followUp);
      await tester.tap(followUp);
      await tester.pumpAndSettle();
      expect(questions.last, 'Kiểm tra giờ trống ngày mai');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Authenticated online request sends context and only question history',
    () async {
      final service = SalonAssistantService(
        scheduling: SchedulingService.testing(
          emulatorEnabled: false,
          projectId: 'men-hair-booking',
          tokenProvider: () async => 'test-token',
          clientFactory: () => MockClient((request) async {
            expect(request.url.path, '/api/scheduling/askSalonAssistant');
            expect(request.headers['Authorization'], 'Bearer test-token');
            final data = (jsonDecode(request.body) as Map)['data'] as Map;
            expect(data['message'], 'Uốn tóc hôm nay');
            expect(data['context'], {'salonId': 'salon_01'});
            expect(data['history'], ['Giá bao nhiêu?']);
            return http.Response(
              jsonEncode({'result': responseData()}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final reply = await service.ask(
        'Uốn tóc hôm nay',
        {'salonId': 'salon_01'},
        ['Giá bao nhiêu?'],
      );
      expect(reply.services.single.price, 250000);
      expect(reply.recommendations.single['times'], ['09:00', '09:30']);
    },
  );

  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'Assistant shows grounded recommendations at width $width and preserves follow-ups',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            home: SalonAssistantScreen(
              ask: (question, context, history) async {
                calls.add({
                  'question': question,
                  'context': context,
                  'history': history,
                });
                return SalonAssistantReply.fromMap(responseData());
              },
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Hôm nay tôi uốn tóc');
        await tester.tap(find.byTooltip('Gửi câu hỏi'));
        await tester.pumpAndSettle();
        expect(find.text('Thợ uốn'), findsOneWidget);
        expect(find.text('Chuyên môn phù hợp: Uốn tóc'), findsOneWidget);
        expect(find.text('09:00'), findsOneWidget);
        expect(find.textContaining('250.000đ'), findsOneWidget);
        expect(find.text('Chọn giờ và đặt lịch'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'Buổi chiều thì sao?');
        await tester.tap(find.byTooltip('Gửi câu hỏi'));
        await tester.pumpAndSettle();
        final forwardedContext = Map<String, dynamic>.from(
          calls[1]['context'] as Map,
        );
        final turns = forwardedContext.remove('conversation') as List;
        expect(forwardedContext, responseData()['context']);
        expect((turns[0] as Map)['role'], 'user');
        expect((turns[1] as Map)['role'], 'assistant');
        expect((turns[1] as Map)['content'], responseData()['message']);
        expect(calls[1]['history'], ['Hôm nay tôi uốn tóc']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Duplicate requests disabled while waiting; failure retains question for retry',
    (tester) async {
      final pending = Completer<SalonAssistantReply>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SalonAssistantScreen(
            ask: (_, _, _) {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Giá uốn tóc');
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      expect(calls, 1);
      pending.completeError(
        const SchedulingRejectedException('AI hết hạn mức miễn phí'),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI hết hạn mức miễn phí'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Giá uốn tóc',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Leaving while AI responds does not update a disposed screen', (
    tester,
  ) async {
    final pending = Completer<SalonAssistantReply>();
    await tester.pumpWidget(
      MaterialApp(home: SalonAssistantScreen(ask: (_, _, _) => pending.future)),
    );
    await tester.enterText(find.byType(TextField), 'Ai làm hôm nay?');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpWidget(const SizedBox());
    pending.complete(SalonAssistantReply.fromMap(responseData()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
