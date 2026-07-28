import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/home/widgets/connector_tile_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Connector _connector({
  String status = 'AVAILABLE',
  String standard = 'CCS2',
  String powerType = 'DC',
  double maxPowerKw = 180,
  double tariffPerKwh = 1.6,
}) {
  return Connector(
    id: 'con_vlt_sgb_01',
    stationId: 'stn_vlt_sgb',
    evseUid: 'VLT-SGB-01',
    standard: standard,
    format: 'CABLE',
    powerType: powerType,
    maxPowerKw: maxPowerKw,
    tariffPerKwh: tariffPerKwh,
    status: status,
  );
}

Future<void> _pumpTile(
  WidgetTester tester,
  Connector connector, {
  ValueChanged<Connector>? onStartCharging,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConnectorTileWidget(
          connector: connector,
          onStartCharging: onStartCharging,
        ),
      ),
    ),
  );
}

FilledButton _startButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Start charging'),
);

void main() {
  group('ConnectorTileWidget', () {
    testWidgets('renders the standard, rating, tariff and a live badge', (
      tester,
    ) async {
      await _pumpTile(tester, _connector());

      expect(find.text('CCS2 (Type 2)'), findsOneWidget);
      expect(find.text('DC · 180 kW · RM 1.60 / kWh'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('enables Start charging when AVAILABLE and reports the tap', (
      tester,
    ) async {
      Connector? started;
      await _pumpTile(
        tester,
        _connector(),
        onStartCharging: (connector) => started = connector,
      );

      expect(_startButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Start charging'));

      expect(started?.evseUid, 'VLT-SGB-01');
    });

    testWidgets('disables Start charging while the connector is CHARGING', (
      tester,
    ) async {
      await _pumpTile(tester, _connector(status: 'CHARGING'));

      expect(find.text('Charging'), findsOneWidget);
      expect(_startButton(tester).onPressed, isNull);
    });

    testWidgets('disables Start charging when the connector is INOPERATIVE', (
      tester,
    ) async {
      await _pumpTile(tester, _connector(status: 'INOPERATIVE'));

      expect(find.text('Inoperative'), findsOneWidget);
      expect(_startButton(tester).onPressed, isNull);
    });

    test('maps known standards onto their display names', () {
      expect(ConnectorTileWidget.standardLabel('CCS2'), 'CCS2 (Type 2)');
      expect(ConnectorTileWidget.standardLabel('CHADEMO'), 'CHAdeMO');
    });

    test('falls back to the raw value for an unknown standard', () {
      expect(ConnectorTileWidget.standardLabel('TESLA'), 'TESLA');
    });

    test('title-cases statuses and tolerates an empty one', () {
      expect(ConnectorTileWidget.statusLabel('AVAILABLE'), 'Available');
      expect(ConnectorTileWidget.statusLabel('INOPERATIVE'), 'Inoperative');
      expect(ConnectorTileWidget.statusLabel('  '), 'Unknown');
    });
  });
}
