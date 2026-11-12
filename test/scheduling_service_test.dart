import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:men_hair_booking/services/scheduling_service.dart';

void main() {
  test(
    'production Spark backend uses HTTPS and retains authentication and request ID',
    () async {
      final seen = <Uri>[];
      final client = _Client((request) async {
        seen.add(request.url);
        expect(request.headers['Authorization'], 'Bearer local-test');
        final body =
            jsonDecode(await request.finalize().bytesToString()) as Map;
        expect(body['data']['requestId'], 'stable-production-request');
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"result":{"ok":true}}')),
          200,
        );
      });
      final service = SchedulingService.testing(
        emulatorEnabled: false,
        projectId: 'men-hair-booking',
        tokenProvider: () async => 'local-test',
        clientFactory: () => client,
      );
      for (final name in [
        'createBooking',
        'saveRoster',
        'linkStaffAccount',
        'createStaffAccount',
        'recordBookingPayment',
        'getBarberRatings',
      ]) {
        expect(
          await service.call(name, {'requestId': 'stable-production-request'}),
          {'ok': true},
        );
        expect(
          seen.last.toString(),
          'https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling/$name',
        );
      }
      expect(client.closed, isTrue);
    },
  );

  test('unknown callable cannot become an injected endpoint', () async {
    final service = SchedulingService.testing(
      clientFactory: () => throw StateError('must not open transport'),
      tokenProvider: () async => 'local-test',
    );
    await expectLater(service.call('../other', {}), throwsArgumentError);
  });

  test(
    'lost response closes client; retry keeps payload/id and recovers one committed shift',
    () async {
      final mutation = SchedulingMutation('saveShifts', {
        'dates': ['2030-01-02'],
      });
      final receipts = <String, Map<String, dynamic>>{};
      final clients = <_Client>[];
      var attempts = 0;
      final service = SchedulingService.testing(
        // Leave real scheduling headroom for token retrieval on busy CI hosts;
        // the first HTTP response intentionally never completes.
        requestTimeout: const Duration(milliseconds: 500),
        tokenProvider: () async => 'emulator-test-token',
        clientFactory: () {
          final client = _Client((request) async {
            final data =
                (jsonDecode(await request.finalize().bytesToString())
                        as Map)['data']
                    as Map;
            final id = data['requestId'] as String;
            receipts.putIfAbsent(
              id,
              () => {
                'shiftIds': ['one-shift'],
              },
            );
            if (attempts++ == 0) {
              return Completer<http.StreamedResponse>().future;
            }
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'result': receipts[id]}))),
              200,
            );
          });
          clients.add(client);
          return client;
        },
      );
      await expectLater(
        service.call(mutation.name, mutation.data),
        throwsA(isA<SchedulingTimeoutException>()),
      );
      expect(clients.single.closed, isTrue);
      final changedCopy = mutation.data;
      changedCopy['dates'] = ['different'];
      expect(mutation.data['dates'], ['2030-01-02']);
      final recovered = await service.call(mutation.name, mutation.data);
      expect(recovered['shiftIds'], ['one-shift']);
      expect(receipts.length, 1);
      expect(clients.every((c) => c.closed), isTrue);
    },
  );
  test('timeout while obtaining token never sends a late mutation', () async {
    final token = Completer<String?>();
    var sent = 0;
    final client = _Client((_) async {
      sent++;
      throw StateError('must not send');
    });
    final service = SchedulingService.testing(
      clientFactory: () => client,
      tokenProvider: () => token.future,
      requestTimeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      service.call('saveShifts', {'requestId': 'auth-timeout'}),
      throwsA(isA<SchedulingTimeoutException>()),
    );
    token.complete('late-token');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(sent, 0);
    expect(client.closed, isTrue);
  });
  test('a definitive backend rejection also closes transport', () async {
    final client = _Client(
      (_) async => http.StreamedResponse(
        Stream.value(utf8.encode('{"error":{"message":"Không có quyền"}}')),
        403,
      ),
    );
    final service = SchedulingService.testing(
      clientFactory: () => client,
      tokenProvider: () async => 'test',
    );
    await expectLater(
      service.call('saveShifts', {'requestId': 'denied'}),
      throwsA(isA<SchedulingRejectedException>()),
    );
    expect(client.closed, isTrue);
  });
  test('request identifiers are unique and use a web-safe random bound', () {
    final ids = List.generate(100, (_) => SchedulingService.requestId());
    expect(ids.toSet().length, 100);
    expect(ids.every((id) => RegExp(r'^\d+_\d+$').hasMatch(id)), isTrue);
  });
  test('recurrence selects weekdays in chosen month including leap day', () {
    final dates = SchedulingService.recurringDates(DateTime(2028, 2), {2});
    expect(dates, [
      '2028-02-01',
      '2028-02-08',
      '2028-02-15',
      '2028-02-22',
      '2028-02-29',
    ]);
    expect(
      SchedulingService.recurringDates(DateTime(2026, 11), {}).isEmpty,
      isTrue,
    );
    expect(
      SchedulingService.recurringDates(DateTime(2026, 11), {
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      }).length,
      30,
    );
  });
}

class _Client extends http.BaseClient {
  _Client(this.handle);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handle;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handle(request);
  @override
  void close() {
    closed = true;
    super.close();
  }
}
