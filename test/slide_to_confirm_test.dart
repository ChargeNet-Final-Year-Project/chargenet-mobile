import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSlider(
  WidgetTester tester, {
  required VoidCallback onConfirmed,
  bool enabled = true,
  bool loading = false,
  String? hint,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SlideToConfirm(
            label: 'Slide to start charging',
            enabled: enabled,
            loading: loading,
            hint: hint,
            onConfirmed: onConfirmed,
          ),
        ),
      ),
    ),
  );
}

/// Horizontal position of the thumb's icon.
double _thumbX(WidgetTester tester) =>
    tester.getCenter(find.byIcon(Icons.bolt)).dx;

void main() {
  group('SlideToConfirm geometry', () {
    test('the thumb travels the track minus its own width', () {
      expect(SlideToConfirm.thumbSize(58), 48);
      expect(SlideToConfirm.travel(400, 58), 342);
      expect(SlideToConfirm.travel(40, 58), 0);
    });

    test('arms only past 90 % of the travel', () {
      expect(SlideToConfirm.isArmed(342, 342), isTrue);
      expect(SlideToConfirm.isArmed(308, 342), isTrue);
      expect(SlideToConfirm.isArmed(300, 342), isFalse);
      expect(SlideToConfirm.isArmed(0, 0), isFalse);
    });
  });

  group('SlideToConfirm widget', () {
    testWidgets('runs the action once on a full swipe', (tester) async {
      var fired = 0;
      await _pumpSlider(tester, onConfirmed: () => fired++);

      expect(find.text('Slide to start charging'), findsOneWidget);

      await tester.drag(find.byType(SlideToConfirm), const Offset(1000, 0));
      await tester.pumpAndSettle();

      expect(fired, 1);
    });

    testWidgets('springs back without firing on a short drag', (tester) async {
      var fired = 0;
      await _pumpSlider(tester, onConfirmed: () => fired++);

      final start = _thumbX(tester);

      await tester.drag(find.byType(SlideToConfirm), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(fired, 0);
      expect(_thumbX(tester), start);
    });

    testWidgets('does nothing while disabled', (tester) async {
      var fired = 0;
      await _pumpSlider(tester, enabled: false, onConfirmed: () => fired++);

      await tester.drag(find.byType(SlideToConfirm), const Offset(1000, 0));
      await tester.pumpAndSettle();

      expect(fired, 0);
    });

    testWidgets('shows a spinner and ignores drags while loading', (
      tester,
    ) async {
      var fired = 0;
      await _pumpSlider(tester, loading: true, onConfirmed: () => fired++);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.drag(find.byType(SlideToConfirm), const Offset(1000, 0));
      // The spinner animates forever, so pump bounded frames instead of
      // settling (pumpAndSettle would time out).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(fired, 0);
    });

    testWidgets('renders the blocker hint under the track', (tester) async {
      await _pumpSlider(
        tester,
        enabled: false,
        hint: 'Top up to at least RM 10.00 to start charging.',
        onConfirmed: () {},
      );

      expect(find.textContaining('Top up to at least'), findsOneWidget);
    });
  });
}
