import 'package:chargenet_mobile/core/app_theme.dart';
import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/features/onboarding/widgets/step_progress.dart';
import 'package:chargenet_mobile/features/charging/widgets/qr_viewfinder_widget.dart';
import 'package:chargenet_mobile/widgets/data_slice.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('scanner feedback and torch remain reachable at $scale text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var toggled = false;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: QrViewfinderWidget(
              message: 'That code is not a ChargeNet charger. Try another code or enter it manually.',
              onToggleTorch: () => toggled = true,
            ),
          ),
        ),
      );
      final torch = find.byIcon(Icons.flashlight_off);
      await tester.ensureVisible(torch);
      await tester.pump();
      expect(tester.getRect(torch).bottom, lessThanOrEqualTo(560));
      await tester.tap(torch);
      expect(toggled, isTrue);
      expect(find.bySemanticsLabel('Turn on the flashlight'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  Future<void> slider(
    WidgetTester tester,
    VoidCallback fire, {
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: SlideToConfirm(
              label: 'Slide to stop',
              confirmationTitle: 'Stop charging',
              confirmationMessage: 'Review station · REVIEW-01\nRM 1.60 / kWh',
              enabled: enabled,
              onConfirmed: fire,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'semantic and keyboard activation require a second deliberate confirmation',
    (tester) async {
      var submitted = 0;
      final semantics = tester.ensureSemantics();
      await slider(tester, () => submitted++);
      expect(
        find.bySemanticsLabel('Stop charging with confirmation'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('Review station'), findsOneWidget);
      expect(submitted, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(submitted, 0);
      await tester.tap(find.text('Stop charging with confirmation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Stop charging'));
      await tester.pumpAndSettle();
      expect(submitted, 1);
      semantics.dispose();
    },
  );

  testWidgets('interrupted drag resets without submitting', (tester) async {
    var submitted = 0;
    await slider(tester, () => submitted++);
    final track = find.byType(GestureDetector).first;
    final before = tester.getTopLeft(find.byIcon(Icons.bolt));
    final gesture = await tester.startGesture(tester.getCenter(track));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(submitted, 0);
    expect(tester.getTopLeft(find.byIcon(Icons.bolt)), before);
  });

  testWidgets(
    'disabling the action while confirmation is open prevents submission',
    (tester) async {
      var submitted = 0;
      await slider(tester, () => submitted++);
      await tester.tap(find.text('Stop charging with confirmation'));
      await tester.pumpAndSettle();
      await slider(tester, () => submitted++, enabled: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(submitted, 0);
    },
  );

  testWidgets(
    'first-load failures hide default balances and retry independently',
    (tester) async {
      final state = ValueNotifier(const DataLoadState());
      addTearDown(state.dispose);
      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataSlice(
              state: state,
              label: 'wallet',
              onRetry: () async {
                retried++;
                state.value = const DataLoadState.ready();
              },
              child: const Text('RM 0.00'),
            ),
          ),
        ),
      );
      expect(find.text('Loading wallet…'), findsOneWidget);
      expect(find.text('RM 0.00'), findsNothing);
      state.value = const DataLoadState(error: 'Offline');
      await tester.pump();
      expect(find.text('RM 0.00'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, 1);
      expect(find.text('RM 0.00'), findsOneWidget);
      state.value = DataLoadState(
        hasData: true,
        error: 'Offline',
        updatedAt: DateTime(2026, 10, 24, 12),
      );
      await tester.pump();
      expect(find.text('RM 0.00'), findsOneWidget);
      expect(
        find.textContaining('Showing last successful data'),
        findsOneWidget,
      );
    },
  );

  testWidgets('onboarding exposes the current step to assistive technology', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: StepProgressWidget(numOfSteps: 2, currentStep: 1),
      ),
    );
    expect(find.bySemanticsLabel('Step 1 of 2'), findsOneWidget);
    semantics.dispose();
  });

  test('operator swatches retain identity with contrasting foregrounds', () {
    for (final background in [
      Colors.white,
      Colors.black,
      const Color(0xFF0D9488),
      const Color(0xFF2563EB),
      const Color(0xFFFFFF00),
      const Color(0xFF777777),
    ]) {
      final foreground = foregroundOnBrand(background);
      final a = foreground.computeLuminance(),
          b = background.computeLuminance();
      final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}
