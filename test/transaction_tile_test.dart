import 'package:chargenet_mobile/features/profile/widgets/transaction_tile_widget.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WalletTransaction _transaction({
  String type = TransactionTileWidget.topUpType,
  double amount = 50,
  String method = 'Maybank FPX',
  String referenceId = 'SIM-1730000000',
}) {
  return WalletTransaction(
    id: 'wtx_1',
    walletId: 'wal_1',
    type: type,
    amount: amount,
    paymentMethod: method,
    referenceId: referenceId,
    status: 'SUCCESS',
    createdAt: DateTime(2026, 10, 5, 15, 4),
  );
}

Future<void> _pumpTile(WidgetTester tester, WalletTransaction transaction) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TransactionTileWidget(transaction: transaction)),
    ),
  );
}

void main() {
  group('TransactionTileWidget labels', () {
    test('prefixes a top-up with + and a charge with −', () {
      expect(
        TransactionTileWidget.amountLabel(_transaction(amount: 50)),
        '+ RM 50.00',
      );
      expect(
        TransactionTileWidget.amountLabel(
          _transaction(
            type: TransactionTileWidget.chargingDebitType,
            amount: 31.36,
          ),
        ),
        '− RM 31.36',
      );
    });

    test('colours credits green and charges red', () {
      expect(
        TransactionTileWidget.amountColor(_transaction()),
        TransactionTileWidget.creditColor,
      );
      expect(
        TransactionTileWidget.amountColor(
          _transaction(type: TransactionTileWidget.chargingDebitType),
        ),
        TransactionTileWidget.debitColor,
      );
    });

    test('names the gateway for a top-up and the session for a debit', () {
      expect(TransactionTileWidget.titleLabel(_transaction()), 'Maybank FPX');
      expect(
        TransactionTileWidget.titleLabel(
          _transaction(
            type: TransactionTileWidget.chargingDebitType,
            method: 'Wallet',
          ),
        ),
        'Charging session',
      );
    });

    test('picks a distinct icon per type', () {
      expect(
        TransactionTileWidget.icon(_transaction()),
        isNot(TransactionTileWidget.icon(_transaction(type: 'CHARGING_DEBIT'))),
      );
    });

    test('formats the local date as dd MMM, h:mm a', () {
      expect(
        TransactionTileWidget.dateLabel(DateTime(2026, 10, 5, 15, 4)),
        '05 Oct, 3:04 PM',
      );
      expect(
        TransactionTileWidget.dateLabel(DateTime(2026, 1, 9, 0, 5)),
        '09 Jan, 12:05 AM',
      );
    });
  });

  group('TransactionTileWidget widget', () {
    testWidgets('renders a credit row', (tester) async {
      await _pumpTile(tester, _transaction());

      expect(find.text('Maybank FPX'), findsOneWidget);
      expect(find.text('+ RM 50.00'), findsOneWidget);
      expect(find.text('05 Oct, 3:04 PM'), findsOneWidget);
      expect(find.text('Ref SIM-1730000000'), findsOneWidget);
    });

    testWidgets('renders a debit row in red', (tester) async {
      await _pumpTile(
        tester,
        _transaction(type: 'CHARGING_DEBIT', amount: 31.36, method: 'Wallet'),
      );

      expect(find.text('Charging session'), findsOneWidget);

      final amount = tester.widget<Text>(find.text('− RM 31.36'));
      expect(amount.style?.color, TransactionTileWidget.debitColor);
    });
  });
}
