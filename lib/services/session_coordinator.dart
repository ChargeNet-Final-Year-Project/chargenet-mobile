import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:chargenet_mobile/services/session_stream_service.dart';

/// Owns a charge independently of the monitor route. Transport loss never
/// authorizes settlement, clearing the charge, or a successful receipt.
class SessionCoordinator extends ChangeNotifier {
  SessionCoordinator({
    required this.streamSession,
    required this.stopSession,
    required this.refreshState,
    this.getSession,
    this.getActiveSession,
    this.publishConnection,
    void Function(ChargingSession?)? publish,
  }) : _publish = publish ?? _publishGlobal;

  static final instance = SessionCoordinator(
    streamSession: SessionStreamService.instance.streamSession,
    stopSession: ApiService.instance.stopSession,
    getSession: ApiService.instance.getSession,
    getActiveSession: ApiService.instance.getActiveSession,
    refreshState: AppStateService.instance.refreshAfterSession,
    publishConnection: (message) => sessionConnectionNotifier.value = message,
  );

  final Stream<ChargingSession> Function(String) streamSession;
  final Future<ChargingSession> Function(String) stopSession;
  final Future<ChargingSession> Function(String)? getSession;
  final Future<ChargingSession?> Function()? getActiveSession;
  final Future<void> Function() refreshState;
  final void Function(String?)? publishConnection;
  final void Function(ChargingSession?) _publish;
  static void _publishGlobal(ChargingSession? session) =>
      activeSessionNotifier.value = session;

  ChargingSession? session;
  ChargingSession? _receipt;
  StreamSubscription<ChargingSession>? _subscription;
  final Set<String> _completed = {};
  int _generation = 0;
  int _revision = 0;
  bool interrupted = false;
  bool unavailable = false;
  bool stopping = false;
  bool _reconciling = false;

  bool get hasReceipt => _receipt != null;

  void _notify() {
    publishConnection?.call(
      interrupted ? 'Updates interrupted · last known readings' : null,
    );
    notifyListeners();
  }

  ChargingSession? takeReceipt() {
    final receipt = _receipt;
    _receipt = null;
    return receipt;
  }

  void watch(ChargingSession value) {
    if (_completed.contains(value.id)) return;
    if (session?.id == value.id) return;
    session = value;
    _publish(value);
    _receipt = null;
    interrupted = false;
    unavailable = false;
    retry();
  }

  void retry() {
    final current = session;
    if (current == null || _completed.contains(current.id)) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _reconciling = false;
    _subscription = streamSession(current.id).listen(
      (value) {
        if (generation != _generation || value.id != current.id) return;
        _accept(value);
      },
      onError: (Object error) => _interrupt(generation, error),
      onDone: () => _interrupt(generation, null),
    );
    _notify();
  }

  void _accept(ChargingSession value) {
    if (_completed.contains(value.id)) return;
    ++_revision;
    session = value;
    interrupted = false;
    unavailable = false;
    if (isSessionTerminal(value.status)) {
      _completed.add(value.id);
      ++_generation;
      unawaited(_subscription?.cancel());
      _subscription = null;
      _receipt = value;
      stopping = false;
      _publish(null);
      unawaited(refreshState().catchError((Object _) {}));
    } else {
      _publish(value);
    }
    _notify();
  }

  void reconcile() => _interrupt(_generation, null);

  void _interrupt(int generation, Object? error) {
    if (generation != _generation) return;
    interrupted = true;
    unavailable = error is ApiException && error.statusCode == 404;
    _notify();
    unawaited(_reconcile(generation));
  }

  Future<void> _reconcile(int generation) async {
    final current = session;
    if (_reconciling || current == null || getSession == null) return;
    _reconciling = true;
    final revision = _revision;
    try {
      final snapshot = await getSession!(current.id);
      if (generation != _generation) return;
      if (revision != _revision && !isSessionTerminal(snapshot.status)) return;
      _accept(snapshot);
      // A REST snapshot is fresh, but it does not restore the live transport.
      if (!isSessionTerminal(snapshot.status)) interrupted = true;
    } on ApiException catch (error) {
      if (generation != _generation) return;
      if (error.statusCode == 404) {
        unavailable = true;
        ChargingSession? active;
        try {
          active = await getActiveSession?.call();
        } catch (_) {
          return;
        }
        if (generation != _generation) return;
        if (revision != _revision) return;
        if (active != null) {
          if (active.id == current.id) {
            _accept(active);
            interrupted = true;
          } else {
            watch(active);
          }
        }
      }
    } catch (_) {
      // Keep the last known charge and the interruption visible.
    } finally {
      if (generation == _generation) {
        _reconciling = false;
        _notify();
      }
    }
  }

  Future<void> stop() async {
    final current = session;
    if (current == null || stopping || _completed.contains(current.id)) return;
    final generation = _generation;
    stopping = true;
    _notify();
    try {
      final ended = await stopSession(current.id);
      if (generation != _generation || ended.id != current.id) return;
      _accept(ended);
      if (!isSessionTerminal(ended.status)) interrupted = true;
    } finally {
      if (generation == _generation) {
        stopping = false;
        _notify();
      }
    }
  }

  void reset() {
    ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    session = null;
    _receipt = null;
    _completed.clear();
    stopping = false;
    interrupted = false;
    unavailable = false;
    _reconciling = false;
    publishConnection?.call(null);
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
