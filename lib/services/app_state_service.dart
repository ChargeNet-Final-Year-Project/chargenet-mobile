import 'package:chargenet_mobile/services/session_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/services/api_service.dart';

/// Keeps global application state in sync with the backend.
class AppStateService {
  AppStateService._({ApiService? api}) : _api = api ?? ApiService.instance;

  @visibleForTesting
  factory AppStateService.withApi(ApiService api) =>
      AppStateService._(api: api);

  static final AppStateService instance = AppStateService._();

  final ApiService _api;
  static int _accountGeneration = 0;
  final Map<ValueNotifier<DataLoadState>, int> _requests = {};

  /// Cold start: load the stored token and resolve the current user.
  ///
  /// Any failure (no token, expired token, backend down) leaves the app signed
  /// out, which is the safe default.
  Future<void> bootstrap() async {
    await _api.init();
    if (!_api.isSignedIn) {
      authStateNotifier.value = AuthState.signedOut;
      return;
    }
    try {
      currentUserNotifier.value = await _api.me();
      authStateNotifier.value = AuthState.signedIn;
    } catch (_) {
      await signOut();
    }
  }

  /// Refreshes user-facing state in parallel and preserves successful results.
  Future<void> refreshAll() async {
    await Future.wait<void>([
      _guard(refreshWallet),
      _guard(refreshVehicles),
      _guard(refreshHistory),
      _guard(refreshTransactions),
      _guard(refreshCpos),
      _guard(refreshActiveSession),
    ]);
  }

  Future<void> refreshWallet() =>
      _load(walletLoadNotifier, _api.fetchWallet, (wallet) {
        walletCurrencyNotifier.value = wallet.currency;
        walletReservedNotifier.value = wallet.reserved;
        walletBalanceNotifier.value = wallet.balance;
      });

  Future<void> refreshVehicles() => _load(
    vehiclesLoadNotifier,
    _api.fetchVehicles,
    (vehicles) => vehiclesNotifier.value = vehicles,
  );

  static const int historyPageSize = 20;

  Future<void> refreshHistory() => _load(
    historyLoadNotifier,
    () => _api.getSessionHistory(limit: historyPageSize),
    (sessions) => sessionHistoryNotifier.value = sessions,
  );

  /// Returns the number of appended rows so callers can detect the last page.
  Future<int> loadMoreHistory() async {
    final account = _accountGeneration;
    final loaded = sessionHistoryNotifier.value;
    final page = await _api.getSessionHistory(
      limit: historyPageSize,
      offset: loaded.length,
    );
    if (account != _accountGeneration ||
        !identical(loaded, sessionHistoryNotifier.value)) {
      return 0;
    }
    sessionHistoryNotifier.value = [...loaded, ...page];
    return page.length;
  }

  Future<void> refreshTransactions() => _load(
    transactionsLoadNotifier,
    _api.fetchTransactions,
    (rows) => transactionsNotifier.value = rows,
  );

  Future<void> refreshCpos() => _load(
    cposLoadNotifier,
    _api.fetchCpos,
    (cpos) => cposNotifier.value = cpos,
  );

  Future<void> refreshActiveSession() =>
      _load(activeSessionLoadNotifier, _api.getActiveSession, (session) {
        final previous = activeSessionNotifier.value;
        if (session == null && previous != null) {
          // Absence from /active does not contain the final settlement amounts.
          SessionCoordinator.instance.reconcile();
        } else if (SessionCoordinator.instance.session != null &&
            session != null) {
          // The shared stream owns an observed charge. A slower /active read
          // must not overwrite fresh telemetry or revive its terminal session.
          SessionCoordinator.instance.watch(session);
        } else {
          activeSessionNotifier.value = session;
        }
      });

  Future<void> refreshAfterSession() async {
    await Future.wait<void>([
      _guard(refreshWallet),
      _guard(refreshHistory),
      _guard(refreshTransactions),
    ]);
  }

