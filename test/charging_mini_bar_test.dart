import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/dashboard/widgets/charging_mini_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A running session as `GET /sessions/active` reports it.
ChargingSession _session({double? soc = 58, double? powerKw = 124.5}) =>
    ChargingSession(
      id: 'ses_1',
      userId: 'usr_1',
      cpoId: 'cpo_voltgo',
      cpoName: 'VoltGo',
      stationId: 'stn_vlt_sgb',
      stationName: 'VoltGo Sungei Besi',
      connectorId: 'con_vlt_sgb_01',
      evseUid: 'VLT-SGB-01',
      connectorType: 'CCS2',
      status: 'CHARGING',
      tariffPerKwh: 1.6,
      batterySoc: soc,
      currentPowerKw: powerKw,
    );

Future<void> _pumpBar(
  WidgetTester tester, {
  ChargingSession? session,
  VoidCallback? onTap,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      bottomNavigationBar: ChargingMiniBar(
        session: session ?? _session(),
        onTap: onTap ?? () {},
      ),
    ),
  ),
);

void main() {
  test('telemetryLabel joins the battery level and the power', () {
    expect(ChargingMiniBar.telemetryLabel(_session()), '58% · 124.5 kW');
    expect(
      ChargingMiniBar.telemetryLabel(_session(soc: 80, powerKw: 22)),
      '80% · 22.0 kW',
    );
  });

  test('telemetryLabel survives a session whose readings are not in yet', () {
    expect(
      ChargingMiniBar.telemetryLabel(_session(soc: null, powerKw: null)),
      '$kNoValue · $kNoValue',
    );
    expect(
      ChargingMiniBar.telemetryLabel(_session(soc: 80, powerKw: null)),
      '80% · $kNoValue',
    );
  });

  testWidgets('shows the live numbers and taps through to the monitor', (
    tester,
  ) async {
    var taps = 0;
    await _pumpBar(tester, onTap: () => taps++);

    expect(find.text('Charging'), findsOneWidget);
    expect(find.text('58% · 124.5 kW'), findsOneWidget);

    await tester.tap(find.byType(ChargingMiniBar));
    expect(taps, 1);
  });
}
