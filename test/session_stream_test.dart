import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/services/session_stream_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSessionEvents', () {
    test('emits each telemetry frame, then completed, then closes', () async {
      final body =
          ': keepalive\n\n'
          '${_frame('telemetry', _session('CHARGING', soc: 41.0))}'
          '${_frame('telemetry', _session('CHARGING', soc: 52.0))}'
          '${_frame('completed', _session('COMPLETED', soc: 80.0))}'
          // Anything after `completed` must be ignored.
          '${_frame('telemetry', _session('CHARGING', soc: 99.0))}';

      final sessions = await parseSessionEvents(_bytes(body)).toList();

      expect(sessions, hasLength(3));
      expect(sessions.map((s) => s.batterySoc).toList(), <double>[
        41.0,
        52.0,
        80.0,
      ]);
      expect(sessions.last.status, 'COMPLETED');
    });

    test('reassembles frames split across many byte chunks', () async {
      final body =
          _frame('telemetry', _session('CHARGING', soc: 30.0)) +
          _frame('completed', _session('COMPLETED', soc: 80.0));

      final sessions = await parseSessionEvents(_bytes(body, chunkSize: 3))
          .toList();

      expect(sessions, hasLength(2));
      expect(sessions.first.batterySoc, 30.0);
    });

    test('accepts CRLF line endings', () async {
      final framed = _frame(
        'telemetry',
        _session('CHARGING', soc: 12.0),
      ).replaceAll('\n', '\r\n');

      final sessions = await parseSessionEvents(_bytes(framed)).toList();

      expect(sessions, hasLength(1));
      expect(sessions.single.batterySoc, 12.0);
    });

    test('ignores comments, unknown events and bad payloads', () async {
      final body =
          ': keepalive\n\n'
          ': another comment\n'
          'event: heartbeat\ndata: {"status":"CHARGING"}\n\n'
          'event: telemetry\ndata: {not json}\n\n'
          'event: telemetry\ndata: ${jsonEncode(_session('CHARGING'))}\n\n';

      final sessions = await parseSessionEvents(_bytes(body)).toList();

      expect(sessions, hasLength(1));
      expect(sessions.single.status, 'CHARGING');
    });

    test('emits a final frame that arrived without its blank line', () async {
      // Connection dropped right after the last `data:` line.
      final body =
          '${_frame('telemetry', _session('CHARGING', soc: 55.0))}'
          'event: telemetry\n'
          'data: ${jsonEncode(_session('CHARGING', soc: 61.0))}';

      final sessions = await parseSessionEvents(_bytes(body)).toList();

      expect(sessions, hasLength(2));
      expect(sessions.last.batterySoc, 61.0);
    });

    test('a comment-only stream closes without emitting', () async {
      final sessions = await parseSessionEvents(_bytes(': keepalive\n\n'))
          .toList();

      expect(sessions, isEmpty);
    });
  });

  group('watchdogSseBytes', () {
    test('a silent connection fails with a TimeoutException, after its frames',
        () async {
      // The socket dies without ever erroring: one frame, then nothing at all.
      // The monitor must learn about it so the polling fallback can take over
      // instead of freezing on the snapshot the screen was opened with.
      final ctrl = StreamController<List<int>>();
      addTearDown(ctrl.close);

      final sessions = <ChargingSession>[];
      final errors = <Object>[];
      final done = Completer<void>();
      parseSessionEvents(
        watchdogSseBytes(ctrl.stream, idle: const Duration(milliseconds: 50)),
      ).listen(
        sessions.add,
        onError: errors.add,
        onDone: done.complete,
        cancelOnError: false,
      );

      ctrl.add(utf8.encode(_frame('telemetry', _session('CHARGING', soc: 30.0))));
      await done.future.timeout(const Duration(seconds: 5));

      expect(sessions.map((s) => s.batterySoc).toList(), <double?>[30.0]);
      expect(errors, hasLength(1));
      expect(errors.single, isA<TimeoutException>());
    });

    test('keepalive traffic keeps the watchdog from firing', () async {
      final ctrl = StreamController<List<int>>();
      final chunks = <List<int>>[];
      final errors = <Object>[];
      final sub = watchdogSseBytes(
        ctrl.stream,
        idle: const Duration(milliseconds: 50),
      ).listen(chunks.add, onError: errors.add);

      // Four comments 20 ms apart: each chunk resets the 50 ms window, so the
      // stream stays alive for twice the idle window.
      for (var i = 0; i < 4; i++) {
        ctrl.add(utf8.encode(': keepalive\n\n'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await sub.cancel();
      await ctrl.close();

      expect(errors, isEmpty);
      expect(chunks, hasLength(4));
    });

    test('the default window outlasts the backend keepalive', () {
      // The backend writes `: keepalive` every 15 s, so a
      // shorter window would tear down a healthy stream.
      expect(sseIdleTimeout, greaterThan(const Duration(seconds: 15)));
    });
  });

  group('isSessionTerminal', () {
    test('only COMPLETED and FAILED are terminal', () {
      expect(isSessionTerminal('COMPLETED'), isTrue);
      expect(isSessionTerminal('FAILED'), isTrue);
      expect(isSessionTerminal('CHARGING'), isFalse);
      expect(isSessionTerminal('PENDING'), isFalse);
    });
  });
}

/// One SSE frame with a single `data:` line.
String _frame(String event, Map<String, dynamic> data) =>
    'event: $event\ndata: ${jsonEncode(data)}\n\n';

/// Feeds [body] as UTF-8 in fixed-size chunks (default: one big chunk).
Stream<List<int>> _bytes(String body, {int chunkSize = 1 << 16}) async* {
  final encoded = utf8.encode(body);
  for (var i = 0; i < encoded.length; i += chunkSize) {
    yield encoded.sublist(i, math.min(i + chunkSize, encoded.length));
  }
}

Map<String, dynamic> _session(String status, {double soc = 40.0}) =>
    <String, dynamic>{
      'id': 'ses_1',
      'userId': 'usr_demo',
      'vehicleId': null,
      'cpoId': 'cpo_voltgo',
      'cpoName': 'VoltGo',
      'stationId': 'stn_1',
      'stationName': 'VoltGo Sungai Buloh R&R',
      'connectorId': 'con_1',
      'evseUid': 'VLT-SGB-01',
      'connectorType': 'CCS2',
      'status': status,
      'startTime': '2026-10-06T22:00:00.000Z',
      'endTime': status == 'COMPLETED' ? '2026-10-06T22:30:00.000Z' : null,
      'durationSeconds': 1800,
      'kwhDelivered': 12.5,
      'currentPowerKw': 74.0,
      'batterySoc': soc,
      'targetSoc': 80.0,
      'tariffPerKwh': 1.4,
      'totalCost': 17.5,
      'balanceAfter': null,
      'stopReason': null,
      'cdrId': null,
      'cdrJson': null,
    };
