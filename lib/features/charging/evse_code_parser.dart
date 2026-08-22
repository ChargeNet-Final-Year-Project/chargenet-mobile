import 'package:chargenet_mobile/data/constants.dart';

/// Normalises whatever a QR scan or a keypad produces into an EVSE uid
///.
///
/// Accepted forms:
/// * the bare uid — `VLT-SGB-01`;
/// * the ChargeNet deep link — `chargenet://evse/VLT-SGB-01`;
/// * any https link that carries an `/evse/<uid>` segment —
///   `https://chargenet.my/evse/VLT-SGB-01`.
///
/// The result is trimmed and upper-cased. Anything else (empty input, a link to
/// another kind of resource, stray punctuation) returns `null` so the caller can
/// show "not a ChargeNet charger code" instead of firing off a doomed lookup.
class EvseCodeParser {
  /// Accept legacy codes and OCPI-style IDs (SG*CSY*E*D12DC), including
  /// ChargeNet's colon suffix for a second connector on the same EVSE.
  static final RegExp _uidPattern = RegExp(r'^[A-Z0-9][A-Z0-9*:_-]{2,63}$');

  /// The uid carried by [raw], or `null` when it is not an EVSE code.
  static String? parse(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;

    final candidate = value.contains('://') ? _fromUri(value) : value;
    if (candidate == null) return null;

    final normalized = candidate.trim().toUpperCase();
    return _uidPattern.hasMatch(normalized) ? normalized : null;
  }

  /// True when [value] already looks like a normalised EVSE uid.
  static bool isValidUid(String value) =>
      _uidPattern.hasMatch(value.trim().toUpperCase());

  /// The uid segment of a deep link or URL, or `null` when the payload does not
  /// point at an EVSE.
  static String? _fromUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    // `chargenet://evse/<uid>` keeps the resource kind in the host.
    if (uri.scheme == KConstants.evseCodeScheme &&
        uri.host == KConstants.evseCodeHost) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }

    return _afterEvseSegment(uri.pathSegments);
  }

  /// The segment following an `evse` path segment (`/evse/<uid>`).
  static String? _afterEvseSegment(List<String> segments) {
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i].toUpperCase() == KConstants.evseCodeHost.toUpperCase()) {
        return segments[i + 1];
      }
    }
    return null;
  }
}
