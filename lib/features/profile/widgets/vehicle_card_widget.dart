import 'package:chargenet_mobile/data/enums/ev_connector_type.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/profile/screens/vehicle_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:chargenet_mobile/core/layout.dart';

/// One saved EV in the profile's "My Vehicles" section.
class VehicleCardWidget extends StatelessWidget {
  const VehicleCardWidget({super.key, required this.vehicle});

  final Vehicle vehicle;

  /// Shown on the tile when this vehicle is the account's default.
  static const String defaultBadgeLabel = 'Default';

  /// `75` → `75`, `72.6` → `72.6`.
  ///
  /// Shared with [VehicleEditScreen] so the form is prefilled with exactly the
  /// value the card renders.
  static String capacityText(double capacity) {
    final rounded = capacity.roundToDouble();
    return capacity == rounded
        ? rounded.toStringAsFixed(0)
        : capacity.toStringAsFixed(1);
  }

  /// `75` → `75 kWh`, `72.6` → `72.6 kWh`.
  static String batteryLabel(double capacity) =>
      '${capacityText(capacity)} kWh';

  /// Canonical api value → display name, falling back to the
  /// raw value so an unknown backend enum never crashes the list.
  static String connectorLabel(String connectorType) {
    try {
      return EvConnectorType.fromApi(connectorType).displayName;
    } on ArgumentError {
      return connectorType;
    }
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleEditScreen(vehicle: vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.related),
                    Wrap(
                      spacing: AppSpacing.related,
                      runSpacing: AppSpacing.related,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PlatePill(plate: vehicle.licensePlate),
                        if (vehicle.isDefault) const _DefaultBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.related),
                    Wrap(
                      spacing: AppSpacing.group,
                      runSpacing: AppSpacing.related,
                      children: [
                        _VehicleFact(
                          icon: Icons.power,
                          text: connectorLabel(vehicle.connectorType),
                        ),
                        _VehicleFact(
                          icon: Icons.battery_charging_full,
                          text: batteryLabel(vehicle.batteryCapacity),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatePill extends StatelessWidget {
  const _PlatePill({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primary),
        borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(
        plate,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.all(Radius.elliptical(999, 999)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: const Text(
        VehicleCardWidget.defaultBadgeLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _VehicleFact extends StatelessWidget {
  const _VehicleFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: Colors.black54),
      const SizedBox(width: 4),
      Flexible(child: Text(text)),
    ],
  );
}
