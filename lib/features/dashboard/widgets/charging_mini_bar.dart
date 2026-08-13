import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:flutter/material.dart';

import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/models.dart';

/// Persistent charging status shown above the dashboard navigation bar.
class ChargingMiniBar extends StatelessWidget {
  const ChargingMiniBar({
    super.key,
    required this.session,
    required this.onTap,
  });

  final ChargingSession session;

  final VoidCallback onTap;

  /// `58% · 124.5 kW`, with [kNoValue] where the backend has no reading yet.
  static String telemetryLabel(ChargingSession session) {
    final power = session.currentPowerKw;
    return '${formatPercent(session.batterySoc)} · '
        '${power == null ? kNoValue : formatKw(power)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.label.copyWith(color: AppDesign.primary);

    return Material(
      color: AppDesign.primaryTint,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 17, color: AppDesign.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: sessionConnectionNotifier,
                      builder: (context, message, _) => Text(
                        message == null ? 'Charging' : 'Updates interrupted',
                        style: text,
                      ),
                    ),
                    Text(
                      telemetryLabel(session),
                      style: text.copyWith(fontFeatures: AppTypography.numbers),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppDesign.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
