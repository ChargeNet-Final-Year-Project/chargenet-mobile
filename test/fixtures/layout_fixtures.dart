import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';

const layoutVehicle = Vehicle(
  id: 'layout-vehicle',
  userId: 'layout-driver',
  name: 'Hyundai IONIQ 5 Long Range AWD',
  licensePlate: 'WCH 1234',
  connectorType: 'CCS2',
  batteryCapacity: 77.4,
  isDefault: true,
);
const layoutCpos = [
  CpoPartner(
    id: 'voltgo',
    name: 'VoltGo Metropolitan Network',
    countryCode: 'MY',
    partyId: 'VLT',
    colorHex: '#0D9488',
  ),
  CpoPartner(
    id: 'chargesync',
    name: 'ChargeSync',
    countryCode: 'MY',
    partyId: 'CSY',
    colorHex: '#2563EB',
  ),
  CpoPartner(
    id: 'ecowatt',
    name: 'EcoWatt',
    countryCode: 'MY',
    partyId: 'ECO',
    colorHex: '#16A34A',
  ),
];
const layoutConnector = Connector(
  id: 'layout-connector',
  stationId: 'layout-station',
  evseUid: 'MY*VLT*ELAYOUT00000001',
  standard: 'IEC_62196_T2_COMBO',
  format: 'CABLE',
  powerType: 'DC',
  maxPowerKw: 350,
  tariffPerKwh: 1.6,
  status: 'AVAILABLE',
);
const layoutStation = Station(
  id: 'layout-station',
  cpoId: 'voltgo',
  cpoName: 'VoltGo Metropolitan Network',
  cpoColorHex: '#0D9488',
  name: 'VoltGo Demonstration Station with an Expanded Name',
  address: '123 Jalan Demonstrasi',
  city: 'Kuala Lumpur',
  latitude: 3.14,
  longitude: 101.69,
  totalBays: 40,
  availableBays: 12,
  isActive: true,
  distanceKm: 12.8,
  connectors: [layoutConnector],
);
final layoutSession = ChargingSession(
  id: 'layout-session',
  userId: 'layout-driver',
  cpoId: 'voltgo',
  cpoName: 'VoltGo Metropolitan Network',
  stationId: 'layout-station',
  stationName: 'VoltGo Demonstration Station',
  connectorId: 'layout-connector',
  evseUid: 'MY*VLT*ELAYOUT00000001',
  connectorType: 'CCS2',
  status: 'CHARGING',
  tariffPerKwh: 1.6,
  batterySoc: 58,
  targetSoc: 80,
  currentPowerKw: 124.5,
  kwhDelivered: 88.8,
  durationSeconds: 3600,
);

void seedLayoutFixtures() {
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

  currentUserNotifier.value = AppUser(
    id: 'layout-driver',
    name: 'Aisyah Rahman',
    email: 'aisyah.rahman@example.com',
    createdAt: DateTime(2026, 1, 1),
  );
  vehiclesNotifier.value = [layoutVehicle];
  cposNotifier.value = layoutCpos;
  walletBalanceNotifier.value = 85.5;
}
