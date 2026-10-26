import 'dart:async';
import 'dart:convert';

import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    for (final state in [
      walletLoadNotifier,
      vehiclesLoadNotifier,
      historyLoadNotifier,
      transactionsLoadNotifier,
      cposLoadNotifier,
      activeSessionLoadNotifier,
    ]) {
      state.value = const DataLoadState();
    }
    walletBalanceNotifier.value = 0;
  });
  test(
    'a failed wallet does not turn successful empty slices into failures',
    () async {
      final api = ApiService.withClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/wallet')) {
            return http.Response(
              jsonEncode({
                'error': {'code': 'UNAVAILABLE', 'message': 'Wallet offline'},
              }),
              503,
            );
          }
          if (request.url.path.endsWith('/sessions/active')) {
            return http.Response(
              jsonEncode({
                'error': {'code': 'NOT_FOUND', 'message': 'No session'},
              }),
              404,
            );
          }
          return http.Response('[]', 200);
        }),
      );
      await AppStateService.withApi(api).refreshAll();
      expect(walletLoadNotifier.value.hasData, isFalse);
      expect(walletLoadNotifier.value.error, 'Wallet offline');
      for (final state in [
        vehiclesLoadNotifier,
        historyLoadNotifier,
        transactionsLoadNotifier,
        cposLoadNotifier,
        activeSessionLoadNotifier,
      ]) {
        expect(state.value.hasData, isTrue);
        expect(state.value.error, isNull);
        expect(state.value.updatedAt, isNotNull);
      }
    },
  );
  test(
    'zero becomes valid after success and remains labelled stale after failure',
    () async {
      var offline = false;
      final api = ApiService.withClient(
        MockClient(
          (_) async => offline
              ? http.Response(
                  jsonEncode({
                    'error': {'code': 'UNAVAILABLE', 'message': 'Offline'},
                  }),
                  503,
                )
              : http.Response(
                  jsonEncode({
                    'id': 'wallet-review',
                    'userId': 'driver',
                    'balance': 0,
                    'currency': 'MYR',
                  }),
                  200,
                ),
        ),
      );
      final service = AppStateService.withApi(api);
      await service.refreshWallet();
      final updated = walletLoadNotifier.value.updatedAt;
      expect(walletLoadNotifier.value.hasData, isTrue);
      expect(walletBalanceNotifier.value, 0);
      offline = true;
      await expectLater(service.refreshWallet(), throwsA(isA<ApiException>()));
      expect(walletLoadNotifier.value.hasData, isTrue);
      expect(walletLoadNotifier.value.updatedAt, updated);
      expect(walletLoadNotifier.value.error, 'Offline');
      expect(walletBalanceNotifier.value, 0);
    },
  );
  test('settlement refresh includes the transaction ledger', () async {
    final paths = <String>[];
    final api = ApiService.withClient(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/wallet')) {
          return http.Response(
            jsonEncode({
              'id': 'wallet',
              'userId': 'driver',
              'balance': 42,
              'currency': 'MYR',
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    await AppStateService.withApi(api).refreshAfterSession();
    expect(
      paths,
      containsAll([
        '/api/v1/wallet',
        '/api/v1/wallet/transactions',
        '/api/v1/sessions/history',
      ]),
    );
    expect(transactionsLoadNotifier.value.hasData, isTrue);
  });

  test('account cleanup rejects an old successful wallet response', () async {
    final response = Completer<http.Response>();
    final api = ApiService.withClient(MockClient((_) => response.future));
    final pending = AppStateService.withApi(api).refreshWallet();
    AppStateService.clearUserState();
    response.complete(
      http.Response(
        jsonEncode({
          'id': 'old',
          'userId': 'old',
          'balance': 999,
          'currency': 'MYR',
        }),
        200,
      ),
    );
    await pending;
    expect(walletBalanceNotifier.value, 0);
    expect(walletLoadNotifier.value.hasData, isFalse);
  });
}
