import 'package:flutter/material.dart';

import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/data/models.dart';

/// A CPO-branded station pin for the home map.
///
/// * the inner badge is filled with the operator's brand colour and carries a
///   white bolt;
/// * the outer ring encodes live availability:
///   * **green** – at least one bay free;
///   * **amber** – the station is live but fully occupied;
///   * **grey**  – the station is off the air (inactive, or every connector
///     reported `INOPERATIVE`);
/// * the chip underneath shows `available/total` bays.
class StationMarkerWidget extends StatelessWidget {
  const StationMarkerWidget({super.key, required this.station, this.onTap});

  final Station station;

  /// Tapping a marker selects the station (the detail sheet lands in station discovery).
  final VoidCallback? onTap;

  /// Key of the outer ring, so widget tests can assert the live status colour.
  static const Key ringKey = Key('station-marker-ring');

  /// Key of the CPO-coloured badge.
  static const Key badgeKey = Key('station-marker-badge');

  static const Color availableRingColor = AppDesign.success;
  static const Color busyRingColor = AppDesign.caution;
  static const Color offlineRingColor = AppDesign.offline;

  /// Connector state that takes an otherwise-live station off the air.
  static const String inoperativeStatus = 'INOPERATIVE';

  /// Green / amber / grey rule described on the class.
  ///
  /// A station with no connector rows at all is judged by [Station.isActive]
  /// and its bay counts alone.
  static Color ringColorFor(Station station) {
    if (!station.isActive) return offlineRingColor;

    final connectors = station.connectors;
    if (connectors.isNotEmpty &&
        connectors.every(
          (connector) => connector.status == inoperativeStatus,
        )) {
      return offlineRingColor;
    }

    return station.availableBays > 0 ? availableRingColor : busyRingColor;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: ringKey,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ringColorFor(station), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                key: badgeKey,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorFromHex(station.cpoColorHex),
                ),
                child: Icon(
                  Icons.bolt,
                  size: 16,
                  color: foregroundOnBrand(colorFromHex(station.cpoColorHex)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          _BayChip(label: '${station.availableBays}/${station.totalBays}'),
        ],
      ),
    );
  }
}

/// The `available/total` read-out pinned under a marker.
class _BayChip extends StatelessWidget {
  const _BayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
