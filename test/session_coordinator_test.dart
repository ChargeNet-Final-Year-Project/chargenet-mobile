import 'dart:async';

import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/session_coordinator.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/layout_fixtures.dart';

ChargingSession frame({
  String id = 'charge',
  String status = 'CHARGING',
  double soc = 42,
}) => ChargingSession.fromJson({
  ...layoutSession.toJson(),
  'id': id,
  'status': status,
  'batterySoc': soc,
});

void main() {
  test(
    'terminal snapshot settles once despite stop and late-frame races',
    () async {
      final stream = StreamController<ChargingSession>.broadcast();
      final stopped = Completer<ChargingSession>();
      var refreshes = 0;
      var stops = 0;
      final owner = SessionCoordinator(
        streamSession: (_) => stream.stream,
        stopSession: (_) {
          stops++;
          return stopped.future;
        },
        refreshState: () async {
          refreshes++;
        },
      );
      owner.watch(frame());
      final stopping = owner.stop();
      await owner.stop();
      stream.add(frame(status: 'COMPLETED'));
      await Future<void>.delayed(Duration.zero);
      stopped.complete(frame(status: 'COMPLETED'));
      await stopping;
      expect(stops, 1);
      expect(refreshes, 1);
      expect(owner.takeReceipt()?.status, 'COMPLETED');
      expect(owner.takeReceipt(), isNull);
      owner.watch(frame());
      stream.add(frame());
      await Future<void>.delayed(Duration.zero);
      expect(owner.session?.status, 'COMPLETED');
      owner.dispose();
      await stream.close();
    },
  );

  test(
    '404 reconciliation retains uncertainty and retry can confirm failure',
    () async {
      final stream = StreamController<ChargingSession>.broadcast();
      var missing = true;
      final owner = SessionCoordinator(
        streamSession: (_) => stream.stream,
        stopSession: (_) async => frame(),
        refreshState: () async {},
        getSession: (_) async {
          if (missing) throw const ApiException(404, 'MISSING', 'Missing');
          return frame(status: 'FAILED');
        },
        getActiveSession: () async => null,
      );
      owner.watch(frame());
      stream.addError(const ApiException(404, 'MISSING', 'Missing'));
      await Future<void>.delayed(Duration.zero);
      expect(owner.unavailable, isTrue);
      expect(owner.interrupted, isTrue);
      expect(owner.hasReceipt, isFalse);
      expect(activeSessionNotifier.value?.id, isNotNull);
      missing = false;
      owner.reconcile();
      await Future<void>.delayed(Duration.zero);
      expect(owner.takeReceipt()?.status, 'FAILED');
      expect(activeSessionNotifier.value, isNull);
      owner.dispose();
      await stream.close();
    },
  );

  test(
    'replacement and account reset ignore old stream and reconciliation',
    () async {
      final stream = StreamController<ChargingSession>.broadcast();
      final response = Completer<ChargingSession>();
      final published = <ChargingSession?>[];
      final owner = SessionCoordinator(
        streamSession: (_) => stream.stream,
        stopSession: (_) async => frame(),
        getSession: (_) => response.future,
        refreshState: () async {},
        publish: published.add,
      );
      owner.watch(frame());
      stream.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      owner.watch(frame(id: 'new-account-session'));
      stream.add(frame(status: 'COMPLETED'));
      owner.reset();
      published.clear();
      response.complete(frame(status: 'COMPLETED'));
      await Future<void>.delayed(Duration.zero);
      expect(published, isEmpty);
      expect(owner.session, isNull);
      expect(owner.hasReceipt, isFalse);
      owner.dispose();
      await stream.close();
    },
  );

  testWidgets(
    'minimising preserves one owner; reopening uses fresh telemetry',
    (tester) async {
      final stream = StreamController<ChargingSession>.broadcast();
      var subscriptions = 0;
      final owner = SessionCoordinator(
        streamSession: (_) {
          subscriptions++;
          return stream.stream;
        },
        stopSession: (_) async => frame(status: 'COMPLETED'),
        refreshState: () async {},
      );
      owner.watch(frame());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ActiveChargingScreen(
                      session: frame(),
                      coordinator: owner,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Minimise'));
      await tester.pumpAndSettle();
      stream.add(frame(soc: 66));
      await tester.pump();
      expect(activeSessionNotifier.value?.batterySoc, 66);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('66%'), findsOneWidget);
      expect(subscriptions, 1);
      await tester.pumpWidget(const SizedBox());
      owner.dispose();
      await stream.close();
      activeSessionNotifier.value = null;
    },
  );
  test('a nonterminal stop response cannot authorize a receipt', () async {
    final stream = StreamController<ChargingSession>.broadcast();
    final owner = SessionCoordinator(
      streamSession: (_) => stream.stream,
      stopSession: (_) async => frame(),
      refreshState: () async {},
    );
    owner.watch(frame());
    await owner.stop();
    expect(owner.hasReceipt, isFalse);
    expect(owner.interrupted, isTrue);
    expect(activeSessionNotifier.value?.status, 'CHARGING');
    owner.dispose();
    await stream.close();
    activeSessionNotifier.value = null;
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'interrupted monitor keeps Stop and Retry usable at $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final stream = StreamController<ChargingSession>.broadcast();
          final owner = SessionCoordinator(
            streamSession: (_) => stream.stream,
            stopSession: (_) async => frame(status: 'COMPLETED'),
            refreshState: () async {},
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ActiveChargingScreen(session: frame(), coordinator: owner),
            ),
          );
          stream.addError(const ApiException(503, 'OFFLINE', 'Offline'));
          await tester.pumpAndSettle();
          expect(find.text('Charging complete'), findsNothing);
          final stop = tester.getRect(
            find.text('Stop charging with confirmation'),
          );
          expect(stop.top, greaterThanOrEqualTo(0));
          expect(stop.bottom, lessThanOrEqualTo(size.height));
          await tester.ensureVisible(find.text('Retry live updates'));
          await tester.tap(find.text('Retry live updates'));
          await tester.pump();
          expect(
            find.text('Retry live updates'),
            findsOneWidget,
            reason: 'retry is pending until fresh data arrives',
          );
          stream.add(frame(soc: 66));
          await tester.pumpAndSettle();
          expect(find.text('Retry live updates'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          owner.dispose();
          await stream.close();
          activeSessionNotifier.value = null;
        },
      );
    }
  }
  test('late reconciliation cannot overwrite a newer live snapshot', () async {
    final stream = StreamController<ChargingSession>.broadcast();
    final response = Completer<ChargingSession>();
    final owner = SessionCoordinator(
      streamSession: (_) => stream.stream,
      stopSession: (_) async => frame(status: 'COMPLETED'),
      getSession: (_) => response.future,
      refreshState: () async {},
    );
    owner.watch(frame());
    stream.addError(StateError('brief interruption'));
    await Future<void>.delayed(Duration.zero);
    stream.add(frame(soc: 66));
    await Future<void>.delayed(Duration.zero);
    response.complete(frame(soc: 43));
    await Future<void>.delayed(Duration.zero);
    expect(owner.session?.batterySoc, 66);
    expect(owner.interrupted, isFalse);
    owner.dispose();
    await stream.close();
    activeSessionNotifier.value = null;
  });
}
