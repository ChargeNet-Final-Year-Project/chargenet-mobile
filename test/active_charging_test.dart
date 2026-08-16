import 'package:chargenet_mobile/data/load_state.dart';

import 'dart:async';

import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:chargenet_mobile/features/charging/stop_reason.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_progress.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A snapshot as the telemetry stream / `/sessions/{id}` reports it.
ChargingSession _session({
  String status = 'CHARGING',
  double? soc = 42,
  double? powerKw = 60,
  double? kwh = 6.2,
  int? durationSeconds = 300,
  double? targetSoc = 80,
  double? totalCost,
  double? balanceAfter,
  String? stopReason,
}) => ChargingSession(
  id: 'ses_1',
  userId: 'usr_1',
  vehicleId: 'veh_1',
  cpoId: 'cpo_voltgo',
  cpoName: 'VoltGo',
  stationId: 'stn_vlt_sgb',
  stationName: 'VoltGo Sungei Besi',
  connectorId: 'con_vlt_sgb_01',
  evseUid: 'VLT-SGB-01',
  connectorType: 'CCS2',
  status: status,
  durationSeconds: durationSeconds,
  kwhDelivered: kwh,
  currentPowerKw: powerKw,
  batterySoc: soc,
  targetSoc: targetSoc,
  tariffPerKwh: 1.6,
  totalCost: totalCost,
  balanceAfter: balanceAfter,
  stopReason: stopReason,
);

/// Pumps the monitor against a fake telemetry stream and hands back the
/// controller the test pushes snapshots into.
///
/// Broadcast on purpose: the screen re-subscribes when the app comes back to
/// the foreground, which a single-subscription stream refuses.
Future<StreamController<ChargingSession>> _pumpMonitor(
  WidgetTester tester, {
  ChargingSession? session,
  SessionStopper? stopSession,
  SessionRefresher? refreshState,
  SessionFinished? onFinished,
}) async {
  // Taller than the phone minimum so the whole monitor is on screen.
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final telemetry = StreamController<ChargingSession>.broadcast();

  await tester.pumpWidget(
    MaterialApp(
      home: ActiveChargingScreen(
        session: session ?? _session(),
        streamSession: (_) => telemetry.stream,
        stopSession: stopSession,
        refreshState: refreshState ?? () async {},
        onFinished: onFinished,
      ),
    ),
  );
  await tester.pump();

  return telemetry;
}

