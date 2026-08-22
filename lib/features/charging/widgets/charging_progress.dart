import 'package:flutter/material.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/core/format.dart';

/// Battery percentage is absolute (0–100), with the session target in words.
/// Missing telemetry stays unknown and never becomes an animated zero.
class ChargingProgress extends StatelessWidget {
  const ChargingProgress({
    super.key,
    required this.socPercent,
    this.targetPercent,
  });
  final double? socPercent;
  final double? targetPercent;

  @override
  Widget build(BuildContext context) {
    final soc = socPercent?.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Battery',
          style: AppTypography.body.copyWith(color: AppDesign.secondaryText),
        ),
        const SizedBox(height: 8),
        Text(
          formatPercent(soc),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (soc != null)
          LinearProgressIndicator(
            value: soc / 100,
            minHeight: 8,
            color: AppDesign.primary,
            backgroundColor: AppDesign.border,
            semanticsLabel: 'Battery charge',
            semanticsValue: formatPercent(soc),
          ),
        if (soc == null)
          const Text(
            'Waiting for battery reading',
            style: TextStyle(color: AppDesign.secondaryText),
          ),
        if (targetPercent != null) ...[
          const SizedBox(height: 12),
          Text(
            'Charging to ${targetPercent!.round()} %',
            style: AppTypography.body.copyWith(color: AppDesign.secondaryText),
          ),
        ],
      ],
    );
  }
}
