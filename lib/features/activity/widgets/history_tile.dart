import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.session,
    required this.cpos,
    this.onTap,
  });

  final ChargingSession session;

  final List<CpoPartner> cpos;

  final VoidCallback? onTap;

  static const String failedLabel = 'Failed';

  static const Color failedColor = AppDesign.danger;

  static bool isFailed(ChargingSession session) => session.status == 'FAILED';

  static DateTime? momentOf(ChargingSession session) =>
      session.startTime ?? session.endTime;

  static String dateLabel(ChargingSession session) =>
      formatDayMonth(momentOf(session));

  static String detailLabel(ChargingSession session) =>
      '${energyLabel(session)} · ${formatDuration(session.durationSeconds)}';

  static String energyLabel(ChargingSession session) {
    final kwh = session.kwhDelivered;
    return kwh == null ? kNoValue : formatKwh(kwh);
  }

  /// `RM 31.36` — what the wallet was charged, so the backend's `totalCost`
  /// when it has priced the session, else the `kWh × tariff` estimate.
  static String costLabel(ChargingSession session) {
    final cost =
        session.totalCost ??
        (session.originalCurrency == session.walletCurrency
            ? energyCost(session.kwhDelivered, session.tariffPerKwh)
            : null);
    return cost == null ? kNoValue : formatMoney(cost, session.walletCurrency);
  }

  @override
  Widget build(BuildContext context) {
    final accent = cpoAccentColor(session.cpoId, cpos);
    final failed = isFailed(session);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(Icons.bolt, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.stationName,
                      style: AppTypography.listTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel(session),
                      style: AppTypography.caption.copyWith(
                        color: AppDesign.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detailLabel(session),
                      style: AppTypography.caption.copyWith(
                        color: AppDesign.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    costLabel(session),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.35,
                      fontFeatures: AppTypography.numbers,
                    ),
                  ),
                  if (failed) ...[
                    const SizedBox(height: 6),
                    const _StatusChip(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HistoryTile.failedColor.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: const Text(
        HistoryTile.failedLabel,
        style: TextStyle(
          color: HistoryTile.failedColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class HistoryMonth {
  const HistoryMonth({required this.label, required this.sessions});

  final String label;

  final List<ChargingSession> sessions;

  static const String undatedLabel = 'Earlier';

  static String labelFor(DateTime moment) =>
      DateFormat('MMMM yyyy').format(moment.toLocal());

  /// Buckets [sessions] — already newest-first, as the API returns them — into
  /// consecutive months, keeping that order inside each bucket.
  ///
  /// Starts a new bucket whenever the label changes, preserving API order.
  static List<HistoryMonth> group(List<ChargingSession> sessions) {
    final months = <HistoryMonth>[];

    for (final session in sessions) {
      final moment = HistoryTile.momentOf(session);
      final label = moment == null ? undatedLabel : labelFor(moment);

      if (months.isEmpty || months.last.label != label) {
        months.add(HistoryMonth(label: label, sessions: <ChargingSession>[]));
      }
      months.last.sessions.add(session);
    }

    return months;
  }
}

sealed class HistoryRow {
  const HistoryRow();

  static List<HistoryRow> flatten(List<HistoryMonth> months) => [
    for (final month in months) ...[
      HistoryHeader(month.label),
      for (final session in month.sessions) HistorySession(session),
    ],
  ];
}

class HistoryHeader extends HistoryRow {
  const HistoryHeader(this.label);

  final String label;
}

class HistorySession extends HistoryRow {
  const HistorySession(this.session);

  final ChargingSession session;
}
