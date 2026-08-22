import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/services/api_service.dart';

/// Session statuses after which a session never changes again.
const Set<String> sessionTerminalStatuses = {'COMPLETED', 'FAILED'};

bool isSessionTerminal(String status) =>
    sessionTerminalStatuses.contains(status);

/// The backend sends keepalives every 15 seconds.
const Duration sseIdleTimeout = Duration(seconds: 20);

/// Fails [bytes] after [idle] so a stalled socket can fall back to polling.
Stream<List<int>> watchdogSseBytes(
  Stream<List<int>> bytes, {
  Duration idle = sseIdleTimeout,
}) => bytes.timeout(
  idle,
  onTimeout: (sink) => sink.addError(
    TimeoutException('No SSE traffic for ${idle.inMilliseconds} ms.', idle),
  ),
);

/// Parses a `text/event-stream` byte stream into [ChargingSession] snapshots.
///
/// * each `event: telemetry` frame yields one snapshot;
/// * the final `event: completed` frame yields its snapshot and closes the
///   returned stream;
/// * comments (`: keepalive`), unknown events and unparseable payloads are
///   skipped silently — a single bad frame must not kill the monitor screen.
Stream<ChargingSession> parseSessionEvents(
  Stream<List<int>> byteStream,
) async* {
  var event = '';
  final data = <String>[];

  await for (final line
      in byteStream.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      final completed = event == 'completed';
      final session = _decodeFrame(event, data);
      event = '';
      data.clear();
      if (session != null) yield session;
      if (completed) return;
      continue;
    }
    if (line.startsWith(':')) continue; // comment, e.g. `: keepalive`
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') {
      event = value;
    } else if (field == 'data') {
      data.add(value);
    }
  }

  // Keep a final frame even when the connection closes before its blank line.
  final tail = _decodeFrame(event, data);
  if (tail != null) yield tail;
}

ChargingSession? _decodeFrame(String event, List<String> data) {
  if (data.isEmpty) return null;
  if (event.isNotEmpty && event != 'telemetry' && event != 'completed') {
    return null;
  }
  try {
    final json = jsonDecode(data.join('\n'));
    if (json is! Map<String, dynamic>) return null;
    return ChargingSession.fromJson(json);
  } catch (_) {
    return null;
  }
}

/// Live telemetry for one charging session.
///
/// The primary transport is the SSE endpoint. If it drops, never opens, or goes
/// silent for longer than [sseIdleTimeout] before the session finishes, the
/// stream transparently falls back to polling `GET /sessions/{id}` every two
/// seconds until a terminal status arrives.
class SessionStreamService {
  SessionStreamService._();

  static final SessionStreamService instance = SessionStreamService._();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPollFailures = 5;

  /// Emits snapshots until the session reaches a terminal status.
  Stream<ChargingSession> streamSession(String sessionId) async* {
    final seeded = await _seed(sessionId);
    if (seeded != null) {
      yield seeded;
      if (isSessionTerminal(seeded.status)) return;
    }

    var finished = false;
    try {
      await for (final session in _sseFrames(sessionId)) {
        yield session;
        if (isSessionTerminal(session.status)) finished = true;
      }
    } catch (_) {
      // Connection refused/dropped/stalled: degrade to polling below.
    }
    if (finished) return;
    yield* _poll(sessionId);
  }

  Future<ChargingSession?> _seed(String sessionId) async {
    try {
      return await ApiService.instance.getSession(sessionId);
    } catch (_) {
      return null;
    }
  }

  Stream<ChargingSession> _sseFrames(String sessionId) async* {
    final api = ApiService.instance;
    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('${api.baseUrl}/sessions/$sessionId/stream'),
      )..headers['Accept'] = 'text/event-stream';
      final token = api.token;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final response = await client
          .send(request)
          .timeout(KConstants.requestTimeout);
      if (response.statusCode != 200) {
        throw ApiException(
          response.statusCode,
          'STREAM_FAILED',
          'Live telemetry is unavailable.',
        );
      }
      yield* parseSessionEvents(watchdogSseBytes(response.stream));
    } finally {
      client.close();
    }
  }

  /// Polls immediately and continues until the session is terminal.
  Stream<ChargingSession> _poll(String sessionId) async* {
    final api = ApiService.instance;
    var failures = 0;
    while (true) {
      try {
        final session = await api.getSession(sessionId);
        failures = 0;
        yield session;
        if (isSessionTerminal(session.status)) return;
      } on ApiException catch (e) {
        // 404 → session gone, 401 → handled by ApiService (signed out).
        if (e.statusCode == 404 || e.statusCode == 401) return;
        if (++failures >= _maxPollFailures) rethrow;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }
}
