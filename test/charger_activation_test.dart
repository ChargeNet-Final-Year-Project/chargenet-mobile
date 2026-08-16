import 'package:chargenet_mobile/data/load_state.dart';

import 'dart:async';

import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:chargenet_mobile/features/charging/charger_activation_screen.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A station + connector as `/evse/{uid}` reports them.
Station _station({String status = 'AVAILABLE', double maxPowerKw = 22}) {
  const stationId = 'stn_vlt_sgb';

  return Station(
    id: stationId,
    cpoId: 'cpo_voltgo',
    cpoName: 'VoltGo',
    cpoColorHex: '#0D9488',
    name: 'VoltGo Sungei Besi',
    address: 'Jalan Sungai Besi',
    city: 'Kuala Lumpur',
    latitude: 3.1221,
    longitude: 101.7031,
    totalBays: 4,
    availableBays: 2,
    isActive: true,
    connectors: [
      Connector(
        id: 'con_vlt_sgb_01',
        stationId: stationId,
        evseUid: KConstants.sampleEvseUid,
        standard: 'CCS2',
        format: 'CABLE',
        powerType: 'DC',
        maxPowerKw: maxPowerKw,
        tariffPerKwh: 1.6,
        status: status,
      ),
    ],
  );
}

/// The station's only connector.
Connector _connector({String status = 'AVAILABLE'}) =>
    _station(status: status).connectors.first;

Vehicle _vehicle({bool isDefault = true}) => Vehicle(
  id: 'veh_1',
  userId: 'usr_1',
  name: 'Atto 3',
  licensePlate: 'WXY 1234',
  connectorType: 'CCS2',
  batteryCapacity: 60.5,
  isDefault: isDefault,
);

ChargingSession _session() => const ChargingSession(
  id: 'ses_1',
  userId: 'usr_1',
  vehicleId: 'veh_1',
  cpoId: 'cpo_voltgo',
  cpoName: 'VoltGo',
  stationId: 'stn_vlt_sgb',
  stationName: 'VoltGo Sungei Besi',
  connectorId: 'con_vlt_sgb_01',
  evseUid: KConstants.sampleEvseUid,
  connectorType: 'CCS2',
  status: 'CHARGING',
  tariffPerKwh: 1.6,
);

/// A lookup that always finds the seeded EVSE.
Future<({Station station, Connector connector})> _found(String evseUid) async {
  final station = _station();
  return (station: station, connector: station.connectors.first);
}

Future<void> _pumpActivation(
  WidgetTester tester, {
  String? evseUid,
  EvseLookup lookupEvse = _found,
  SessionStarter? startSession,
  SessionStreamer? sessionStream,
  Future<ChargingQuote> Function(String, {String estimatedKwh})? loadQuote,
}) async {
  // Taller than the phone minimum so the whole confirm panel is on screen.
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: ChargerActivationScreen(
        evseUid: evseUid,
        lookupEvse: lookupEvse,
        loadQuote:
            loadQuote ??
            (uid, {estimatedKwh = '15'}) async => ChargingQuote(
              id: 'quote-test',
              tariffPerKwh: '1.60',
              originalCurrency: 'MYR',
              walletCurrency: 'MYR',
              exchangeRate: '1',
              equivalentTariff: '1.60',
              estimatedKwh: estimatedKwh,
              estimatedOriginalCost: (num.parse(estimatedKwh) * 1.6)
                  .toStringAsFixed(2),
              estimatedWalletCost: (num.parse(estimatedKwh) * 1.6)
                  .toStringAsFixed(2),
              budget: '85.50',
              rateSource: 'same-currency',
            ),
        startSession: startSession,
        sessionStream: sessionStream,
      ),
    ),
  );
}

/// Swipes the slide-to-start control and lets the request settle.
Future<void> _slideToStart(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(SlideToConfirm));
  await tester.drag(find.byType(SlideToConfirm), const Offset(1000, 0));
  await tester.pumpAndSettle();
}

