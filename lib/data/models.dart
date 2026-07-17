/// The signed-in driver, as returned by `/auth/me` and the auth endpoints.
class AppUser {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
  };
}

class CpoPartner {
  final String id;
  final String name;
  final String countryCode;
  final String partyId;
  final String colorHex;

  const CpoPartner({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.partyId,
    required this.colorHex,
  });

  factory CpoPartner.fromJson(Map<String, dynamic> json) => CpoPartner(
    id: json['id'] as String,
    name: json['name'] as String,
    countryCode: json['countryCode'] as String,
    partyId: json['partyId'] as String,
    colorHex: json['colorHex'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'countryCode': countryCode,
    'partyId': partyId,
    'colorHex': colorHex,
  };
}

class Connector {
  final String currency;
  final String? tariffId;
  final String id;
  final String stationId;
  final String evseUid;
  final String standard;
  final String format;
  final String powerType;
  final double maxPowerKw;
  final double tariffPerKwh;
  final String status;

  const Connector({
    this.currency = 'MYR',
    this.tariffId,
    required this.id,
    required this.stationId,
    required this.evseUid,
    required this.standard,
    required this.format,
    required this.powerType,
    required this.maxPowerKw,
    required this.tariffPerKwh,
    required this.status,
  });

  /// True while the connector can be started.
  bool get isAvailable => status == 'AVAILABLE';

  factory Connector.fromJson(Map<String, dynamic> json) => Connector(
    currency: json['currency'] as String? ?? 'MYR',
    tariffId: json['tariffId'] as String?,
    id: json['id'] as String,
    stationId: json['stationId'] as String,
    evseUid: json['evseUid'] as String,
    standard: json['standard'] as String,
    format: json['format'] as String,
    powerType: json['powerType'] as String,
    maxPowerKw: (json['maxPowerKw'] as num).toDouble(),
    tariffPerKwh: (json['tariffPerKwh'] as num).toDouble(),
    status: json['status'] as String,
  );

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'tariffId': tariffId,
    'id': id,
    'stationId': stationId,
    'evseUid': evseUid,
    'standard': standard,
    'format': format,
    'powerType': powerType,
    'maxPowerKw': maxPowerKw,
    'tariffPerKwh': tariffPerKwh,
    'status': status,
  };
}

class Station {
  final String region;
  final String countryCode;
  final bool isSimulated;
  final String id;
  final String cpoId;
  final String cpoName;
  final String cpoColorHex;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final int totalBays;
  final int availableBays;
  final bool isActive;
  final double? distanceKm;
  final List<Connector> connectors;

