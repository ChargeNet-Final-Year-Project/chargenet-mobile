import 'package:chargenet_mobile/data/load_state.dart';

import 'dart:async';

import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:chargenet_mobile/features/dashboard/widgets/charging_mini_bar.dart';
import 'package:chargenet_mobile/features/onboarding/pages/features_page.dart';
import 'package:chargenet_mobile/features/onboarding/pages/welcome_page.dart';
import 'package:chargenet_mobile/features/profile/widgets/wallet_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        fontFamily: AppDesign.fontFamily,
        textTheme: AppTypography.theme,
        colorScheme: ColorScheme.fromSeed(seedColor: AppDesign.primary),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
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

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader(AppDesign.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/Outfit-VariableFont_wght.ttf'));
    await font.load();
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final welcome in [true, false]) {
        testWidgets(
          '${welcome ? 'welcome' : 'features'} remains reachable at $size / $scale',
          (tester) async {
            var continued = false;
            final page = welcome
                ? WelcomePage(onNext: () => continued = true)
                : FeaturesPage(onNext: () => continued = true);
            await _pump(tester, page, size: size, scale: scale);
            final action = find.text(
              welcome ? 'Get Started' : 'Start My Journey',
            );
            await tester.ensureVisible(action);
            await tester.pump();
            await tester.tap(action);
            expect(continued, isTrue);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('wallet keeps its balance and controls at 200% text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    walletBalanceNotifier.value = 12345.67;
    addTearDown(() => walletBalanceNotifier.value = 0);
    await _pump(
      tester,
      const SingleChildScrollView(child: WalletCardWidget()),
      size: const Size(320, 640),
      scale: 2,
    );
    expect(find.text('RM 12,345.67'), findsOneWidget);
    final balanceScroll = tester.widget<SingleChildScrollView>(
      find
          .ancestor(
            of: find.text('RM 12,345.67'),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(balanceScroll.controller!.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.text('RM 12,345.67'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(balanceScroll.controller!.offset, greaterThan(0));
    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pump();
    expect(find.text(WalletCardWidget.hiddenBalance), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('charging strip reflows and remains actionable at 200% text', (
    tester,
  ) async {
    var opened = false;
    final session = ChargingSession(
      id: 'type-session',
      userId: 'driver',
      cpoId: 'cpo',
      cpoName: 'Operator',
      stationId: 'station',
      stationName: 'Station',
      connectorId: 'connector',
      evseUid: 'EVSE',
      connectorType: 'CCS2',
      status: 'CHARGING',
      tariffPerKwh: 1.6,
      batterySoc: 58,
      currentPowerKw: 124.5,
    );
    await _pump(
      tester,
      ChargingMiniBar(session: session, onTap: () => opened = true),
      size: const Size(320, 640),
      scale: 2,
    );
    expect(find.text('58% · 124.5 kW'), findsOneWidget);
    await tester.tap(find.text('Charging'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('monitor preserves readouts at $width / $scale', (
        tester,
      ) async {
        final stream = StreamController<ChargingSession>.broadcast();
        addTearDown(stream.close);
        addTearDown(() => activeSessionNotifier.value = null);
        await _pump(
          tester,
          ActiveChargingScreen(
            session: ChargingSession(
              id: 'type-monitor',
              userId: 'driver',
              cpoId: 'cpo',
              cpoName: 'Operator',
              stationId: 'station',
              stationName: 'Station with an expanded name',
              connectorId: 'connector',
              evseUid: 'EVSE',
              connectorType: 'CCS2',
              status: 'CHARGING',
              tariffPerKwh: 1.6,
              batterySoc: 100,
              currentPowerKw: 124.5,
              kwhDelivered: 88.8,
              durationSeconds: 36000,
            ),
            streamSession: (_) => stream.stream,
          ),
          size: Size(width, 640),
          scale: scale,
        );
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('124.5 kW'), findsOneWidget);
        expect(find.text('10:00:00'), findsOneWidget);
        final stopBeforeScroll = tester.getRect(find.byType(SlideToConfirm));
        expect(stopBeforeScroll.top, greaterThanOrEqualTo(0));
        expect(stopBeforeScroll.bottom, lessThanOrEqualTo(640));
        await tester.ensureVisible(find.text('RM 142.08'));
        await tester.pump();
        final cost = tester.getRect(find.text('RM 142.08'));
        expect(cost.bottom, lessThanOrEqualTo(stopBeforeScroll.top));
        expect(tester.getRect(find.byType(SlideToConfirm)), stopBeforeScroll);
        await tester.ensureVisible(find.byType(SlideToConfirm));
        await tester.pump();
        final label = tester.getRect(find.text(ActiveChargingScreen.stopLabel));
        final control = tester.getRect(find.byType(SlideToConfirm));
        expect(control.contains(label.topLeft), isTrue);
        expect(control.contains(label.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
