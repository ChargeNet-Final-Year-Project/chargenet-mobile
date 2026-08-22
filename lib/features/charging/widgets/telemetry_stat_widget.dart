import 'package:flutter/material.dart';
import 'package:chargenet_mobile/core/typography.dart';

/// A labelled, left-aligned telemetry reading.
class TelemetryStatWidget extends StatelessWidget {
  const TelemetryStatWidget({
    super.key,
    required this.label,
    required this.value,
  });
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: AppTypography.caption.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      value,
    ],
  );
}
