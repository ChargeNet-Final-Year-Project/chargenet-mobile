import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/profile/widgets/wallet_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpCard(WidgetTester tester) {
  return tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: WalletCardWidget())),
  );
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    walletBalanceNotifier.value = 0.0;
  });

  tearDown(() => walletBalanceNotifier.value = 0.0);

  group('WalletCardWidget.formatBalance', () {
    test('renders two decimals with the RM prefix', () {
      expect(WalletCardWidget.formatBalance(85.5), 'RM 85.50');
      expect(WalletCardWidget.formatBalance(135.5), 'RM 135.50');
      expect(WalletCardWidget.formatBalance(0), 'RM 0.00');
    });

    test('groups thousands', () {
      expect(WalletCardWidget.formatBalance(1234.5), 'RM 1,234.50');
    });
  });

  group('WalletCardWidget', () {
    testWidgets('shows the live balance from the notifier', (tester) async {
      await _pumpCard(tester);

      expect(find.text('ChargeNet Wallet'), findsOneWidget);
      expect(find.text('RM 0.00'), findsOneWidget);

      walletBalanceNotifier.value = 85.5;
      await tester.pump();

      expect(find.text('RM 85.50'), findsOneWidget);
      expect(find.text('Top Up'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('hides the balance behind a mask and restores it', (
      tester,
    ) async {
      walletBalanceNotifier.value = 85.5;
      await _pumpCard(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Hide balance'));
      await tester.pumpAndSettle();

      expect(find.text(WalletCardWidget.hiddenBalance), findsOneWidget);
      expect(find.text('RM 85.50'), findsNothing);

      await tester.tap(find.byTooltip('Show balance'));
      await tester.pumpAndSettle();

      expect(find.text('RM 85.50'), findsOneWidget);
    });

    testWidgets('remembers a hidden balance across a restart', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'walletBalanceVisible': false,
      });
      walletBalanceNotifier.value = 85.5;

      await _pumpCard(tester);
      await tester.pumpAndSettle();

      expect(find.text(WalletCardWidget.hiddenBalance), findsOneWidget);
    });
  });
}
