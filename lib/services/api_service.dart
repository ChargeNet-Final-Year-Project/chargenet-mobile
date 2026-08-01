import 'package:chargenet_mobile/features/home/station_filter.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/services/token_storage.dart';

/// Single JSON client for the ChargeNet mobile API.
///
/// * every call is bounded by [KConstants.requestTimeout];
/// * any non-2xx response becomes an [ApiException] carrying the server's error
///   envelope (`{"error":{code,message,…}}`);
/// * a 401 outside of login/register drops the stored token and flips
///   [authStateNotifier] to [AuthState.signedOut] so the app gate routes back
///   to the login screen;
/// * `topUp` and `startSession` send a fresh `Idempotency-Key` so a retry can
///   never double-charge the wallet.
class ApiService {
  ApiService._({http.Client? client}) : _client = client ?? http.Client();

  static final ApiService instance = ApiService._();

  /// Creates a service with an injected client for tests.
  @visibleForTesting
  factory ApiService.withClient(http.Client client) =>
      ApiService._(client: client);

  static final String _base = '${KConstants.apiBaseUrl}${KConstants.apiPrefix}';
  static final Random _random = Random();

  final http.Client _client;
  String? _token;

  String get baseUrl => _base;

  /// Raw bearer token. Only [SessionStreamService] needs it, because it opens
  /// its own request in order to consume the body as a stream.
  String? get token => _token;

  bool get isSignedIn => _token != null;

  Future<void> init() async {
    _token = await TokenStorage.instance.read();
  }

  Future<void> setToken(String token) async {
    _token = token;
    await TokenStorage.instance.write(token);
  }

  /// Sets the bearer token in memory only, without touching the keystore.
  /// Tests use it to exercise an authenticated call; the app persists the token
  /// with [setToken].
  @visibleForTesting
  void useToken(String? token) => _token = token;

  Future<void> clearToken() async {
    _token = null;
    await TokenStorage.instance.delete();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Creates an account (and its wallet) and returns the fresh credentials.
  ///
  /// The caller decides when to persist the token via [setToken].
  Future<({String token, AppUser user})> register({
    required String name,
    required String email,
    required String password,
    String walletCurrency = 'MYR',
  }) async {
    final res = await _send(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'walletCurrency': walletCurrency,
      },
      handleUnauthorized: false,
    );
    return _authResult(res);
  }

