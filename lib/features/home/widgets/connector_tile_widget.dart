import 'package:chargenet_mobile/core/format.dart';
import 'package:flutter/material.dart';

import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/data/enums/ev_connector_type.dart';
import 'package:chargenet_mobile/data/models.dart';

/// One connector row inside the station detail sheet.
///
/// Shows the standard, its rating and tariff plus a live status badge, and a
/// "Start charging" button that is enabled only while the connector reports
/// [Connector.isAvailable].
class ConnectorTileWidget extends StatelessWidget {
  const ConnectorTileWidget({
    super.key,
    required this.connector,
    this.onStartCharging,
  });

  final Connector connector;

  /// Invoked by the enabled "Start charging" button.
  final ValueChanged<Connector>? onStartCharging;

  /// Tint used for both the status badge and the action button.
  static Color statusColor(String status) {
    switch (status) {
      case 'AVAILABLE':
        return AppDesign.success;
      case 'CHARGING':
        return AppDesign.caution;
      case 'BLOCKED':
        return AppDesign.danger;
      default:
        return AppDesign.offline;
    }
  }

  /// `AVAILABLE` → `Available`.
  static String statusLabel(String status) {
    final trimmed = status.trim();
    if (trimmed.isEmpty) return 'Unknown';

    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  /// Friendly standard name, falling back to the raw API value.
  static String standardLabel(String standard) {
    try {
      return EvConnectorType.fromApi(standard).displayName;
    } on ArgumentError {
      return standard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(connector.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  standardLabel(connector.standard),
                  style: theme.textTheme.titleSmall,
                ),
                _StatusBadge(
                  label: statusLabel(connector.status),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${connector.powerType} · '
              '${connector.maxPowerKw.toStringAsFixed(0)} kW · '
              '${formatTariff(connector.tariffPerKwh, connector.currency)} / kWh',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: connector.isAvailable
                    ? () => onStartCharging?.call(connector)
                    : null,
                icon: const Icon(Icons.bolt),
                label: const Text('Start charging'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small coloured pill naming the connector's live state.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
