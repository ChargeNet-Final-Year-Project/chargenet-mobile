import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/enums/ev_connector_type.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('model round-trips (fromJson → toJson is the identity)', () {
    test('AppUser', () {
      final json = <String, dynamic>{
        'id': 'usr_demo',
        'name': 'Demo Driver',
        'email': 'demo@chargenet.my',
        'createdAt': '2026-01-15T08:30:00.000Z',
      };

      final user = AppUser.fromJson(json);

      expect(user.name, 'Demo Driver');
      expect(user.createdAt.isUtc, isTrue);
      expect(user.toJson(), json);
    });

    test('CpoPartner', () {
      final json = <String, dynamic>{
        'id': 'cpo_voltgo',
        'name': 'VoltGo',
        'countryCode': 'MY',
        'partyId': 'MY-VLT',
        'colorHex': '#0D9488',
      };

      expect(CpoPartner.fromJson(json).toJson(), json);
    });

    test('Connector', () {
      final connector = _connectorJson();

      final parsed = Connector.fromJson(connector);

      expect(parsed.evseUid, 'VLT-SGB-01');
      expect(parsed.maxPowerKw, 150.0);
      expect(parsed.tariffPerKwh, 1.4);
      expect(parsed.toJson(), connector);
    });

    test('Station with connectors', () {
      final json = <String, dynamic>{
        ..._stationJson(),
        'distanceKm': 12.4,
        'connectors': <dynamic>[_connectorJson()],
      };

      final station = Station.fromJson(json);

      expect(station.connectors, hasLength(1));
      expect(station.connectors.single.standard, 'CCS2');
      expect(station.distanceKm, 12.4);
      expect(station.toJson(), json);
    });

    test('Station sent without a computed distance', () {
      final json = _stationJson();

      final station = Station.fromJson(json);

      expect(station.distanceKm, isNull);
      expect(station.connectors, isEmpty);
      expect(station.toJson(), json);
    });

    test('Wallet', () {
      final json = <String, dynamic>{
        'reserved': 0.0,
        'availableBalance': null,
        'id': 'wal_1',
        'userId': 'usr_demo',
        'balance': 85.5,
        'currency': 'MYR',
      };

      expect(Wallet.fromJson(json).balance, 85.5);
      expect(Wallet.fromJson(json).toJson(), json);
    });

    test('WalletTransaction', () {
      final json = <String, dynamic>{
        'currency': 'MYR',
        'id': 'wtx_1',
        'walletId': 'wal_1',
        'type': 'TOPUP',
        'amount': 50.0,
        'paymentMethod': 'Maybank FPX',
        'referenceId': 'SIM-1760000000',
        'status': 'SUCCESS',
        'createdAt': '2026-10-06T22:14:21.479Z',
      };

      expect(WalletTransaction.fromJson(json).toJson(), json);
    });

    test('Vehicle', () {
      final json = <String, dynamic>{
        'id': 'veh_1',
        'userId': 'usr_demo',
        'name': 'Proton X50',
        'licensePlate': 'WXY 1234',
        'connectorType': 'CCS2',
        'batteryCapacity': 60.0,
        'isDefault': true,
      };

      expect(Vehicle.fromJson(json).toJson(), json);
    });
  });

  group('ChargingSession', () {
    test('completed session with an object cdrJson', () {
      final json = _completedSessionJson();

      final session = ChargingSession.fromJson(json);

      expect(session.vehicleId, 'veh_1');
      expect(session.stopReason, 'TARGET_REACHED');
      expect(session.balanceAfter, 54.14);
      expect(session.cdrId, 'cdr_1');
      expect(session.cdrJson, isA<Map<String, dynamic>>());
      expect(session.cdrJson!['totalEnergyKwh'], 22.4);
      expect(session.toJson(), json);
    });

    test('running session keeps every optional field null', () {
      final json = <String, dynamic>{
        ..._completedSessionJson(),
        'status': 'CHARGING',
        'endTime': null,
        'durationSeconds': null,
        'kwhDelivered': null,
        'currentPowerKw': null,
        'balanceAfter': null,
        'stopReason': null,
        'cdrId': null,
        'cdrJson': null,
      };

      final session = ChargingSession.fromJson(json);

      expect(session.status, 'CHARGING');
      expect(session.vehicleId, 'veh_1');
      expect(session.cdrJson, isNull);
      expect(session.balanceAfter, isNull);
      expect(session.stopReason, isNull);
      expect(session.endTime, isNull);
      expect(session.toJson(), json);
    });

    test('a vehicle-less session parses vehicleId as null', () {
      final json = <String, dynamic>{
        ..._completedSessionJson(),
        'vehicleId': null,
      };

      expect(ChargingSession.fromJson(json).vehicleId, isNull);
    });
  });

  group('EvConnectorType', () {
    test('fromApi maps every canonical value', () {
      expect(EvConnectorType.fromApi('CCS2'), EvConnectorType.ccs2);
      expect(EvConnectorType.fromApi('TYPE2'), EvConnectorType.type2);
      expect(EvConnectorType.fromApi('CHADEMO'), EvConnectorType.japan);
      expect(EvConnectorType.fromApi('NACS'), EvConnectorType.nacs);
      expect(EvConnectorType.fromApi('CCS1'), EvConnectorType.ccs1);
      expect(EvConnectorType.fromApi('GBT'), EvConnectorType.china);
    });

    test('fromApi tolerates case and surrounding whitespace', () {
      expect(EvConnectorType.fromApi(' chademo '), EvConnectorType.japan);
    });

    test('apiValue round-trips through fromApi', () {
      for (final type in EvConnectorType.values) {
        expect(EvConnectorType.fromApi(type.apiValue), type);
      }
    });

    test('fromApi throws for an unknown standard', () {
      expect(() => EvConnectorType.fromApi('MAGIC'), throwsArgumentError);
    });

    test('display names are unchanged', () {
      expect(EvConnectorType.type2.displayName, 'Type 2 (AC)');
      expect(EvConnectorType.japan.displayName, 'CHAdeMO');
      expect(EvConnectorType.china.displayName, 'GB/T');
    });
  });

  group('KConstants', () {
    test('exposes the API contract defaults', () {
      expect(KConstants.apiPrefix, '/api/v1');
      expect(KConstants.requestTimeout, const Duration(seconds: 15));
      expect(KConstants.minStartBalance, 10.0);
      expect(KConstants.authTokenKey, 'authToken');
    });

    test('apiBaseUrl is always an absolute http URL', () {
      expect(KConstants.apiBaseUrl, startsWith('http://'));
      expect(KConstants.apiBaseUrl, isNot(endsWith('/')));
    });
  });
}

