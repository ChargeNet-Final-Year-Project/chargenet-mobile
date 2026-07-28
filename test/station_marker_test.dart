import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/home/widgets/station_marker_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A station carrying [connectorStatuses] in order (empty ⇒ no connector rows).
Station _station({
  int availableBays = 2,
  int totalBays = 4,
  bool isActive = true,
  List<String> connectorStatuses = const ['AVAILABLE', 'CHARGING'],
  String cpoColorHex = '#0D9488',
}) {
  return Station(
    id: 'stn_vlt_sgb',
    cpoId: 'cpo_voltgo',
    cpoName: 'VoltGo',
    cpoColorHex: cpoColorHex,
    name: 'VoltGo Sungei Besi',
    address: 'Jalan Sungai Besi',
    city: 'Kuala Lumpur',
    latitude: 3.1221,
    longitude: 101.7031,
    totalBays: totalBays,
    availableBays: availableBays,
    isActive: isActive,
    connectors: [
      for (var i = 0; i < connectorStatuses.length; i++)
        Connector(
          id: 'con_vlt_sgb_0$i',
          stationId: 'stn_vlt_sgb',
          evseUid: 'VLT-SGB-0$i',
          standard: 'CCS2',
          format: 'CABLE',
          powerType: 'DC',
          maxPowerKw: 180,
          tariffPerKwh: 1.6,
          status: connectorStatuses[i],
        ),
    ],
  );
}

/// The colour the outer status ring is actually painted with.
Color _ringColor(WidgetTester tester) {
  final ring = tester.widget<Container>(
    find.byKey(StationMarkerWidget.ringKey),
  );
  final decoration = ring.decoration! as BoxDecoration;

  return (decoration.border! as Border).top.color;
}

/// The fill colour of the CPO badge.
Color _badgeColor(WidgetTester tester) {
  final badge = tester.widget<Container>(
    find.byKey(StationMarkerWidget.badgeKey),
  );

  return (badge.decoration! as BoxDecoration).color!;
}

Future<void> _pumpMarker(
  WidgetTester tester,
  Station station, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: StationMarkerWidget(station: station, onTap: onTap),
        ),
      ),
    ),
  );
}

void main() {
  group('colorFromHex', () {
    test('parses the 6-digit brand tokens served by the API', () {
      expect(colorFromHex('#0D9488'), const Color(0xFF0D9488));
      expect(colorFromHex('0D9488'), const Color(0xFF0D9488));
      expect(colorFromHex('  #2563EB  '), const Color(0xFF2563EB));
    });

    test('honours an explicit alpha channel', () {
      expect(colorFromHex('#800D9488'), const Color(0x800D9488));
    });

    test('expands 3-digit shorthand', () {
      expect(colorFromHex('#0D9'), const Color(0xFF00DD99));
    });

    test('falls back instead of throwing on malformed input', () {
      expect(colorFromHex(''), kFallbackCpoColor);
      expect(colorFromHex('#GGGGGG'), kFallbackCpoColor);
      expect(colorFromHex('#0D948'), kFallbackCpoColor);
      expect(colorFromHex('teal'), kFallbackCpoColor);
    });
  });

  group('StationMarkerWidget.ringColorFor', () {
    test('green while at least one bay is free', () {
      expect(
        StationMarkerWidget.ringColorFor(_station(availableBays: 1)),
        StationMarkerWidget.availableRingColor,
      );
    });

    test('amber when the station is live but full', () {
      expect(
        StationMarkerWidget.ringColorFor(_station(availableBays: 0)),
        StationMarkerWidget.busyRingColor,
      );
    });

    test('grey when the station is inactive', () {
      expect(
        StationMarkerWidget.ringColorFor(_station(isActive: false)),
        StationMarkerWidget.offlineRingColor,
      );
    });

    test('grey when every connector reports INOPERATIVE', () {
      expect(
        StationMarkerWidget.ringColorFor(
          _station(connectorStatuses: const ['INOPERATIVE', 'INOPERATIVE']),
        ),
        StationMarkerWidget.offlineRingColor,
      );
    });

    test('amber, not grey, when full but the connectors are merely busy', () {
      expect(
        StationMarkerWidget.ringColorFor(
          _station(
            availableBays: 0,
            connectorStatuses: const ['CHARGING', 'CHARGING'],
          ),
        ),
        StationMarkerWidget.busyRingColor,
      );
    });

    test('falls back to the bay count when connector rows are absent', () {
      expect(
        StationMarkerWidget.ringColorFor(
          _station(availableBays: 3, connectorStatuses: const []),
        ),
        StationMarkerWidget.availableRingColor,
      );
    });
  });

  group('StationMarkerWidget', () {
    testWidgets('paints the CPO brand colour and a green ring when free', (
      tester,
    ) async {
      await _pumpMarker(tester, _station());

      expect(find.text('2/4'), findsOneWidget);
      expect(_badgeColor(tester), const Color(0xFF0D9488));
      expect(_ringColor(tester), StationMarkerWidget.availableRingColor);
    });

    testWidgets('shows the grey ring and a 0/total chip when inactive', (
      tester,
    ) async {
      await _pumpMarker(
        tester,
        _station(isActive: false, availableBays: 0, totalBays: 4),
      );

      expect(find.text('0/4'), findsOneWidget);
      expect(_ringColor(tester), StationMarkerWidget.offlineRingColor);
    });

    testWidgets('reports taps so the map can select the station', (
      tester,
    ) async {
      var taps = 0;
      await _pumpMarker(tester, _station(), onTap: () => taps++);

      await tester.tap(find.byType(StationMarkerWidget));

      expect(taps, 1);
    });

    testWidgets('an unusable brand colour degrades to the fallback', (
      tester,
    ) async {
      await _pumpMarker(tester, _station(cpoColorHex: '#ZZZ'));

      expect(_badgeColor(tester), kFallbackCpoColor);
    });
  });
}