/// Runs a widget test as if the app were on desktop, where the camera scanner
/// cannot run, so the screen takes the manual-entry path.
///
/// The platform override must be released before the body returns, otherwise
/// the test binding flags the changed foundation debug variable.
void testOnDesktop(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

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
      state.value = const DataLoadState.ready();
    }
  });

  setUp(() {
    walletBalanceNotifier.value = 0.0;
    vehiclesNotifier.value = [];
    activeSessionNotifier.value = null;
  });

  tearDown(() {
    walletBalanceNotifier.value = 0.0;
    vehiclesNotifier.value = [];
    activeSessionNotifier.value = null;
  });

  group('activation capabilities', () {
    test('the camera scanner only exists on Android and iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(ChargerActivationScreen.scannerSupported, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(ChargerActivationScreen.scannerSupported, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(ChargerActivationScreen.scannerSupported, isFalse);

      debugDefaultTargetPlatformOverride = null;
    });

    test('the seeded EVSE shortcut is offered where the camera cannot run', () {
      expect(
        ChargerActivationScreen.showSampleEvse(scannerUsable: true),
        isFalse,
        reason: 'a working camera is the path to walk',
      );
      expect(
        ChargerActivationScreen.showSampleEvse(scannerUsable: false),
        isTrue,
      );
    });
  });

  group('pre-charge rules', () {
    test('the wallet must hold the RM 10 minimum', () {
      expect(KConstants.minStartBalance, 10.0);
      expect(ChargerActivationScreen.hasEnoughBalance(10), isTrue);
      expect(ChargerActivationScreen.hasEnoughBalance(9.99), isFalse);
    });

    test('start needs an available connector and enough balance', () {
      expect(
        ChargerActivationScreen.canStart(connector: _connector(), balance: 50),
        isTrue,
      );
      expect(
        ChargerActivationScreen.canStart(
          connector: _connector(status: 'CHARGING'),
          balance: 50,
        ),
        isFalse,
      );
      expect(
        ChargerActivationScreen.canStart(connector: _connector(), balance: 5),
        isFalse,
      );
      expect(
        ChargerActivationScreen.canStart(connector: null, balance: 50),
        isFalse,
      );
    });

    test('blocker explains a busy connector and a thin wallet', () {
      expect(
        ChargerActivationScreen.blocker(connector: _connector(), balance: 50),
        isNull,
      );
      expect(
        ChargerActivationScreen.blocker(
          connector: _connector(status: 'CHARGING'),
          balance: 50,
        ),
        contains('charging'),
      );
      expect(
        ChargerActivationScreen.blocker(connector: _connector(), balance: 4),
        contains('RM 10.00'),
      );
    });

    test('estimates energy, time and cost from the charging formula', () {
      expect(
        ChargerActivationScreen.estimateKwh(
          batteryKwh: 60,
          fromSoc: 20,
          toSoc: 80,
        ),
        closeTo(36, 0.001),
      );
      expect(
        ChargerActivationScreen.estimateKwh(
          batteryKwh: 60,
          fromSoc: 80,
          toSoc: 80,
        ),
        0,
      );

      // 36 kWh at a 22 kW charger derated to 80 % ⇒ (36 / 17.6) * 60 minutes.
      expect(
        ChargerActivationScreen.estimateMinutes(kwh: 36, maxPowerKw: 22),
        closeTo(122.73, 0.01),
      );
      expect(
        ChargerActivationScreen.estimateMinutes(kwh: 36, maxPowerKw: 0),
        0,
      );

      expect(
        ChargerActivationScreen.estimateCost(kwh: 36, tariffPerKwh: 1.6),
        57.6,
      );
      expect(
        ChargerActivationScreen.estimateCost(kwh: 12.345, tariffPerKwh: 1.234),
        15.23,
      );
    });

    test('start failures are translated for the driver', () {
      expect(
        ChargerActivationScreen.errorMessage(
          const ApiException(402, 'INSUFFICIENT_BALANCE', 'Too low', {
            'required': 10.0,
          }),
        ),
        'Your wallet needs at least RM 10.00 to start.',
      );
      expect(
        ChargerActivationScreen.errorMessage(
          const ApiException(409, 'CONNECTOR_UNAVAILABLE', 'Taken'),
        ),
        contains('taken'),
      );
      expect(
        ChargerActivationScreen.errorMessage(
          const ApiException(409, 'SESSION_ALREADY_ACTIVE', 'Running'),
        ),
        contains('already have a charging session'),
      );
      expect(
        ChargerActivationScreen.errorMessage(
          const ApiException(404, 'EVSE_NOT_FOUND', 'Missing'),
        ),
        ChargerActivationScreen.notFoundMessage,
      );
      expect(
        ChargerActivationScreen.errorMessage(
          const ApiException(422, 'VALIDATION_ERROR', 'Invalid request', {
            'fields': {'targetSoc': 'Target must be between 50 and 100.'},
          }),
        ),
        'Target must be between 50 and 100.',
      );
      expect(
        ChargerActivationScreen.errorMessage(
          const ApiException(500, 'SERVER_ERROR', 'Boom'),
        ),
        'Boom',
      );

      final incompatible = ChargerActivationScreen.errorMessage(
        const ApiException(409, 'INCOMPATIBLE_CONNECTOR', 'Nope'),
        vehicle: _vehicle(),
        connector: _connector(),
      );
      expect(incompatible, contains('Atto 3'));
      expect(incompatible, contains('CCS2 (Type 2)'));
    });
  });

  group('confirm panel', () {
    testOnDesktop('a preselected EVSE goes straight to the confirm panel', (
      tester,
    ) async {
      walletBalanceNotifier.value = 85.5;
      vehiclesNotifier.value = [_vehicle()];
      String? asked;

      await _pumpActivation(
        tester,
        evseUid: KConstants.sampleEvseUid,
        lookupEvse: (uid) async {
          asked = uid;
          return _found(uid);
        },
      );
      await tester.pumpAndSettle();

      expect(asked, KConstants.sampleEvseUid);
      expect(find.text('Start charging'), findsOneWidget, reason: 'AppBar');
      expect(find.text('Charger details'), findsOneWidget);
      expect(find.text('VoltGo Sungei Besi'), findsOneWidget);
      expect(find.text('RM 1.60 / kWh'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget, reason: 'default target');
      expect(
        find.textContaining('RM 85.50'),
        findsNWidgets(2),
        reason: 'wallet funds and accepted spending limit',
      );
      expect(find.textContaining('Atto 3'), findsOneWidget);
      expect(find.text('Confirm and start'), findsOneWidget);
    });

    testOnDesktop('estimates the session for the chosen vehicle and target', (
      tester,
    ) async {
      walletBalanceNotifier.value = 85.5;
      vehiclesNotifier.value = [_vehicle()];

      await _pumpActivation(tester, evseUid: KConstants.sampleEvseUid);
      await tester.pumpAndSettle();

      // 60.5 kWh battery, 20 % → 80 % target, 22 kW connector, RM 1.60/kWh.
      expect(find.textContaining('About 36.3 kWh'), findsOneWidget);
      expect(find.textContaining('~124 min'), findsOneWidget);
      expect(find.textContaining('RM 58.08'), findsOneWidget);
    });

    testOnDesktop(
      'without a vehicle the default energy assumption is disclosed',
      (tester) async {
        walletBalanceNotifier.value = 85.5;
        vehiclesNotifier.value = [];

        await _pumpActivation(tester, evseUid: KConstants.sampleEvseUid);
        await tester.pumpAndSettle();

        expect(find.text('No vehicle'), findsOneWidget);
        expect(
          find.textContaining('The cost estimate assumes 15 kWh'),
          findsOneWidget,
        );
      },
    );

    testOnDesktop('a thin wallet disables the slide and offers a top-up', (
      tester,
    ) async {
      walletBalanceNotifier.value = 4.0;
      vehiclesNotifier.value = [_vehicle()];

      await _pumpActivation(tester, evseUid: KConstants.sampleEvseUid);
      await tester.pumpAndSettle();

      expect(find.textContaining('At least RM 10.00'), findsOneWidget);
      expect(
        find.textContaining('Top up to at least RM 10.00'),
        findsOneWidget,
      );
      expect(find.text('Top up'), findsOneWidget);

      final slider = tester.widget<SlideToConfirm>(find.byType(SlideToConfirm));
      expect(slider.enabled, isFalse);
    });

    testOnDesktop('a busy connector disables the slide', (tester) async {
      walletBalanceNotifier.value = 85.5;
      vehiclesNotifier.value = [_vehicle()];

      await _pumpActivation(
        tester,
        evseUid: KConstants.sampleEvseUid,
        lookupEvse: (uid) async => (
          station: _station(status: 'CHARGING'),
          connector: _connector(status: 'CHARGING'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('charging right now'), findsOneWidget);
      expect(
        tester.widget<SlideToConfirm>(find.byType(SlideToConfirm)).enabled,
        isFalse,
      );
    });

    testOnDesktop('a full slide starts the session and opens the monitor', (
      tester,
    ) async {
      walletBalanceNotifier.value = 85.5;
      vehiclesNotifier.value = [_vehicle()];

      String? startedUid;
      String? startedVehicle;
      int? startedTarget;

      // The monitor opens a live SSE stream by default; a controller keeps the
      // test offline (it never emits, so the screen simply sits and waits).
      final telemetry = StreamController<ChargingSession>.broadcast();

      await _pumpActivation(
        tester,
        evseUid: KConstants.sampleEvseUid,
        startSession: (uid, {vehicleId, targetSoc = 80}) async {
          startedUid = uid;
          startedVehicle = vehicleId;
          startedTarget = targetSoc;
          return _session();
        },
        sessionStream: (_) => telemetry.stream,
      );
      await tester.pumpAndSettle();

      await _slideToStart(tester);

      expect(startedUid, KConstants.sampleEvseUid);
      expect(startedVehicle, 'veh_1', reason: 'default vehicle is preselected');
      expect(startedTarget, 80);

      // the live monitor: the confirmation panel hands over to the light live monitor, which
      // mirrors the session into the notifier the dashboard mini-bar reads.
      expect(find.byType(ActiveChargingScreen), findsOneWidget);
      expect(find.text('VoltGo Sungei Besi'), findsOneWidget);
      expect(find.text(ActiveChargingScreen.stopLabel), findsOneWidget);
      expect(activeSessionNotifier.value?.id, 'ses_1');
    });

    testOnDesktop(
      'changed pricing requires confirmation again and never starts automatically',
      (tester) async {
        walletBalanceNotifier.value = 85.5;
        var estimates = 0;
        var starts = 0;
        final telemetry = StreamController<ChargingSession>.broadcast();
        addTearDown(telemetry.close);
        await _pumpActivation(
          tester,
          evseUid: KConstants.sampleEvseUid,
          loadQuote: (uid, {estimatedKwh = '15'}) async {
            estimates++;
            return ChargingQuote(
              id: 'estimate-$estimates',
              tariffPerKwh: estimates == 1 ? '1.6' : '2.0',
              originalCurrency: 'MYR',
              walletCurrency: 'MYR',
              exchangeRate: '1',
              equivalentTariff: estimates == 1 ? '1.6' : '2.0',
              estimatedKwh: '15',
              estimatedOriginalCost: estimates == 1 ? '24.00' : '30.00',
              estimatedWalletCost: estimates == 1 ? '24.00' : '30.00',
              budget: '85.50',
              rateSource: 'same-currency',
            );
          },
          startSession: (uid, {vehicleId, targetSoc = 80}) async {
            starts++;
            if (starts == 1) {
              throw const ApiException(
                409,
                'QUOTE_CHANGED',
                'Pricing has changed',
              );
            }
            return _session();
          },
          sessionStream: (_) => telemetry.stream,
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(days: 2));
        expect(
          estimates,
          1,
          reason: 'elapsed time never regenerates a valid estimate',
        );
        await _slideToStart(tester);
        expect(starts, 1);
        expect(estimates, 2);
        expect(find.text('RM 30.00'), findsOneWidget);
        expect(
          find.textContaining('Pricing has changed. Review'),
          findsOneWidget,
        );
        expect(find.byType(ActiveChargingScreen), findsNothing);
        await _slideToStart(tester);
        expect(starts, 2);
        expect(find.byType(ActiveChargingScreen), findsOneWidget);
      },
    );

    testOnDesktop('an already-running session offers the monitor instead', (
      tester,
    ) async {
      walletBalanceNotifier.value = 85.5;
      vehiclesNotifier.value = [_vehicle()];

      await _pumpActivation(
        tester,
        evseUid: KConstants.sampleEvseUid,
        startSession: (uid, {vehicleId, targetSoc = 80}) async =>
            throw const ApiException(
              409,
              'SESSION_ALREADY_ACTIVE',
              'Active session exists',
            ),
      );
      await tester.pumpAndSettle();

      await _slideToStart(tester);

      expect(
        find.text('You already have a charging session running.'),
        findsOneWidget,
      );
      expect(find.text('Go to active session'), findsOneWidget);
      expect(
        tester.widget<SlideToConfirm>(find.byType(SlideToConfirm)).enabled,
        isTrue,
        reason: 'the failed start frees the control again',
      );

      // Let the snackbar time out so no timer is left pending.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
    });
  });

  group('manual entry', () {
    testOnDesktop('opens on manual entry when no EVSE is preselected', (
      tester,
    ) async {
      await _pumpActivation(tester);
      await tester.pumpAndSettle();

      expect(find.text('Enter the charger code'), findsOneWidget);
      expect(find.text('Find charger'), findsOneWidget);
      expect(
        find.text('Scan a QR code instead'),
        findsNothing,
        reason: 'the scanner cannot run on this platform',
      );
      expect(find.byType(SlideToConfirm), findsNothing);
    });

    testOnDesktop('normalises the typed code before looking it up', (
      tester,
    ) async {
      String? asked;
      await _pumpActivation(
        tester,
        lookupEvse: (uid) async {
          asked = uid;
          return _found(uid);
        },
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  vlt-sgb-01 ');
      await tester.tap(find.text('Find charger'));
      await tester.pumpAndSettle();

      expect(asked, 'VLT-SGB-01');
      expect(find.text('VoltGo Sungei Besi'), findsOneWidget);
      expect(find.text('Confirm and start'), findsOneWidget);
    });

    testOnDesktop('refuses input that is not a ChargeNet code', (tester) async {
      var calls = 0;
      await _pumpActivation(
        tester,
        lookupEvse: (uid) async {
          calls++;
          return _found(uid);
        },
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/pricing',
      );
      await tester.tap(find.text('Find charger'));
      await tester.pumpAndSettle();

      expect(calls, 0, reason: 'no doomed lookup is fired');
      expect(find.text(ChargerActivationScreen.badCodeMessage), findsOneWidget);
    });

    testOnDesktop(
      'an unknown EVSE leaves the code in the field with a reason',
      (tester) async {
        await _pumpActivation(
          tester,
          evseUid: 'VLT-NOPE-99',
          lookupEvse: (uid) async =>
              throw const ApiException(404, 'EVSE_NOT_FOUND', 'EVSE not found'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(ChargerActivationScreen.notFoundMessage),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'VLT-NOPE-99',
        );
      },
    );

    testOnDesktop('the debug shortcut fills in the seeded EVSE', (
      tester,
    ) async {
      String? asked;
      await _pumpActivation(
        tester,
        lookupEvse: (uid) async {
          asked = uid;
          return _found(uid);
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Use sample EVSE'));
      await tester.pumpAndSettle();

      expect(asked, KConstants.sampleEvseUid);
      expect(find.text('Confirm and start'), findsOneWidget);
    });
  });
}