/// Pushes one real telemetry snapshot.
Future<void> _emit(
  WidgetTester tester,
  StreamController<ChargingSession> telemetry,
  ChargingSession snapshot,
) async {
  telemetry.add(snapshot);
  await tester.pump();
  await tester.pump();
  await tester.pump(ActiveChargingScreen.animDuration);
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
    activeSessionNotifier.value = null;
    dashboardTabNotifier.value = DashboardTab.home;
  });

  tearDown(() {
    activeSessionNotifier.value = null;
    dashboardTabNotifier.value = DashboardTab.home;
  });

  group('telemetry formatters', () {
    test('formatClock renders the simulated duration as a clock', () {
      expect(formatClock(null), '00:00:00');
      expect(formatClock(0), '00:00:00');
      expect(formatClock(872), '00:14:32');
      expect(formatClock(3725), '01:02:05');
      expect(formatClock(-4), '00:00:00');
    });

    test('formatPercent rounds, and reads "unknown" for null', () {
      expect(formatPercent(null), kNoValue);
      expect(formatPercent(58.4), '58%');
      expect(formatPercent(80), '80%');
    });
  });

  group('stop reasons', () {
    test('every reason the backend can send has words', () {
      expect(stopReasonLabel(null), isNull);
      expect(stopReasonLabel(''), isNull);
      expect(stopReasonLabel('TARGET_SOC_REACHED'), 'Target charge reached');
      expect(stopReasonLabel('BALANCE_EXHAUSTED'), 'Wallet balance used up');
      expect(stopReasonLabel('USER_STOPPED'), 'You stopped the session');
      expect(stopReasonLabel('REMOTE_STOPPED'), 'Stopped at the charge point');
      expect(stopReasonLabel('EVSE_FAULT'), 'Charger reported a fault');
    });

    test('an unknown code degrades instead of leaking a backend enum', () {
      expect(stopReasonLabel('SOMETHING_NEW'), 'Charger stopped');
    });
  });

  group('live monitor', () {
    testWidgets(
      'lays out the charger, battery progress and labelled readings',
      (tester) async {
        await _pumpMonitor(tester);

        // Header.
        expect(find.text('VoltGo Sungei Besi'), findsOneWidget);
        expect(find.text('VoltGo · VLT-SGB-01'), findsOneWidget);
        expect(find.text('CCS2'), findsOneWidget);
        expect(find.text('Charging'), findsOneWidget);

        // Ring and headline power.
        expect(find.byType(ChargingProgress), findsOneWidget);
        expect(find.text('42%'), findsOneWidget);
        expect(find.text('Battery'), findsOneWidget);
        expect(find.text('60.0 kW'), findsOneWidget);
        expect(find.text('Charging speed'), findsOneWidget);

        // Stats, tariff and target.
        expect(find.text('Energy added'), findsOneWidget);
        expect(find.text('6.2 kWh'), findsOneWidget);
        expect(find.text('Duration'), findsOneWidget);
        expect(find.text('00:05:00'), findsOneWidget);
        expect(find.text('Cost'), findsOneWidget);
        expect(find.text('RM 9.92'), findsOneWidget); // 6.2 kWh × RM 1.60
        expect(find.text('RM 1.60 / kWh'), findsOneWidget);
        expect(find.text('Charging to 80 %'), findsOneWidget);

        expect(find.text(ActiveChargingScreen.stopLabel), findsOneWidget);

        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          closeTo(0.42, 1e-9),
        );
      },
    );

    testWidgets('mirrors the session into the shared notifier', (tester) async {
      await _pumpMonitor(tester);

      // This is what the dashboard mini-bar and `GET /sessions/active` read.
      expect(activeSessionNotifier.value?.id, 'ses_1');
      expect(activeSessionNotifier.value?.evseUid, 'VLT-SGB-01');
    });

    testWidgets('three telemetry frames move the %, kW and kWh', (
      tester,
    ) async {
      final telemetry = await _pumpMonitor(tester);
      expect(find.text('42%'), findsOneWidget);

      await _emit(
        tester,
        telemetry,
        _session(soc: 51, powerKw: 88.4, kwh: 12.1, durationSeconds: 640),
      );
      expect(find.text('51%'), findsOneWidget);
      expect(find.text('88.4 kW'), findsOneWidget);
      expect(find.text('12.1 kWh'), findsOneWidget);

      await _emit(
        tester,
        telemetry,
        _session(soc: 58, powerKw: 124.5, kwh: 22.4, durationSeconds: 872),
      );
      expect(find.text('58%'), findsOneWidget);
      expect(find.text('124.5 kW'), findsOneWidget);
      expect(find.text('22.4 kWh'), findsOneWidget);
      expect(find.text('00:14:32'), findsOneWidget);

      await _emit(
        tester,
        telemetry,
        _session(soc: 80, powerKw: 40.2, kwh: 36.3, durationSeconds: 1500),
      );
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('40.2 kW'), findsOneWidget);
      expect(find.text('36.3 kWh'), findsOneWidget);
      expect(find.text('00:25:00'), findsOneWidget);

      expect(activeSessionNotifier.value?.batterySoc, 80);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.8, 1e-9),
      );
    });

    testWidgets('a just-started session reads "unknown", never zero', (
      tester,
    ) async {
      await _pumpMonitor(
        tester,
        session: _session(
          soc: null,
          powerKw: null,
          kwh: null,
          durationSeconds: null,
        ),
      );

      // State of charge, power, energy, duration and cost are all missing.
      expect(find.text(kNoValue), findsNWidgets(5));
      expect(find.text('0.0 kW'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Waiting for battery reading'), findsOneWidget);
    });

    testWidgets(
      'completion dismisses only its own pending confirmation before the receipt',
      (tester) async {
        final telemetry = await _pumpMonitor(
          tester,
          onFinished: (context, session) async {
            await showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Terminal receipt'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
        await tester.tap(find.text('Stop charging with confirmation'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await _emit(tester, telemetry, _session(status: 'COMPLETED'));
        await tester.pumpAndSettle();
        expect(find.text('Terminal receipt'), findsOneWidget);
        expect(find.text('Stop charging'), findsNothing);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(activeSessionNotifier.value, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a terminal frame ends the session and shows the receipt', (
      tester,
    ) async {
      var refreshed = false;
      final telemetry = await _pumpMonitor(
        tester,
        refreshState: () async {
          refreshed = true;
        },
      );

      await _emit(
        tester,
        telemetry,
        _session(
          status: 'COMPLETED',
          soc: 80,
          powerKw: 0,
          kwh: 36.3,
          durationSeconds: 1500,
          totalCost: 58.08,
          balanceAfter: 26.92,
          stopReason: 'TARGET_SOC_REACHED',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        activeSessionNotifier.value,
        isNull,
        reason: 'nothing is running any more',
      );
      expect(refreshed, isTrue, reason: 'wallet and history are refreshed');

      // the receipt's itemised receipt, carrying the terminal snapshot's numbers.
      expect(find.text('Charging complete'), findsOneWidget);
      expect(find.text('Target charge reached'), findsOneWidget);
      expect(find.byKey(ChargingReceipt.dividerKey), findsOneWidget);
      expect(find.text('Energy delivered'), findsOneWidget);
      expect(
        find.text('36.300 kWh'),
        findsOneWidget,
        reason: 'the receipt prints three decimals',
      );
      expect(find.text('Paid from wallet'), findsOneWidget);
      expect(find.text('Remaining balance'), findsOneWidget);
      expect(find.text('RM 26.92'), findsOneWidget);
      expect(
        find.text('Receipt no.'),
        findsNothing,
        reason: 'the backend has not issued a CDR for it',
      );
      expect(find.text('RM 58.08'), findsWidgets); // monitor stats + receipt

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Charging complete'), findsNothing);
      expect(
        dashboardTabNotifier.value,
        DashboardTab.activity,
        reason: 'the finished session is now a history row',
      );
    });

    testWidgets('the finish presenter receives the terminal session', (
      tester,
    ) async {
      ChargingSession? handedOver;
      final telemetry = await _pumpMonitor(
        tester,
        onFinished: (context, session) async {
          handedOver = session;
        },
      );

      await _emit(
        tester,
        telemetry,
        _session(status: 'COMPLETED', stopReason: 'TARGET_SOC_REACHED'),
      );
      await tester.pumpAndSettle();

      expect(handedOver?.status, 'COMPLETED');
      expect(
        find.text('Charging complete'),
        findsNothing,
        reason: 'the injected presenter replaces the receipt',
      );
      expect(activeSessionNotifier.value, isNull);
      expect(dashboardTabNotifier.value, DashboardTab.activity);
    });

    testWidgets('sliding to stop asks the backend and blocks the screen', (
      tester,
    ) async {
      final completion = Completer<ChargingSession>();
      String? stoppedId;
      final telemetry = await _pumpMonitor(
        tester,
        stopSession: (sessionId) {
          stoppedId = sessionId;
          return completion.future;
        },
      );

      await tester.drag(find.byType(SlideToConfirm), const Offset(1000, 0));
      await tester.pump();

      expect(stoppedId, 'ses_1');
      expect(find.text(ActiveChargingScreen.finishingLabel), findsOneWidget);

      completion.complete(
        _session(
          status: 'COMPLETED',
          soc: 60,
          powerKw: 0,
          kwh: 22.4,
          durationSeconds: 872,
          totalCost: 35.84,
          balanceAfter: 49.16,
          stopReason: 'USER_STOPPED',
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(ActiveChargingScreen.finishingLabel), findsNothing);
      expect(find.text('Charging complete'), findsOneWidget);
      expect(find.text('You stopped the session'), findsOneWidget);
      expect(activeSessionNotifier.value, isNull);

      // The monitor cancelled the stream, so a late frame cannot repaint it.
      telemetry.add(_session(soc: 99));
      await tester.pump();
      expect(find.text('99%'), findsNothing);
    });

    testWidgets('a rejected stop re-arms the slide and explains why', (
      tester,
    ) async {
      await _pumpMonitor(
        tester,
        stopSession: (_) async => throw const ApiException(
          0,
          'NETWORK_ERROR',
          'Could not reach ChargeNet. Check your connection and try again.',
        ),
      );

      await tester.drag(find.byType(SlideToConfirm), const Offset(1000, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not reach ChargeNet. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text(ActiveChargingScreen.finishingLabel), findsNothing);
      expect(
        tester.widget<SlideToConfirm>(find.byType(SlideToConfirm)).enabled,
        isTrue,
        reason: 'the failed stop frees the control again',
      );
      expect(
        activeSessionNotifier.value?.id,
        'ses_1',
        reason: 'the session is still running',
      );

      // Let the snackbar time out so no timer is left pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a dropped stream and missing session never fabricate completion',
      (tester) async {
        final telemetry = await _pumpMonitor(tester);

        telemetry.addError(
          const ApiException(503, 'CPO_UNREACHABLE', 'offline'),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(ActiveChargingScreen.reconnectLabel), findsOneWidget);

        await _emit(tester, telemetry, _session(soc: 47));
        expect(find.text(ActiveChargingScreen.reconnectLabel), findsNothing);
        expect(find.text('47%'), findsOneWidget);

        telemetry.addError(
          const ApiException(404, 'SESSION_NOT_FOUND', 'Session gone'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Charging complete'), findsNothing);
        expect(activeSessionNotifier.value?.id, 'ses_1');
      },
    );

    testWidgets(
      'stream exhaustion retains the active session without a receipt',
      (tester) async {
        final telemetry = await _pumpMonitor(tester);
        await telemetry.close();
        await tester.pumpAndSettle();
        expect(find.text('Charging complete'), findsNothing);
        expect(activeSessionNotifier.value?.id, 'ses_1');
        expect(find.text('Retry live updates'), findsOneWidget);
      },
    );

    testWidgets('coming back to the foreground re-opens the stream', (
      tester,
    ) async {
      final telemetry = await _pumpMonitor(tester);
      expect(find.text('42%'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // The screen re-subscribed, so the next frame still lands.
      await _emit(
        tester,
        telemetry,
        _session(soc: 66, powerKw: 70, kwh: 18.5, durationSeconds: 700),
      );

      expect(find.text('66%'), findsOneWidget);
      expect(find.text('70.0 kW'), findsOneWidget);
      expect(find.text('00:11:40'), findsOneWidget);
    });
  });
}