  Future<void> refreshAfterResume() async {
    await Future.wait<void>([
      _guard(refreshActiveSession),
      _guard(refreshWallet),
    ]);
  }

  Future<Wallet> topUp(double amount, String paymentMethod) async {
    final account = _accountGeneration;
    final wallet = await _api.topUp(amount, paymentMethod);
    if (account != _accountGeneration) return wallet;
    walletCurrencyNotifier.value = wallet.currency;
    walletReservedNotifier.value = wallet.reserved;
    walletBalanceNotifier.value = wallet.balance;
    walletLoadNotifier.value = DataLoadState(
      hasData: true,
      updatedAt: DateTime.now(),
    );
    await _guard(refreshTransactions);
    return wallet;
  }

  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final created = await _api.createVehicle(vehicle);
    await _guard(refreshVehicles);
    return created;
  }

  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final updated = await _api.updateVehicle(vehicle);
    await _guard(refreshVehicles);
    return updated;
  }

  /// Reloads the list because the server may promote another default vehicle.
  Future<void> deleteVehicle(String id) async {
    await _api.deleteVehicle(id);
    await _guard(refreshVehicles);
  }

  Future<ChargingSession> startSession(
    String evseUid, {
    String? vehicleId,
    int targetSoc = 80,
    String? quoteId,
  }) async {
    final account = _accountGeneration;
    final session = await _api.startSession(
      evseUid,
      vehicleId: vehicleId,
      targetSoc: targetSoc,
      quoteId: quoteId,
    );
    if (account != _accountGeneration) {
      throw StateError('Account changed during session start');
    }
    _requests[activeSessionLoadNotifier] =
        (_requests[activeSessionLoadNotifier] ?? 0) + 1;
    activeSessionNotifier.value = session;
    activeSessionLoadNotifier.value = DataLoadState(
      hasData: true,
      updatedAt: DateTime.now(),
    );
    return session;
  }

  /// Clears user state while retaining the public station catalogue.
  Future<void> signOut() async {
    clearUserState();
    authStateNotifier.value = AuthState.signedOut;
    await _api.clearToken();
  }

  static void clearUserState() {
    ++_accountGeneration;
    SessionCoordinator.instance.reset();
    currentUserNotifier.value = null;
    walletBalanceNotifier.value = 0.0;
    walletCurrencyNotifier.value = 'MYR';
    walletReservedNotifier.value = 0;
    activeSessionNotifier.value = null;
    vehiclesNotifier.value = [];
    sessionHistoryNotifier.value = [];
    transactionsNotifier.value = [];
    for (final state in [
      walletLoadNotifier,
      vehiclesLoadNotifier,
      historyLoadNotifier,
      transactionsLoadNotifier,
      activeSessionLoadNotifier,
    ]) {
      state.value = const DataLoadState();
    }
    authStateNotifier.value = AuthState.signedOut;
  }

  Future<void> _load<T>(
    ValueNotifier<DataLoadState> state,
    Future<T> Function() read,
    void Function(T) publish,
  ) async {
    final account = _accountGeneration;
    final request = (_requests[state] ?? 0) + 1;
    _requests[state] = request;
    bool current() =>
        account == _accountGeneration && _requests[state] == request;
    final previous = state.value;
    state.value = DataLoadState(
      hasData: previous.hasData,
      loading: true,
      error: previous.error,
      updatedAt: previous.updatedAt,
    );
    try {
      final value = await read();
      if (!current()) return;
      publish(value);
      state.value = DataLoadState(hasData: true, updatedAt: DateTime.now());
    } catch (error) {
      if (!current()) return;
      state.value = DataLoadState(
        hasData: previous.hasData,
        updatedAt: previous.updatedAt,
        error: error is ApiException
            ? error.message
            : 'Could not reach ChargeNet. Please try again.',
      );
      rethrow;
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Leave the notifier untouched; the screen keeps its last good value.
    }
  }
}