/// Sample Connector payload.
Map<String, dynamic> _connectorJson() => <String, dynamic>{
  'currency': 'MYR',
  'tariffId': null,
  'id': 'con_1',
  'stationId': 'stn_1',
  'evseUid': 'VLT-SGB-01',
  'standard': 'CCS2',
  'format': 'CABLE',
  'powerType': 'DC',
  'maxPowerKw': 150.0,
  'tariffPerKwh': 1.4,
  'status': 'AVAILABLE',
};

/// Sample Station payload without a computed distance or connectors.
Map<String, dynamic> _stationJson() => <String, dynamic>{
  'region': '',
  'countryCode': 'MY',
  'isSimulated': false,
  'id': 'stn_1',
  'cpoId': 'cpo_voltgo',
  'cpoName': 'VoltGo',
  'cpoColorHex': '#0D9488',
  'name': 'VoltGo Sungai Buloh R&R',
  'address': 'North-South Expressway',
  'city': 'Sungai Buloh',
  'latitude': 3.2059,
  'longitude': 101.5799,
  'totalBays': 4,
  'availableBays': 3,
  'isActive': true,
  'distanceKm': null,
  'connectors': <dynamic>[],
};

/// Sample ChargingSession payload as returned after settlement.
Map<String, dynamic> _completedSessionJson() => <String, dynamic>{
  'quoteId': null,
  'originalCurrency': 'MYR',
  'walletCurrency': 'MYR',
  'exchangeRate': '1',
  'rateSource': 'same-currency',
  'originalCost': null,
  'reservedAmount': null,
  'unfundedAmount': 0.0,
  'id': 'ses_1',
  'userId': 'usr_demo',
  'vehicleId': 'veh_1',
  'cpoId': 'cpo_voltgo',
  'cpoName': 'VoltGo',
  'stationId': 'stn_1',
  'stationName': 'VoltGo Sungai Buloh R&R',
  'connectorId': 'con_1',
  'evseUid': 'VLT-SGB-01',
  'connectorType': 'CCS2',
  'status': 'COMPLETED',
  'startTime': '2026-10-06T22:00:00.000Z',
  'endTime': '2026-10-06T22:30:00.000Z',
  'durationSeconds': 1800,
  'kwhDelivered': 22.4,
  'currentPowerKw': 0.0,
  'batterySoc': 80.0,
  'targetSoc': 80.0,
  'tariffPerKwh': 1.4,
  'totalCost': 31.36,
  'balanceAfter': 54.14,
  'stopReason': 'TARGET_REACHED',
  'cdrId': 'cdr_1',
  'cdrJson': <String, dynamic>{
    'cdrId': 'cdr_1',
    'totalEnergyKwh': 22.4,
    'totalCost': 31.36,
  },
};
