enum EvConnectorType {
  ccs2('CCS2 (Type 2)', 'CCS2'),
  type2('Type 2 (AC)', 'TYPE2'),
  japan('CHAdeMO', 'CHADEMO'),
  nacs('NACS', 'NACS'),
  ccs1('CCS1 (Type 1)', 'CCS1'),
  china('GB/T', 'GBT');

  final String displayName;

  /// Canonical uppercase value used by the API and the database.
  final String apiValue;

  const EvConnectorType(this.displayName, this.apiValue);

  /// Maps a canonical API value (`CCS2`, `TYPE2`, …) onto the enum.
  ///
  /// Throws [ArgumentError] for anything unknown so a server-side enum change
  /// fails loudly instead of silently mis-mapping.
  static EvConnectorType fromApi(String value) {
    final needle = value.trim().toUpperCase();
    for (final type in values) {
      if (type.apiValue == needle) return type;
    }
    throw ArgumentError('Unknown connector standard: $value');
  }
}
