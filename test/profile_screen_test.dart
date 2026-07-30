import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AppUser _user = AppUser(
  id: 'usr_demo',
  name: 'Aisyah Rahman',
  email: 'aisyah@example.com',
  createdAt: DateTime(2025, 3, 1),
);

Vehicle _vehicle({bool isDefault = true}) => Vehicle(
  id: 'veh_1',
  userId: 'usr_demo',
  name: 'Tesla Model Y',
  licensePlate: 'PCN1234',
  connectorType: 'CCS2',
  batteryCapacity: 75,
  isDefault: isDefault,
);

final List<CpoPartner> _cpos = [
  CpoPartner(
    id: 'cpo_voltgo',
    name: 'VoltGo',
    countryCode: 'MY',
    partyId: 'MYVLT',
    colorHex: '#0D9488',
  ),
  CpoPartner(
    id: 'cpo_chargesync',
    name: 'ChargeSync',
    countryCode: 'MY',
    partyId: 'MYCSY',
    colorHex: '#2563EB',
  ),
  CpoPartner(
    id: 'cpo_ecowatt',
    name: 'EcoWatt',
    countryCode: 'MY',
    partyId: 'MYECO',
    colorHex: '#16A34A',
  ),
];

Future<void> _pumpProfile(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
  await tester.pumpAndSettle();
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
    currentUserNotifier.value = _user;
    walletBalanceNotifier.value = 85.5;
    vehiclesNotifier.value = [_vehicle()];
    cposNotifier.value = _cpos;
  });

  tearDown(() {
    currentUserNotifier.value = null;
    walletBalanceNotifier.value = 0.0;
    vehiclesNotifier.value = [];
    cposNotifier.value = [];
  });

  group('ProfileScreen', () {
    testWidgets('stacks user, wallet, vehicles and sign out', (tester) async {
      await _pumpProfile(tester);

      expect(find.text('Aisyah Rahman'), findsOneWidget);
      expect(find.text('ChargeNet Wallet'), findsOneWidget);
      expect(find.text('RM 85.50'), findsOneWidget);
      expect(find.text('My Vehicles'), findsOneWidget);
      expect(find.text('Roaming network'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('keeps saved vehicles without a roaming catalogue on Profile', (
      tester,
    ) async {
      await _pumpProfile(tester);

      expect(find.text('Tesla Model Y'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('3 operators connected, one wallet'), findsNothing);
      expect(find.text('VoltGo'), findsNothing);
      expect(find.text('ChargeSync'), findsNothing);
      expect(find.text('EcoWatt'), findsNothing);
    });

    testWidgets('shows the empty garage call to action without a vehicle', (
      tester,
    ) async {
      vehiclesNotifier.value = [];

      await _pumpProfile(tester);

      expect(
        find.text('Add your EV to get compatible chargers'),
        findsOneWidget,
      );
      expect(find.text('Add vehicle'), findsOneWidget);
      expect(find.text('Tesla Model Y'), findsNothing);
    });

    testWidgets('keeps the wallet card visible while partners load', (
      tester,
    ) async {
      cposNotifier.value = [];

      await _pumpProfile(tester);

      expect(find.text('Roaming partners are loading…'), findsNothing);
      expect(find.text('RM 85.50'), findsOneWidget);
    });
  });
}
