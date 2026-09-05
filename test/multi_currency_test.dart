import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargenet_mobile/core/app_theme.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/home/station_clusters.dart';
import 'package:chargenet_mobile/features/charging/evse_code_parser.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_quote_panel.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';

ChargingQuote quote() => ChargingQuote(
  id: 'q-sg',
  tariffPerKwh: '0.600000',
  originalCurrency: 'SGD',
  walletCurrency: 'MYR',
  exchangeRate: '3.4500000000',
  equivalentTariff: '2.070000',
  estimatedKwh: '15',
  estimatedOriginalCost: '9.00',
  estimatedWalletCost: '31.05',
  budget: '85.50',
  rateSource: 'chargenet-demo-v1',
);

void main() {
  testWidgets('quote confirmation glyphs fit the track at 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const label = 'Confirm and start';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: SlideToConfirm(label: label, onConfirmed: () {}),
            ),
          ),
        ),
      ),
    );
    final text = find.text(label);
    final track = find
        .ancestor(of: text, matching: find.byType(GestureDetector))
        .first;
    final bounds = tester.getRect(track).inflate(.5);
    final origin = tester.getTopLeft(text);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final glyphs = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: label.length),
    );
    expect(glyphs.length, greaterThan(1));
    for (final box in glyphs) {
      expect(bounds.contains(origin + Offset(box.right, box.bottom)), isTrue);
    }
    expect(tester.takeException(), isNull);
  });
  test(
    'new OCPI-style charging identifiers survive discovery and QR entry',
    () {
      for (final uid in [
        'MY*VLT*E*D01DC',
        'SG*CSY*E*D12DC',
        'TH*ECO*E*D21DC',
        'SG*CSY*E*D12DC:2',
      ]) {
        expect(EvseCodeParser.parse(uid.toLowerCase()), uid);
        expect(
          EvseCodeParser.parse('chargenet://evse/${Uri.encodeComponent(uid)}'),
          uid,
        );
      }
    },
  );
  test('currency formatting identifies all three denominations', () {
    expect(formatMoney(31.05, 'MYR'), 'RM 31.05');
    expect(formatMoney(9, 'SGD'), 'SGD 9.00');
    expect(formatMoney(120, 'THB'), 'THB 120.00');
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('quote is readable at 320dp / $scale text', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ChargingQuotePanel(
                  quote: quote(),
                  loading: false,
                  error: null,
                  onRetry: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('SGD 0.60 / kWh'), findsOneWidget);
      expect(find.text('RM 31.05'), findsOneWidget);
      expect(find.text('Payment details'), findsOneWidget);
      expect(find.textContaining('Valid until'), findsNothing);
      expect(find.textContaining('quotation'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed estimate can be retried', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargingQuotePanel(
            quote: null,
            loading: false,
            error: 'Unable to calculate the estimated cost.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
  test('receipt preserves original amount and wallet deduction', () {
    const receipt = ChargingSession(
      id: 's',
      userId: 'u',
      cpoId: 'c',
      cpoName: 'Demo CPO',
      stationId: 'st',
      stationName: 'Demo Marina Bay',
      connectorId: 'con',
      evseUid: 'SG*VLT*E1',
      connectorType: 'CCS2',
      status: 'COMPLETED',
      tariffPerKwh: .6,
      kwhDelivered: 15,
      originalCurrency: 'SGD',
      walletCurrency: 'MYR',
      exchangeRate: '3.45',
      originalCost: 9,
      totalCost: 31.05,
      balanceAfter: 54.45,
    );
    final copy = ChargingReceipt.plainText(receipt);
    expect(copy, contains('SGD 9.00'));
    expect(copy, contains('RM 31.05'));
    expect(copy, contains('1 SGD = 3.45 MYR'));
  });
  test('clusters respect distance and zoom without merging countries', () {
    Station station(String id, double lat, double lng) => Station(
      id: id,
      cpoId: 'c',
      cpoName: 'Demo',
      cpoColorHex: '#0D9488',
      name: id,
      address: 'Simulated',
      city: 'Demo',
      latitude: lat,
      longitude: lng,
      totalBays: 1,
      availableBays: 1,
      isActive: true,
      connectors: const [],
    );
    final points = [
      station('island', 5.419, 100.331),
      station('nearby', 5.42, 100.332),
      station('mainland', 5.399, 100.368),
      station('singapore', 1.28, 103.854),
    ];
    final groups = clusterStations(points, 11);
    expect(groups.fold<int>(0, (sum, group) => sum + group.length), 4);
    expect(
      groups.firstWhere((g) => g.any((s) => s.id == 'singapore')).length,
      1,
    );
    expect(clusterStations(points, 18).length, 4);
  });
}