  const Station({
    this.region = '',
    this.countryCode = 'MY',
    this.isSimulated = false,
    required this.id,
    required this.cpoId,
    required this.cpoName,
    required this.cpoColorHex,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.totalBays,
    required this.availableBays,
    required this.isActive,
    this.distanceKm,
    required this.connectors,
  });

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    region: json['region'] as String? ?? '',
    countryCode: json['countryCode'] as String? ?? 'MY',
    isSimulated: json['isSimulated'] as bool? ?? false,
    id: json['id'] as String,
    cpoId: json['cpoId'] as String,
    cpoName: json['cpoName'] as String,
    cpoColorHex: json['cpoColorHex'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    city: json['city'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    totalBays: json['totalBays'] as int,
    availableBays: json['availableBays'] as int,
    isActive: json['isActive'] as bool,
    distanceKm: json['distanceKm'] != null
        ? (json['distanceKm'] as num).toDouble()
        : null,
    connectors: (json['connectors'] as List<dynamic>? ?? [])
        .map((e) => Connector.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Highest power any connector here can deliver, in kW (0 with no data).
  double get maxPowerKw {
    var max = 0.0;

    for (final connector in connectors) {
      if (connector.maxPowerKw > max) max = connector.maxPowerKw;
    }

    return max;
  }

  /// True when at least one connector is DC.
  bool get hasDc => connectors.any((connector) => connector.powerType == 'DC');

  Map<String, dynamic> toJson() => {
    'region': region,
    'countryCode': countryCode,
    'isSimulated': isSimulated,
    'id': id,
    'cpoId': cpoId,
    'cpoName': cpoName,
    'cpoColorHex': cpoColorHex,
    'name': name,
    'address': address,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'totalBays': totalBays,
    'availableBays': availableBays,
    'isActive': isActive,
    'distanceKm': distanceKm,
    'connectors': connectors.map((c) => c.toJson()).toList(),
  };
}

class Wallet {
  final double reserved;
  final double? availableBalance;
  final String id;
  final String userId;
  final double balance;
  final String currency;

  const Wallet({
    this.reserved = 0,
    this.availableBalance,
    required this.id,
    required this.userId,
    required this.balance,
    required this.currency,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    reserved: (json['reserved'] as num?)?.toDouble() ?? 0,
    availableBalance: (json['availableBalance'] as num?)?.toDouble(),
    id: json['id'] as String,
    userId: json['userId'] as String,
    balance: (json['balance'] as num).toDouble(),
    currency: json['currency'] as String,
  );

  Map<String, dynamic> toJson() => {
    'reserved': reserved,
    'availableBalance': availableBalance,
    'id': id,
    'userId': userId,
    'balance': balance,
    'currency': currency,
  };
}

class WalletTransaction {
  final String currency;
  final String id;
  final String walletId;
  final String type;
  final double amount;
  final String paymentMethod;
  final String referenceId;
  final String status;
  final DateTime createdAt;

  const WalletTransaction({
    this.currency = 'MYR',
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    required this.referenceId,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        currency: json['currency'] as String? ?? 'MYR',
        id: json['id'] as String,
        walletId: json['walletId'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['paymentMethod'] as String,
        referenceId: json['referenceId'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'id': id,
    'walletId': walletId,
    'type': type,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'referenceId': referenceId,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}

class Vehicle {
  final String id;
  final String userId;
  final String name;
  final String licensePlate;
  final String connectorType;
  final double batteryCapacity;
  final bool isDefault;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    required this.licensePlate,
    required this.connectorType,
    required this.batteryCapacity,
    required this.isDefault,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    licensePlate: json['licensePlate'] as String,
    connectorType: json['connectorType'] as String,
    batteryCapacity: (json['batteryCapacity'] as num).toDouble(),
    isDefault: json['isDefault'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'licensePlate': licensePlate,
    'connectorType': connectorType,
    'batteryCapacity': batteryCapacity,
    'isDefault': isDefault,
  };
}

class ChargingSession {
  final String? quoteId;
  final String originalCurrency;
  final String walletCurrency;
  final String exchangeRate;
  final String rateSource;
  final double? originalCost;
  final double? reservedAmount;
  final double unfundedAmount;

  final String id;
  final String userId;
  final String? vehicleId;
  final String cpoId;
  final String cpoName;
  final String stationId;
  final String stationName;
  final String connectorId;
  final String evseUid;
  final String connectorType;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final double? kwhDelivered;
  final double? currentPowerKw;
  final double? batterySoc;
  final double? targetSoc;
  final double tariffPerKwh;
  final double? totalCost;
  final double? balanceAfter;
  final String? stopReason;
  final String? cdrId;
  final Map<String, dynamic>? cdrJson;

  const ChargingSession({
    this.quoteId,
    this.originalCurrency = 'MYR',
    this.walletCurrency = 'MYR',
    this.exchangeRate = '1',
    this.rateSource = 'same-currency',
    this.originalCost,
    this.reservedAmount,
    this.unfundedAmount = 0,

    required this.id,
    required this.userId,
    this.vehicleId,
    required this.cpoId,
    required this.cpoName,
    required this.stationId,
    required this.stationName,
    required this.connectorId,
    required this.evseUid,
    required this.connectorType,
    required this.status,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.kwhDelivered,
    this.currentPowerKw,
    this.batterySoc,
    this.targetSoc,
    required this.tariffPerKwh,
    this.totalCost,
    this.balanceAfter,
    this.stopReason,
    this.cdrId,
    this.cdrJson,
  });

  factory ChargingSession.fromJson(Map<String, dynamic> json) =>
      ChargingSession(
        quoteId: json['quoteId'] as String?,
        originalCurrency: json['originalCurrency'] as String? ?? 'MYR',
        walletCurrency: json['walletCurrency'] as String? ?? 'MYR',
        exchangeRate: json['exchangeRate']?.toString() ?? '1',
        rateSource: json['rateSource'] as String? ?? 'same-currency',
        originalCost: (json['originalCost'] as num?)?.toDouble(),
        reservedAmount: (json['reservedAmount'] as num?)?.toDouble(),
        unfundedAmount: (json['unfundedAmount'] as num?)?.toDouble() ?? 0,
        id: json['id'] as String,
        userId: json['userId'] as String,
        vehicleId: json['vehicleId'] as String?,
        cpoId: json['cpoId'] as String,
        cpoName: json['cpoName'] as String,
        stationId: json['stationId'] as String,
        stationName: json['stationName'] as String,
        connectorId: json['connectorId'] as String,
        evseUid: json['evseUid'] as String,
        connectorType: json['connectorType'] as String,
        status: json['status'] as String,
        startTime: json['startTime'] != null
            ? DateTime.parse(json['startTime'] as String)
            : null,
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        durationSeconds: json['durationSeconds'] as int?,
        kwhDelivered: json['kwhDelivered'] != null
            ? (json['kwhDelivered'] as num).toDouble()
            : null,
        currentPowerKw: json['currentPowerKw'] != null
            ? (json['currentPowerKw'] as num).toDouble()
            : null,
        batterySoc: json['batterySoc'] != null
            ? (json['batterySoc'] as num).toDouble()
            : null,
        targetSoc: json['targetSoc'] != null
            ? (json['targetSoc'] as num).toDouble()
            : null,
        tariffPerKwh: (json['tariffPerKwh'] as num).toDouble(),
        totalCost: json['totalCost'] != null
            ? (json['totalCost'] as num).toDouble()
            : null,
        balanceAfter: json['balanceAfter'] != null
            ? (json['balanceAfter'] as num).toDouble()
            : null,
        stopReason: json['stopReason'] as String?,
        cdrId: json['cdrId'] as String?,
        cdrJson: json['cdrJson'] == null
            ? null
            : Map<String, dynamic>.from(json['cdrJson'] as Map),
      );

  Map<String, dynamic> toJson() => {
    'quoteId': quoteId,
    'originalCurrency': originalCurrency,
    'walletCurrency': walletCurrency,
    'exchangeRate': exchangeRate,
    'rateSource': rateSource,
    'originalCost': originalCost,
    'reservedAmount': reservedAmount,
    'unfundedAmount': unfundedAmount,
    'id': id,
    'userId': userId,
    'vehicleId': vehicleId,
    'cpoId': cpoId,
    'cpoName': cpoName,
    'stationId': stationId,
    'stationName': stationName,
    'connectorId': connectorId,
    'evseUid': evseUid,
    'connectorType': connectorType,
    'status': status,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'kwhDelivered': kwhDelivered,
    'currentPowerKw': currentPowerKw,
    'batterySoc': batterySoc,
    'targetSoc': targetSoc,
    'tariffPerKwh': tariffPerKwh,
    'totalCost': totalCost,
    'balanceAfter': balanceAfter,
    'stopReason': stopReason,
    'cdrId': cdrId,
    'cdrJson': cdrJson,
  };
}

/// An immutable backend quotation. Decimal strings are retained for display;
/// acceptance and all financial calculations are authoritative in PostgreSQL.
class ChargingQuote {
  final String id, tariffPerKwh, originalCurrency, walletCurrency, exchangeRate;
  final String equivalentTariff, estimatedKwh, estimatedOriginalCost;
  final String estimatedWalletCost, budget, rateSource;
  const ChargingQuote({
    required this.id,
    required this.tariffPerKwh,
    required this.originalCurrency,
    required this.walletCurrency,
    required this.exchangeRate,
    required this.equivalentTariff,
    required this.estimatedKwh,
    required this.estimatedOriginalCost,
    required this.estimatedWalletCost,
    required this.budget,
    required this.rateSource,
  });
  bool get hasConversion => originalCurrency != walletCurrency;
  factory ChargingQuote.fromJson(Map<String, dynamic> j) => ChargingQuote(
    id: j['id'] as String,
    tariffPerKwh: j['tariffPerKwh'].toString(),
    originalCurrency: j['originalCurrency'] as String,
    walletCurrency: j['walletCurrency'] as String,
    exchangeRate: j['exchangeRate'].toString(),
    equivalentTariff: j['equivalentTariff'].toString(),
    estimatedKwh: j['estimatedKwh'].toString(),
    estimatedOriginalCost: j['estimatedOriginalCost'].toString(),
    estimatedWalletCost: j['estimatedWalletCost'].toString(),
    budget: j['budget'].toString(),
    rateSource: j['rateSource'] as String,
  );
}
