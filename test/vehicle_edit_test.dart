import 'package:chargenet_mobile/data/enums/ev_connector_type.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/profile/screens/vehicle_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Vehicle _vehicle() => Vehicle(
  id: 'veh_1',
  userId: 'usr_1',
  name: 'Tesla Model Y',
  licensePlate: 'PCN1234',
  connectorType: 'CCS2',
  batteryCapacity: 75,
  isDefault: true,
);

Future<void> _pumpEditor(WidgetTester tester, {Vehicle? vehicle}) {
  return tester.pumpWidget(
    MaterialApp(home: VehicleEditScreen(vehicle: vehicle)),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// The literal text held by the [index]-th [TextFormField].
///
/// `find.text` cannot be used for a prefilled field: Flutter keeps the (hidden)
/// hint widget in the tree, and the hints mirror the demo vehicle's values.
String _fieldText(WidgetTester tester, int index) {
  final field = find.byType(TextFormField).at(index);
  final textField = tester.widget<TextField>(
    find.descendant(of: field, matching: find.byType(TextField)),
  );
  return textField.controller?.text ?? '';
}

void main() {
  group('VehicleEditScreen validation', () {
    test('requires a name', () {
      expect(VehicleEditScreen.validateName(''), 'Enter a vehicle name');
      expect(VehicleEditScreen.validateName('   '), 'Enter a vehicle name');
      expect(VehicleEditScreen.validateName('Tesla Model Y'), isNull);
    });

    test('requires a license plate', () {
      expect(VehicleEditScreen.validatePlate(null), 'Enter the license plate');
      expect(VehicleEditScreen.validatePlate('PCN1234'), isNull);
    });

    test('keeps the capacity between 10 and 250 kWh', () {
      expect(
        VehicleEditScreen.validateBattery(''),
        'Enter the battery capacity',
      );
      expect(
        VehicleEditScreen.validateBattery('abc'),
        'Enter the battery capacity',
      );
      expect(
        VehicleEditScreen.validateBattery('9'),
        'Enter a capacity between 10 and 250 kWh',
      );
      expect(
        VehicleEditScreen.validateBattery('251'),
        'Enter a capacity between 10 and 250 kWh',
      );
      expect(VehicleEditScreen.validateBattery('10'), isNull);
      expect(VehicleEditScreen.validateBattery('250'), isNull);
      expect(VehicleEditScreen.validateBattery('72.6'), isNull);
    });

    test('the capacity field allows three digits and one decimal', () {
      expect(VehicleEditScreen.batteryPattern.hasMatch('72.6'), isTrue);
      expect(VehicleEditScreen.batteryPattern.hasMatch('999'), isTrue);
      expect(VehicleEditScreen.batteryPattern.hasMatch('72.66'), isFalse);
      expect(VehicleEditScreen.batteryPattern.hasMatch('1234'), isFalse);
    });

    test('uppercases plates and drops the characters the API rejects', () {
      final formatted = VehicleEditScreen.plateFormatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'pcn 1234!'),
      );

      expect(formatted.text, 'PCN 1234');
    });

    test('maps an unknown connector onto the CCS2 default', () {
      expect(
        VehicleEditScreen.connectorFromApi('TYPE2'),
        EvConnectorType.type2,
      );
      expect(
        VehicleEditScreen.connectorFromApi('NONSENSE'),
        EvConnectorType.ccs2,
      );
      expect(VehicleEditScreen.connectorFromApi(null), EvConnectorType.ccs2);
    });
  });

  group('VehicleEditScreen form', () {
    testWidgets('add mode shows every validation message', (tester) async {
      await _pumpEditor(tester);

      expect(find.text('Add vehicle'), findsOneWidget);
      expect(find.text('Delete vehicle'), findsNothing);

      await _tapSave(tester);

      expect(find.text('Enter a vehicle name'), findsOneWidget);
      expect(find.text('Enter the license plate'), findsOneWidget);
      expect(find.text('Enter the battery capacity'), findsOneWidget);
    });

    testWidgets('rejects an out-of-range capacity and uppercases the plate', (
      tester,
    ) async {
      await _pumpEditor(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Hyundai Ioniq 5',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wxy5678');
      await tester.enterText(find.byType(TextFormField).at(2), '300');
      await tester.pump();

      expect(find.text('WXY5678'), findsOneWidget);

      await _tapSave(tester);

      expect(
        find.text('Enter a capacity between 10 and 250 kWh'),
        findsOneWidget,
      );
    });

    testWidgets('edit mode prefills the saved vehicle', (tester) async {
      await _pumpEditor(tester, vehicle: _vehicle());

      expect(find.text('Edit vehicle'), findsOneWidget);
      expect(_fieldText(tester, 0), 'Tesla Model Y');
      expect(_fieldText(tester, 1), 'PCN1234');
      expect(_fieldText(tester, 2), '75');
      expect(find.text('CCS2 (Type 2)'), findsWidgets);
      expect(find.text('Delete vehicle'), findsOneWidget);
    });

    testWidgets('delete asks for confirmation first', (tester) async {
      await _pumpEditor(tester, vehicle: _vehicle());

      await tester.tap(find.text('Delete vehicle'));
      await tester.pumpAndSettle();

      expect(find.text('Delete vehicle?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete vehicle?'), findsNothing);
      expect(find.text('Edit vehicle'), findsOneWidget);
    });
  });
}
