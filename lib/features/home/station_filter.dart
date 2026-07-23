/// Filters are applied together by the backend to the same connector.
class StationFilter {
  const StationFilter({
    this.query = '',
    bool dcFast = false,
    String? powerType,
    this.country,
    this.region,
    this.minPowerKw,
    this.maxPowerKw,
    this.connectorType,
    this.availableOnly = false,
    this.cpoId,
  }) : powerType = powerType ?? (dcFast ? 'DC' : null);

  final String query;
  final String? country;
  final String? region;
  final String? powerType;
  final double? minPowerKw;
  final double? maxPowerKw;
  final String? connectorType;
  final bool availableOnly;
  final String? cpoId;

  bool get dcFast => powerType == 'DC';
  int get activeCount => [
    country != null || region != null,
    powerType != null,
    minPowerKw != null || maxPowerKw != null,
    connectorType != null,
    availableOnly,
    cpoId != null,
  ].where((active) => active).length;
  bool get isActive => query.isNotEmpty || activeCount > 0;

  StationFilter copyWith({
    String? query,
    String? country,
    String? region,
    String? powerType,
    bool? dcFast,
    double? minPowerKw,
    double? maxPowerKw,
    String? connectorType,
    bool? availableOnly,
    String? cpoId,
    bool clearCountry = false,
    bool clearRegion = false,
    bool clearPowerType = false,
    bool clearMinPower = false,
    bool clearMaxPower = false,
    bool clearConnectorType = false,
    bool clearCpoId = false,
  }) => StationFilter(
    query: query ?? this.query,
    country: clearCountry ? null : country ?? this.country,
    region: clearCountry || clearRegion
        ? null
        : region ??
              (country != null && country != this.country ? null : this.region),
    powerType: clearPowerType || dcFast == false
        ? null
        : dcFast == true
        ? 'DC'
        : powerType ?? this.powerType,
    minPowerKw: clearMinPower ? null : minPowerKw ?? this.minPowerKw,
    maxPowerKw: clearMaxPower ? null : maxPowerKw ?? this.maxPowerKw,
    connectorType: clearConnectorType
        ? null
        : connectorType ?? this.connectorType,
    availableOnly: availableOnly ?? this.availableOnly,
    cpoId: clearCpoId ? null : cpoId ?? this.cpoId,
  );
}

class StationRegion {
  const StationRegion({
    required this.countryCode,
    required this.name,
    required this.stationCount,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
  final String countryCode;
  final String name;
  final int stationCount;
  final double south, west, north, east;
  factory StationRegion.fromJson(Map<String, dynamic> json) => StationRegion(
    countryCode: json['countryCode'] as String,
    name: json['name'] as String,
    stationCount: json['stationCount'] as int,
    south: (json['south'] as num).toDouble(),
    west: (json['west'] as num).toDouble(),
    north: (json['north'] as num).toDouble(),
    east: (json['east'] as num).toDouble(),
  );
}
