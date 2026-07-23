import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/home/widgets/connector_tile_widget.dart';

/// The sliding station card shown over the map while the home screen has a
/// selected station.
///
/// It is deliberately **not** a `showModalBottomSheet`: the sheet lives inside
/// the home `Stack` so the map behind it stays interactive, and it is built on
/// [DraggableScrollableSheet] so it can be dragged from a peek to near full
/// screen.
class StationDetailBottomSheet extends StatelessWidget {
  const StationDetailBottomSheet({
    super.key,
    required this.station,
    required this.onDismiss,
    this.userLocation,
    this.onStartCharging,
  });

  /// Peek height, minimum (handle only) and maximum (near full screen).
  static const double initialSize = 0.38;
  static const double minSize = 0.15;
  static const double maxSize = 0.9;

  final Station station;

  /// Called when the sheet is dragged back down to [minSize].
  final VoidCallback onDismiss;

  /// Used to compute the distance when the API sent no `distanceKm`.
  final LatLng? userLocation;

  /// Forwarded to every [ConnectorTileWidget].
  final ValueChanged<Connector>? onStartCharging;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // Dragging the sheet down to its minimum dismisses it, matching the
        // map-tap dismissal path.
        if (notification.extent <= notification.minExtent + 0.01) {
          onDismiss();
        }

        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        snap: true,
        builder: (context, scrollController) =>
            _buildSheet(context, scrollController),
      ),
    );
  }

  /// `distanceKm` from the API, else a device-side great-circle estimate.
  double? get _distanceKm {
    final apiDistance = station.distanceKm;
    if (apiDistance != null) return apiDistance;

    final origin = userLocation;
    if (origin == null) return null;

    return Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          station.latitude,
          station.longitude,
        ) /
        1000;
  }

  /// `DC fast · up to 350 kW`, or just the type when nothing is published.
  String get _powerLine {
    final kind = station.hasDc ? 'DC fast' : 'AC';

    if (station.connectors.isEmpty) return kind;

    return '$kind · up to ${station.maxPowerKw.toStringAsFixed(0)} kW';
  }

  /// No maps SDK in scope: the address goes to the clipboard and the
  /// snack bar tells the user it is there.
  Future<void> _copyAddress(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(
      ClipboardData(
        text:
            '${station.name}, ${'${station.address}${station.isSimulated ? ' ? Simulated station' : ''}'}, ${station.city}',
      ),
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Address copied to the clipboard.')),
      );
  }

  Widget _buildSheet(BuildContext context, ScrollController scrollController) {
    final theme = Theme.of(context);
    final distanceKm = _distanceKm;
    final connectors = station.connectors;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(KConstants.circularBorderRadius),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _CpoPill(
                name: station.cpoName,
                color: colorFromHex(station.cpoColorHex),
              ),
              if (distanceKm != null)
                Text(
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: theme.textTheme.labelLarge,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(station.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${'${station.address}${station.isSimulated ? ' ? Simulated station' : ''}'}, ${station.city}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(_powerLine, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          _BayCounter(
            availableBays: station.availableBays,
            totalBays: station.totalBays,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _copyAddress(context),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Get directions'),
          ),
          const SizedBox(height: 16),
          Text('Connectors', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (connectors.isEmpty)
            const Text('No connectors are published for this station.')
          else
            for (final connector in connectors)
              ConnectorTileWidget(
                connector: connector,
                onStartCharging: onStartCharging,
              ),
        ],
      ),
    );
  }
}

/// Operator name pill tinted with the CPO's brand colour.
class _CpoPill extends StatelessWidget {
  const _CpoPill({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: foregroundOnBrand(color),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// The `3 of 4 bays free` summary line.
class _BayCounter extends StatelessWidget {
  const _BayCounter({required this.availableBays, required this.totalBays});

  final int availableBays;
  final int totalBays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.ev_station, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$availableBays of $totalBays bays free',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
