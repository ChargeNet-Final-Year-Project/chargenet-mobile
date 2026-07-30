import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/profile/widgets/vehicle_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Vehicle _vehicle({
  String name = 'Tesla Model Y',
  String licensePlate = 'PCN1234',
  String connectorType = 'CCS2',
  double batteryCapacity = 75,
  bool isDefault = true,
}) {
  return Vehicle(
    id: 'veh_1',
    userId: 'usr_1',
    name: name,
    licensePlate: licensePlate,
    connectorType: connectorType,
    batteryCapacity: batteryCapacity,
    isDefault: isDefault,
  );
}

Future<void> _pumpCard(WidgetTester tester, Vehicle vehicle) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: VehicleCardWidget(vehicle: vehicle)),
    ),
  );
}

void main() {
  group('VehicleCardWidget formatting', () {
    test('drops a trailing .0 from the capacity', () {
      expect(VehicleCardWidget.batteryLabel(75), '75 kWh');
      expect(VehicleCardWidget.capacityText(75), '75');
    });

    test('keeps one decimal when the capacity has one', () {
      expect(VehicleCardWidget.batteryLabel(72.6), '72.6 kWh');
      expect(VehicleCardWidget.capacityText(72.6), '72.6');
    });

    test('maps the canonical connector value onto its display name', () {
      expect(VehicleCardWidget.connectorLabel('CCS2'), 'CCS2 (Type 2)');
      expect(VehicleCardWidget.connectorLabel('TYPE2'), 'Type 2 (AC)');
    });

    test('falls back to the raw value for an unknown connector', () {
      expect(VehicleCardWidget.connectorLabel('TESLA'), 'TESLA');
    });
  });

  group('VehicleCardWidget widget', () {
    testWidgets('renders name, plate, connector, capacity and badge', (
      tester,
    ) async {
      await _pumpCard(tester, _vehicle());

      expect(find.text('Tesla Model Y'), findsOneWidget);
      expect(find.text('PCN1234'), findsOneWidget);
      expect(find.text('CCS2 (Type 2)'), findsOneWidget);
      expect(find.text('75 kWh'), findsOneWidget);
      expect(find.text(VehicleCardWidget.defaultBadgeLabel), findsOneWidget);
    });

    testWidgets('hides the Default badge for a non-default vehicle', (
      tester,
    ) async {
      await _pumpCard(tester, _vehicle(isDefault: false));

      expect(find.text(VehicleCardWidget.defaultBadgeLabel), findsNothing);
    });

    testWidgets('shows a decimal capacity without rounding it away', (
      tester,
    ) async {
      await _pumpCard(tester, _vehicle(batteryCapacity: 72.6));

      expect(find.text('72.6 kWh'), findsOneWidget);
    });
  });
}