  Future<({String token, AppUser user})> login({
    required String email,
    required String password,
  }) async {
    final res = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      handleUnauthorized: false,
    );
    return _authResult(res);
  }

  Future<AppUser> me() async {
    final res = await _send('GET', '/auth/me');
    return AppUser.fromJson(_decodeObject(res));
  }

  ({String token, AppUser user}) _authResult(http.Response res) {
    final json = _decodeObject(res);
    return (
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Future<List<CpoPartner>> fetchCpos() async {
    final res = await _send('GET', '/cpos');
    return _decodeList(res).map(CpoPartner.fromJson).toList();
  }

  /// Nearby stations.
  ///
  /// When [lat] and [lng] are supplied the server fills `distanceKm` and sorts
  /// by distance; [radiusKm] narrows the search around that point.
  Future<List<Station>> fetchStations({
    String? query,
    String? country,
    String? region,
    String? powerType,
    double? maxPowerKw,
    String? connectorType,
    String? cpoId,
    bool availableOnly = false,
    double? minPowerKw,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final hasOrigin = lat != null && lng != null;
    final res = await _send(
      'GET',
      '/stations',
      query: {
        'country': ?country,
        'region': ?region,
        'powerType': ?powerType,
        if (maxPowerKw != null) 'maxPower': '$maxPowerKw',
        if (query != null && query.isNotEmpty) 'query': query,
        if (connectorType != null && connectorType.isNotEmpty)
          'connectorType': connectorType,
        if (cpoId != null && cpoId.isNotEmpty) 'cpoId': cpoId,
        if (availableOnly) 'availableOnly': 'true',
        if (minPowerKw != null) 'minPower': '$minPowerKw',
        if (hasOrigin) 'lat': '$lat',
        if (hasOrigin) 'lng': '$lng',
        if (hasOrigin && radiusKm != null) 'radiusKm': '$radiusKm',
      },
    );
    return _decodeList(res).map(Station.fromJson).toList();
  }

  Future<List<StationRegion>> fetchStationRegions() async {
    final res = await _send('GET', '/stations/regions');
    return _decodeList(res).map(StationRegion.fromJson).toList();
  }

  Future<Station> fetchStation(String id) async {
    final res = await _send('GET', '/stations/${Uri.encodeComponent(id)}');
    return Station.fromJson(_decodeObject(res));
  }

  /// Resolves a scanned QR payload or a manually typed EVSE uid.
  Future<({Station station, Connector connector})> lookupEvse(
    String evseUid,
  ) async {
    final res = await _send('GET', '/evse/${Uri.encodeComponent(evseUid)}');
    final json = _decodeObject(res);
    return (
      station: Station.fromJson(json['station'] as Map<String, dynamic>),
      connector: Connector.fromJson(json['connector'] as Map<String, dynamic>),
    );
  }

  Future<Wallet> fetchWallet() async {
    final res = await _send('GET', '/wallet');
    return Wallet.fromJson(_decodeObject(res));
  }

  /// Simulated top-up (5–2000 RM). Idempotent: retrying with the same key is
  /// impossible because a fresh key is generated per call, and a caller that
  /// needs to retry safely should catch the failure and call this again.
  Future<Wallet> topUp(double amount, String paymentMethod) async {
    final res = await _send(
      'POST',
      '/wallet/topup',
      body: {'amount': amount, 'paymentMethod': paymentMethod},
      headers: {'Idempotency-Key': _newIdempotencyKey()},
    );
    return Wallet.fromJson(_decodeObject(res));
  }

  Future<List<WalletTransaction>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _send(
      'GET',
      '/wallet/transactions',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _decodeList(res).map(WalletTransaction.fromJson).toList();
  }

  Future<List<Vehicle>> fetchVehicles() async {
    final res = await _send('GET', '/vehicles');
    return _decodeList(res).map(Vehicle.fromJson).toList();
  }

  Future<Vehicle> createVehicle(Vehicle v) async {
    final res = await _send('POST', '/vehicles', body: v.toJson());
    return Vehicle.fromJson(_decodeObject(res));
  }

  Future<Vehicle> updateVehicle(Vehicle v) async {
    final res = await _send(
      'PUT',
      '/vehicles/${Uri.encodeComponent(v.id)}',
      body: v.toJson(),
    );
    return Vehicle.fromJson(_decodeObject(res));
  }

  Future<void> deleteVehicle(String id) async {
    await _send('DELETE', '/vehicles/${Uri.encodeComponent(id)}');
  }

  Future<ChargingQuote> createQuote(
    String evseUid, {
    String estimatedKwh = '15',
  }) async {
    final response = await _send(
      'POST',
      '/quotes',
      body: {'evseUid': evseUid, 'estimatedKwh': estimatedKwh},
    );
    return ChargingQuote.fromJson(_decodeObject(response));
  }

  /// Carries an `Idempotency-Key` so a flaky network cannot start (and later
  /// bill) two sessions for one user tap.
  Future<ChargingSession> startSession(
    String evseUid, {
    String? vehicleId,
    int targetSoc = 80,
    String? quoteId,
  }) async {
    final res = await _send(
      'POST',
      '/sessions/start',
      body: {
        'evseUid': evseUid,
        'quoteId': ?quoteId,
        'targetSoc': targetSoc,
        'vehicleId': ?vehicleId,
      },
      headers: {'Idempotency-Key': _newIdempotencyKey()},
    );
    return ChargingSession.fromJson(_decodeObject(res));
  }

  /// Stops a session. Idempotent server-side: stopping a completed session
  /// returns it unchanged.
  Future<ChargingSession> stopSession(String sessionId) async {
    final res = await _send(
      'POST',
      '/sessions/${Uri.encodeComponent(sessionId)}/stop',
    );
    return ChargingSession.fromJson(_decodeObject(res));
  }

  /// The user's running session, or `null` when there is none (`404`).
  Future<ChargingSession?> getActiveSession() async {
    try {
      final res = await _send('GET', '/sessions/active');
      return ChargingSession.fromJson(_decodeObject(res));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ChargingSession> getSession(String id) async {
    final res = await _send('GET', '/sessions/${Uri.encodeComponent(id)}');
    return ChargingSession.fromJson(_decodeObject(res));
  }

  /// Completed/failed sessions, newest first.
  Future<List<ChargingSession>> getSessionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _send(
      'GET',
      '/sessions/history',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _decodeList(res).map(ChargingSession.fromJson).toList();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String> headers = const {},
    bool handleUnauthorized = true,
  }) async {
    final requestToken = _token;
    final base = Uri.parse('$_base$path');
    final uri = (query == null || query.isEmpty)
        ? base
        : base.replace(queryParameters: query);
    final allHeaders = {..._headers, ...headers};
    final encoded = body == null ? null : jsonEncode(body);

    final future = switch (method) {
      'GET' => _client.get(uri, headers: allHeaders),
      'POST' => _client.post(uri, headers: allHeaders, body: encoded),
      'PUT' => _client.put(uri, headers: allHeaders, body: encoded),
      'DELETE' => _client.delete(uri, headers: allHeaders, body: encoded),
      _ => throw ArgumentError('Unsupported HTTP method: $method'),
    };

    http.Response res;
    try {
      res = await future.timeout(KConstants.requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        0,
        'NETWORK_ERROR',
        'ChargeNet took too long to respond. Please try again.',
      );
    } catch (_) {
      throw const ApiException(
        0,
        'NETWORK_ERROR',
        'Could not reach ChargeNet. Check your connection and try again.',
      );
    }

    if (handleUnauthorized && requestToken != _token) {
      throw const ApiException(
        0,
        'ACCOUNT_CHANGED',
        'Account changed during the request.',
      );
    }
    _checkStatus(res, handleUnauthorized: handleUnauthorized);
    return res;
  }

  void _checkStatus(http.Response res, {required bool handleUnauthorized}) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    if (handleUnauthorized && res.statusCode == 401) {
      // The stored token is expired or revoked: drop it so the app gate routes
      // back to login. Fire-and-forget — the caller still gets the error.
      AppStateService.clearUserState();
      unawaited(clearToken());
      authStateNotifier.value = AuthState.signedOut;
    }
    throw _toApiException(res);
  }

  ApiException _toApiException(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map) {
          final extra = <String, dynamic>{...error}
            ..remove('code')
            ..remove('message');
          return ApiException(
            res.statusCode,
            '${error['code'] ?? 'UNKNOWN'}',
            '${error['message'] ?? 'Something went wrong.'}',
            extra,
          );
        }
      }
    } catch (_) {
      // Not JSON (proxy error page, truncated body, …); fall through.
    }
    return ApiException(
      res.statusCode,
      'UNKNOWN',
      res.body.isEmpty ? 'Something went wrong.' : res.body,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;

  List<Map<String, dynamic>> _decodeList(http.Response res) =>
      (jsonDecode(res.body) as List<dynamic>).cast<Map<String, dynamic>>();

  static String _newIdempotencyKey() {
    final suffix = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'cn-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}

/// Raised for every non-2xx response.
class ApiException implements Exception {
  final int statusCode;

  /// Machine-readable code from the server, e.g. `INSUFFICIENT_BALANCE`.
  /// `NETWORK_ERROR` / `UNKNOWN` are produced client-side.
  final String code;

  final String message;

  /// The rest of the error object: `fields`, `required`, `balance`, …
  final Map<String, dynamic> extra;

  const ApiException(
    this.statusCode,
    this.code,
    this.message, [
    this.extra = const {},
  ]);

  /// Per-field validation messages (`VALIDATION_ERROR` responses).
  Map<String, String> get fields {
    final raw = extra['fields'];
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry('$key', '$value'));
  }

  /// Minimum balance a rejected start needs (`INSUFFICIENT_BALANCE`).
  double? get required => (extra['required'] as num?)?.toDouble();

  /// Wallet balance at the moment of failure (`INSUFFICIENT_BALANCE`).
  double? get balance => (extra['balance'] as num?)?.toDouble();

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}
