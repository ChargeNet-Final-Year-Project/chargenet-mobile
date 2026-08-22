import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/features/profile/widgets/transaction_tile_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A finished session as `/sessions/{id}` (or a history row) reports it.
ChargingSession _session({
  String status = 'COMPLETED',
  double? kwh = 19.6,
  int? durationSeconds = 1500,
  double? totalCost = 31.36,
  double? balanceAfter = 26.92,
  String? stopReason = 'TARGET_SOC_REACHED',
  String? cdrId,
  Map<String, dynamic>? cdrJson,
  DateTime? startTime,
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
  startTime: startTime ?? DateTime(2026, 10, 6, 15, 4),
  endTime: DateTime(2026, 10, 6, 15, 29),
  durationSeconds: durationSeconds,
  kwhDelivered: kwh,
  currentPowerKw: 0,
  batterySoc: 80,
  targetSoc: 80,
  tariffPerKwh: 1.6,
  totalCost: totalCost,
  balanceAfter: balanceAfter,
  stopReason: stopReason,
  cdrId: cdrId,
  cdrJson: cdrJson,
);

/// Also checks that receipt paper stays light under an external dark host.
class _Host extends StatelessWidget {
  const _Host({required this.session, this.dark = false});

  final ChargingSession session;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: dark ? ThemeData.dark() : null,
      home: Scaffold(
        body: Center(
          // A Builder for the same reason the real callers pass their own
          // screen's context: the sheet needs a Navigator and localizations
          // *below* the MaterialApp.
          child: Builder(
            builder: (inner) => FilledButton(
              onPressed: () => showChargingReceipt(inner, session),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the receipt the way both callers do: from a host screen, through
/// [showChargingReceipt].
///
/// The default surface is a phone tall enough to hold the whole receipt, so a
/// test that taps an action cannot silently miss an off-screen target; the
/// small-phone test passes its own [size] on purpose.
Future<void> _openReceipt(
  WidgetTester tester,
  ChargingSession session, {
  bool dark = false,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_Host(session: session, dark: dark));
  await tester.pumpAndSettle();

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('receipt formatters', () {
    test('formatDuration renders the backend seconds as a clock', () {
      // Verify the receipt contract before checking layout details.
      expect(formatDuration(872), '00:14:32');
      expect(formatDuration(1500), '00:25:00');
      expect(formatDuration(0), '00:00:00');
      expect(formatDuration(null), '00:00:00');
      expect(formatDuration(-4), '00:00:00');
      expect(formatDuration(3725), '01:02:05');
    });

    test('the monitor row and the receipt row read the same clock', () {
      expect(formatClock(872), formatDuration(872));
    });

    test('formatDateTime writes a local date and time', () {
      expect(
        formatDateTime(DateTime(2026, 10, 6, 15, 4)),
        '06 Oct 2026, 3:04 PM',
      );
      expect(
        formatDateTime(DateTime(2026, 1, 9, 0, 5)),
        '09 Jan 2026, 12:05 AM',
      );
      expect(formatDateTime(null), kNoValue);
    });
  });

  group('receipt rows', () {
    test('prints one row per itemised line in display order', () {
      final rows = ChargingReceipt.detailRows(_session(cdrId: 'cdr_01HX'));

      expect(rows.map((row) => row.label).toList(), [
        ChargingReceipt.dateRowLabel,
        ChargingReceipt.chargerRowLabel,
        ChargingReceipt.energyRowLabel,
        ChargingReceipt.durationRowLabel,
        ChargingReceipt.rateRowLabel,
        ChargingReceipt.subtotalRowLabel,
        ChargingReceipt.paidRowLabel,
        ChargingReceipt.balanceRowLabel,
        ChargingReceipt.stopReasonRowLabel,
        ChargingReceipt.receiptNoRowLabel,
      ]);
      expect(rows.map((row) => row.value).toList(), [
        '06 Oct 2026, 3:04 PM',
        'VLT-SGB-01 · CCS2',
        '19.600 kWh',
        '00:25:00',
        'RM 1.60 / kWh',
        'RM 31.36',
        'RM 31.36',
        'RM 26.92',
        'Target charge reached',
        'cdr_01HX',
      ]);
    });

    test('the paid figure is the wallet\'s CHARGING_DEBIT row', () {
      final session = _session();
      final debit = WalletTransaction(
        id: 'wtx_1',
        walletId: 'wal_1',
        type: TransactionTileWidget.chargingDebitType,
        amount: session.totalCost!,
        paymentMethod: 'Wallet',
        referenceId: session.id,
        status: 'SUCCESS',
        createdAt: session.endTime!,
      );

      expect(
        ChargingReceipt.money(ChargingReceipt.chargedOf(session)),
        TransactionTileWidget.formatAmount(debit.amount),
      );
    });

    test('an unpriced settlement keeps paid money unknown', () {
      final estimated = _session(totalCost: null);
      expect(ChargingReceipt.chargedOf(estimated), isNull);
      expect(ChargingReceipt.subtotalOf(estimated), closeTo(31.36, 1e-9));
      expect(
        ChargingReceipt.plainText(_session(status: 'CHARGING')),
        contains('Completion unconfirmed'),
      );

      final unpriced = _session(totalCost: null, kwh: null);
      expect(ChargingReceipt.chargedOf(unpriced), isNull);
      expect(
        ChargingReceipt.money(ChargingReceipt.chargedOf(unpriced)),
        kNoValue,
      );
      expect(ChargingReceipt.energyLabel(unpriced), kNoValue);
    });

    test('a very small session prices out at RM 0.00, not unknown', () {
      final tiny = _session(kwh: 0, durationSeconds: 0, totalCost: 0);

      expect(ChargingReceipt.energyLabel(tiny), '0.000 kWh');
      expect(ChargingReceipt.money(ChargingReceipt.chargedOf(tiny)), 'RM 0.00');
      expect(ChargingReceipt.money(0), 'RM 0.00');
    });

    test(
      'the two optional rows only appear when there is something to say',
      () {
        final plain = ChargingReceipt.detailRows(_session(stopReason: null));
        final labels = plain.map((row) => row.label);

        expect(labels, isNot(contains(ChargingReceipt.stopReasonRowLabel)));
        expect(labels, isNot(contains(ChargingReceipt.receiptNoRowLabel)));
        expect(
          ChargingReceipt.detailRows(_session(cdrId: 'cdr_1')).last.label,
          ChargingReceipt.receiptNoRowLabel,
        );
      },
    );

    test('plainText carries every row and never the platform fee', () {
      final session = _session(
        cdrId: 'cdr_01HX',
        cdrJson: {
          'chargenet': {'platform_fee': 1.23},
          'total_cost': 31.36,
        },
      );
      final text = ChargingReceipt.plainText(session);

      expect(
        text,
        startsWith(
          'ChargeNet receipt\n'
          'Charging complete\n'
          'VoltGo · VoltGo Sungei Besi\n'
          'Total: RM 31.36\n\n',
        ),
      );
      expect(text, contains('Date & time: 06 Oct 2026, 3:04 PM'));
      expect(text, contains('Charger: VLT-SGB-01 · CCS2'));
      expect(text, contains('Paid from wallet: RM 31.36'));
      expect(text, contains('Remaining balance: RM 26.92'));
      expect(text, endsWith('Receipt no.: cdr_01HX'));
      expect(
        text,
        isNot(contains('1.23')),
        reason:
            'the CDR platform fee is ChargeNet\'s revenue, not the '
            'driver\'s charge',
      );
    });
  });

  group('ChargingReceipt', () {
    testWidgets('renders the header, the detail rows and both actions', (
      tester,
    ) async {
      await _openReceipt(tester, _session(cdrId: 'cdr_01HX'));

      expect(find.text('Charging complete'), findsOneWidget);
      expect(find.text('RM 31.36'), findsNWidgets(2));
      expect(find.text('VoltGo'), findsOneWidget);
      expect(find.text('VoltGo Sungei Besi'), findsOneWidget);
      expect(find.byKey(ChargingReceipt.dividerKey), findsOneWidget);
      await tester.tap(find.text('Receipt details'));
      await tester.pumpAndSettle();
      expect(find.text('Date & time'), findsOneWidget);
      expect(find.text('Energy delivered'), findsOneWidget);
      expect(find.text('Rate'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Paid from wallet'), findsOneWidget);
      expect(find.text('Remaining balance'), findsOneWidget);
      expect(find.text('Stop reason'), findsOneWidget);
      expect(find.text('Target charge reached'), findsOneWidget);
      expect(find.text('Receipt no.'), findsOneWidget);
      expect(find.text('cdr_01HX'), findsOneWidget);
      expect(find.text(ChargingReceipt.copyLabel), findsOneWidget);
      expect(find.text(ChargingReceipt.doneLabel), findsOneWidget);
    });

    testWidgets('reads as a failure when the session failed', (tester) async {
      await _openReceipt(
        tester,
        _session(status: 'FAILED', stopReason: 'EVSE_FAULT'),
      );

      expect(find.text('Charging failed'), findsOneWidget);
      expect(find.text('Charging complete'), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Charger reported a fault'), findsOneWidget);
    });

    testWidgets('stays paper-light over the dark monitor', (tester) async {
      await _openReceipt(tester, _session(), dark: true);

      final receipt = tester.element(find.byType(ChargingReceipt));
      expect(
        Theme.of(receipt).brightness,
        Brightness.light,
        reason: 'a receipt is paper, whichever route opened it',
      );
    });

    testWidgets('a tiny session on a small phone scrolls instead of clipping', (
      tester,
    ) async {
      await _openReceipt(
        tester,
        _session(kwh: 0, durationSeconds: 0, totalCost: 0, stopReason: null),
        size: const Size(320, 568),
      );

      expect(find.text('0.000 kWh'), findsOneWidget);
      expect(find.text('00:00:00'), findsOneWidget);
      expect(
        find.text('RM 0.00'),
        findsNWidgets(2), // total, subtotal and paid from wallet
      );
      expect(
        find.text(ChargingReceipt.stopReasonRowLabel),
        findsNothing,
        reason: 'a session that reached its target has no reason row',
      );
      expect(tester.takeException(), isNull);

      // The actions sit at the end of the scrolling receipt, not off it.
      await tester.ensureVisible(find.text(ChargingReceipt.doneLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ChargingReceipt.doneLabel));
      await tester.pumpAndSettle();

      expect(find.byType(ChargingReceipt), findsNothing);
    });

    testWidgets('Done dismisses the sheet', (tester) async {
      await _openReceipt(tester, _session());

      await tester.tap(find.text(ChargingReceipt.doneLabel));
      await tester.pumpAndSettle();

      expect(find.byType(ChargingReceipt), findsNothing);
      expect(find.text('Charging complete'), findsNothing);
    });

    testWidgets('Copy receipt puts the plain text on the clipboard', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final session = _session(cdrId: 'cdr_01HX');
      await _openReceipt(tester, session);

      await tester.tap(find.text(ChargingReceipt.copyLabel));
      await tester.pumpAndSettle();

      final copy = calls.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map)['text'],
        ChargingReceipt.plainText(session),
      );
      expect(find.text(ChargingReceipt.copiedMessage), findsOneWidget);
      expect(
        find.byType(ChargingReceipt),
        findsOneWidget,
        reason: 'copying leaves the receipt open',
      );
    });
  });
}
