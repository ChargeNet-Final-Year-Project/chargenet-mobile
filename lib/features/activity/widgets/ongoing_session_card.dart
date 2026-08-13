import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/charging/widgets/telemetry_stat_widget.dart';
import 'package:flutter/material.dart';
import 'package:chargenet_mobile/core/layout.dart';

class OngoingSessionCard extends StatelessWidget {
  const OngoingSessionCard({
    super.key,
    required this.session,
    required this.cpos,
    required this.onOpen,
  });

  final ChargingSession session;

  final List<CpoPartner> cpos;

  final VoidCallback onOpen;

  static const String title = 'Charging now';
  static const String openLabel = 'Open live monitor';

  static const String powerCaption = 'Power';
  static const String energyCaption = 'Energy';
  static const String costCaption = 'Cost so far';

  /// Returns `null` before the first telemetry frame so the bar stays empty.
  static double? socFraction(ChargingSession session) {
    final soc = session.batterySoc;
    return soc == null ? null : (soc / 100).clamp(0.0, 1.0);
  }

  static String socLabel(ChargingSession session) {
    final target = session.targetSoc;
    final soc = formatPercent(session.batterySoc);
    return target == null ? soc : '$soc · target ${formatPercent(target)}';
  }

  /// What the session has cost so far: the backend's `totalCost` once it has
  /// priced the session, else the same live estimate the monitor shows.
  static double? costSoFar(ChargingSession session) =>
      session.totalCost ??
      (session.originalCurrency == session.walletCurrency
          ? energyCost(session.kwhDelivered, session.tariffPerKwh)
          : null);

  static String powerValue(ChargingSession session) {
    final power = session.currentPowerKw;
    return power == null ? kNoValue : formatKw(power);
  }

  static String energyValue(ChargingSession session) {
    final kwh = session.kwhDelivered;
    return kwh == null ? kNoValue : formatKwh(kwh);
  }

  static String costValue(ChargingSession session) {
    final cost = costSoFar(session);
    return cost == null ? kNoValue : formatMoney(cost, session.walletCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final accent = cpoAccentColor(session.cpoId, cpos);
    const valueStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(KConstants.circularBorderRadius),
        ),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    session.stationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: sessionConnectionNotifier,
                  builder: (context, message, _) => message == null
                      ? _LivePill(color: accent)
                      : const Text(
                          'Stale',
                          style: TextStyle(color: AppDesign.secondaryText),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${session.cpoName} · ${session.evseUid}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ValueListenableBuilder<String?>(
              valueListenable: sessionConnectionNotifier,
              builder: (context, message, _) =>
                  message == null ? const SizedBox.shrink() : Text(message),
            ),
            const SizedBox(height: 14),
            _SocBar(color: accent, fraction: socFraction(session)),
            const SizedBox(height: 8),
            Text(
              socLabel(session),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
                final columns = (constraints.maxWidth / (96 * scale))
                    .floor()
                    .clamp(1, 3);
                final stats = [
                  TelemetryStatWidget(
                    label: powerCaption,
                    value: Text(
                      powerValue(session),
                      style: valueStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TelemetryStatWidget(
                    label: energyCaption,
                    value: Text(
                      energyValue(session),
                      style: valueStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TelemetryStatWidget(
                    label: costCaption,
                    value: Text(
                      costValue(session),
                      style: valueStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ];
                return Wrap(
                  alignment: WrapAlignment.center,
                  runSpacing: AppSpacing.group,
                  children: [
                    for (final stat in stats)
                      SizedBox(
                        width: constraints.maxWidth / columns,
                        child: stat,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text(openLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uses a determinate indicator to avoid a perpetual animation in widget tests.
class _SocBar extends StatelessWidget {
  const _SocBar({required this.fraction, required this.color});

  final double? fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: LinearProgressIndicator(
        value: fraction ?? 0,
        minHeight: 9,
        backgroundColor: color.withValues(alpha: 0.14),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        'Live',
        style: TextStyle(
          color: AppDesign.ink,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
