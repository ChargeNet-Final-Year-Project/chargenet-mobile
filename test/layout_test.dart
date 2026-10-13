import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/profile/profile_screen.dart';
import 'package:chargenet_mobile/features/home/station_filter.dart';
import 'package:chargenet_mobile/features/home/widgets/filter_chips_widget.dart';
import 'package:chargenet_mobile/features/home/widgets/station_detail_bottom_sheet.dart';
import 'package:chargenet_mobile/features/activity/widgets/ongoing_session_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/layout_fixtures.dart';

Future<void> pumpLayout(
  WidgetTester tester,
  Widget child,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        fontFamily: AppDesign.fontFamily,
        textTheme: AppTypography.theme,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    seedLayoutFixtures();
  });
  tearDown(() {
    currentUserNotifier.value = null;
    vehiclesNotifier.value = [];
    cposNotifier.value = [];
    walletBalanceNotifier.value = 0;
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('profile groups remain reachable at $size / $scale', (
        tester,
      ) async {
        await pumpLayout(tester, const ProfileScreen(), size, scale);
        await tester.scrollUntilVisible(
          find.text('Sign out'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Roaming network'), findsNothing);
        expect(cposNotifier.value, isNotEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('discovery controls reflow at $size / $scale', (
        tester,
      ) async {
        var selected = const StationFilter();
        await pumpLayout(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: FilterChipsWidget(
              filter: const StationFilter(),
              cpos: layoutCpos,
              onChanged: (value) => selected = value,
            ),
          ),
          size,
          scale,
        );
        expect(
          tester.getSize(find.byType(FilterChip).first).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('DC'));
        expect(selected.dcFast, isTrue);
        expect(tester.takeException(), isNull);

        var started = false;
        await pumpLayout(
          tester,
          Stack(
            children: [
              StationDetailBottomSheet(
                station: layoutStation,
                onDismiss: () {},
                onStartCharging: (_) => started = true,
              ),
            ],
          ),
          size,
          scale,
        );
        for (
          var i = 0;
          i < 16 &&
              find.text('Start charging').hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.drag(
            find.byType(ListView),
            Offset(0, -size.height * .5),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Start charging').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Start charging'));
        expect(started, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ongoing activity stays actionable at $size / $scale', (
        tester,
      ) async {
        var opened = false;
        await pumpLayout(
          tester,
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: OngoingSessionCard(
                session: layoutSession,
                cpos: layoutCpos,
                onOpen: () => opened = true,
              ),
            ),
          ),
          size,
          scale,
        );
        await tester.ensureVisible(find.text(OngoingSessionCard.openLabel));
        await tester.tap(find.text(OngoingSessionCard.openLabel));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
