// Opt in explicitly: flutter test --dart-define=RUN_LIVE_AI_TEST=true
// test/salon_assistant_live_test.dart
// Uses Firebase/Workers AI online. Creates/removes one unprivileged test Auth
// account; never changes customer data, staff accounts, shifts or payments.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:men_hair_booking/firebase_options.dart';
import 'package:men_hair_booking/models/salon_assistant_reply.dart';
import 'package:men_hair_booking/screens/salon_assistant_screen.dart';
import 'package:men_hair_booking/services/salon_assistant_service.dart';
import 'package:men_hair_booking/services/scheduling_service.dart';

class _NetworkAccess extends HttpOverrides {
  HttpClient createRealClient() => super.createHttpClient(null);
}

void main() {
  testWidgets(
    'live app question renders Firebase prices from Workers AI',
    (tester) async {
      final client = IOClient(_NetworkAccess().createRealClient());
      String? token;
      final key = DefaultFirebaseOptions.web.apiKey;
      final identity = 'https://identitytoolkit.googleapis.com/v1/accounts';
      Future<Map<String, dynamic>> auth(
        String method,
        Map<String, dynamic> data,
      ) async {
        final response = await client
            .post(
              Uri.parse('$identity:$method?key=$key'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 30));
        expect(
          response.statusCode,
          200,
          reason: 'Temporary test Auth operation: $method',
        );
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }

      try {
        await tester.runAsync(() async {
          final nonce =
              '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
          final signup = await auth('signUp', {
            'email': 'ai-ui-$nonce@example.test',
            'password': 'Test-${Random.secure().nextInt(1 << 30)}-$nonce!',
            'returnSecureToken': true,
          });
          token = signup['idToken'] as String;
        });
        SalonAssistantReply? actual;
        Object? failure;
        final service = SalonAssistantService(
          scheduling: SchedulingService.testing(
            emulatorEnabled: false,
            projectId: 'men-hair-booking',
            tokenProvider: () async => token,
            clientFactory: () => IOClient(_NetworkAccess().createRealClient()),
            requestTimeout: const Duration(seconds: 60),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: SalonAssistantScreen(
              ask: (question, context, history) async {
                try {
                  final reply = await service.ask(question, context, history);
                  actual = reply;
                  return reply;
                } catch (error) {
                  failure = error;
                  rethrow;
                }
              },
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextField),
          'Uốn tóc bao nhiêu tiền, làm bao lâu?',
        );
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Gửi câu hỏi'));
          final wait = Stopwatch()..start();
          while (actual == null &&
              failure == null &&
              wait.elapsed < const Duration(seconds: 65)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump(const Duration(milliseconds: 50));
          }
        });
        expect(failure, isNull);
        expect(
          actual,
          isNotNull,
          reason: 'Live UI must receive a response within 65 seconds',
        );
        await tester.pumpAndSettle();
        expect(actual!.services.single.name, 'Uốn tóc');
        expect(actual!.context['topic'], 'prices');
        expect(find.text(actual!.message), findsOneWidget);
        expect(find.textContaining('phút'), findsOneWidget);
        expect(find.textContaining('Đã tra dữ liệu lúc'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          if (token != null) await auth('delete', {'idToken': token});
          client.close();
        });
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_AI_TEST'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
