import 'package:chargenet_mobile/features/profile/widgets/topup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSheet(WidgetTester tester) {
  return tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: TopUpSheet())),
  );
}

FilledButton _payButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  group('TopUpSheet amount rules', () {
    test('offers the four preset amounts', () {
      expect(TopUpSheet.presets, [20, 50, 100, 200]);
    });

    test('accepts 5–2000 and rejects everything else', () {
      expect(TopUpSheet.isValidAmount(5), isTrue);
      expect(TopUpSheet.isValidAmount(2000), isTrue);
      expect(TopUpSheet.isValidAmount(4.99), isFalse);
      expect(TopUpSheet.isValidAmount(2000.01), isFalse);
      expect(TopUpSheet.isValidAmount(null), isFalse);
    });

    test('labels the pay button with the amount, or plain Pay', () {
      expect(TopUpSheet.payLabel(50), 'Pay RM 50.00');
      expect(TopUpSheet.payLabel(4.99), 'Pay');
      expect(TopUpSheet.payLabel(null), 'Pay');
    });

    test('accepts at most two decimals in the field', () {
      expect(TopUpSheet.isValidAmountText('50'), isTrue);
      expect(TopUpSheet.isValidAmountText('50.'), isTrue);
      expect(TopUpSheet.isValidAmountText('50.99'), isTrue);
      expect(TopUpSheet.isValidAmountText('50.999'), isFalse);
      expect(TopUpSheet.isValidAmountText('12345'), isFalse);
      expect(TopUpSheet.isValidAmountText('abc'), isFalse);
    });

    test('the keystroke formatter keeps the last valid text', () {
      const typed = TextEditingValue(text: '50.12');

      final rejected = TopUpSheet.amountFormatter.formatEditUpdate(
        typed,
        const TextEditingValue(text: '50.123'),
      );
      expect(rejected.text, '50.12');

      final accepted = TopUpSheet.amountFormatter.formatEditUpdate(
        typed,
        const TextEditingValue(text: '50.99'),
      );
      expect(accepted.text, '50.99');

      final cleared = TopUpSheet.amountFormatter.formatEditUpdate(
        typed,
        const TextEditingValue(text: ''),
      );
      expect(cleared.text, '');
    });
  });

  group('TopUpSheet widget', () {
    testWidgets('starts with Pay disabled and no amount', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Pay'), findsOneWidget);
      expect(_payButton(tester).onPressed, isNull);
    });

    testWidgets('disables Pay for an amount below RM 5', (tester) async {
      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();

      expect(find.text('Pay'), findsOneWidget);
      expect(_payButton(tester).onPressed, isNull);
    });

    testWidgets('enables Pay and updates the label for a custom amount', (
      tester,
    ) async {
      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField), '123.45');
      await tester.pump();

      expect(find.text('Pay RM 123.45'), findsOneWidget);
      expect(_payButton(tester).onPressed, isNotNull);
    });

    testWidgets('a preset fills the field and relabels the button', (
      tester,
    ) async {
      await _pumpSheet(tester);

      await tester.tap(find.text('RM 50'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '50',
      );
      expect(find.text('Pay RM 50.00'), findsOneWidget);

      await tester.tap(find.text('RM 200'));
      await tester.pump();

      expect(find.text('Pay RM 200.00'), findsOneWidget);
    });

    testWidgets('offers the three simulated gateways with icons', (
      tester,
    ) async {
      await _pumpSheet(tester);

      expect(find.text('Maybank FPX'), findsOneWidget);
      expect(find.text("Touch 'n Go eWallet"), findsOneWidget);
      expect(find.text('Credit Card'), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNWidgets(3));
      expect(find.text('Simulated payment — no real money moves.'), findsOne);
    });
  });
}
