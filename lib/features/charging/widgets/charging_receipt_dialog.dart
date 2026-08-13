import 'dart:math' as math;

import 'package:chargenet_mobile/core/app_theme.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/charging/stop_reason.dart';
import 'package:chargenet_mobile/services/session_stream_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showChargingReceipt(
  BuildContext context,
  ChargingSession session,
) {
  if (!isSessionTerminal(session.status)) {
    throw ArgumentError(
      'A final receipt requires a confirmed terminal session.',
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    backgroundColor: ChargingReceipt.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Theme(
      data: ChargingReceipt.theme,
      child: ChargingReceipt(session: session),
    ),
  );
}

typedef ReceiptRow = ({String label, String value});

/// Every figure comes from the [ChargingSession] the backend returned
/// (`totalCost`, `kwhDelivered`, `tariffPerKwh`, `balanceAfter`, `cdrId`), so a
/// receipt and the wallet's `CHARGING_DEBIT` row for the same session always
/// agree. The CDR's `chargenet.platform_fee` is deliberately *not* rendered: it
/// is ChargeNet's share of the tariff, not something the driver is billed for.
class ChargingReceipt extends StatelessWidget {
  const ChargingReceipt({super.key, required this.session});

  final ChargingSession session;

  // Keep receipt paper light under dark host themes.

  static const Color paper = AppDesign.surface;
  static const Color ink = AppDesign.ink;
  static const Color muted = AppDesign.secondaryText;
  static const Color rule = AppDesign.border;
  static const Color success = AppDesign.success;
  static const Color danger = AppDesign.danger;

  static ThemeData get theme =>
      AppTheme.light.copyWith(scaffoldBackgroundColor: paper);

  static const Key dividerKey = Key('chargingReceiptDivider');

  static const String completeLabel = 'Charging complete';
  static const String failedLabel = 'Charging failed';
  static const String doneLabel = 'Done';
  static const String copyLabel = 'Copy receipt';
  static const String copiedMessage = 'Receipt copied to the clipboard.';

  static const String dateRowLabel = 'Date & time';
  static const String chargerRowLabel = 'Charger';
  static const String energyRowLabel = 'Energy delivered';
  static const String durationRowLabel = 'Duration';
  static const String rateRowLabel = 'Rate';
  static const String subtotalRowLabel = 'Subtotal';
  static const String paidRowLabel = 'Paid from wallet';
  static const String balanceRowLabel = 'Remaining balance';
  static const String stopReasonRowLabel = 'Stop reason';
  static const String receiptNoRowLabel = 'Receipt no.';

  /// `FAILED` is the only terminal status that reads as a failure; a session
  /// that simply reached its target is a success.
  static bool isFailed(ChargingSession session) => session.status == 'FAILED';

  static String resultLabel(ChargingSession session) =>
      session.status == 'COMPLETED'
      ? completeLabel
      : isFailed(session)
      ? failedLabel
      : 'Completion unconfirmed';

  /// `kwh × tariff`, rounded the way the backend rounds, or `null` before the
  /// session has delivered anything.
  static double? subtotalOf(ChargingSession session) =>
      energyCost(session.kwhDelivered, session.tariffPerKwh);

  /// Paid money requires the server's settlement amount; an energy estimate
  /// cannot establish a wallet debit.
  static double? chargedOf(ChargingSession session) => session.totalCost;

  static DateTime? momentOf(ChargingSession session) =>
      session.startTime ?? session.endTime;

  static String money(num? amount, [String currency = 'MYR']) =>
      amount == null ? kNoValue : formatMoney(amount, currency);

  static String energyLabel(ChargingSession session) {
    final kwh = session.kwhDelivered;
    return kwh == null ? kNoValue : formatKwh(kwh, decimals: 3);
  }

  /// Omits stop reason and receipt number when the backend did not provide them.
  static List<ReceiptRow> detailRows(ChargingSession session) {
    final reason = stopReasonLabel(session.stopReason);

    return [
      (label: dateRowLabel, value: formatDateTime(momentOf(session))),
      (
        label: chargerRowLabel,
        value: '${session.evseUid} · ${session.connectorType}',
      ),
      (label: energyRowLabel, value: energyLabel(session)),
      (label: durationRowLabel, value: formatDuration(session.durationSeconds)),
      (
        label: rateRowLabel,
        value:
            '${formatTariff(session.tariffPerKwh, session.originalCurrency)} / kWh',
      ),
      (
        label: subtotalRowLabel,
        value: money(
          session.originalCost ?? subtotalOf(session),
          session.originalCurrency,
        ),
      ),
      if (session.originalCurrency != session.walletCurrency)
        (
          label: 'Accepted exchange rate',
          value:
              '1 ${session.originalCurrency} = ${num.parse(session.exchangeRate)} ${session.walletCurrency}',
        ),
      (
        label: paidRowLabel,
        value: money(chargedOf(session), session.walletCurrency),
      ),
      (
        label: balanceRowLabel,
        value: money(session.balanceAfter, session.walletCurrency),
      ),
      if (session.unfundedAmount > 0)
        (
          label: 'Covered by ChargeNet',
          value: money(session.unfundedAmount, session.walletCurrency),
        ),
      if (reason != null) (label: stopReasonRowLabel, value: reason),
      if (session.cdrId != null)
        (label: receiptNoRowLabel, value: session.cdrId!),
    ];
  }

  /// Uses [detailRows] so copied and displayed receipts stay in sync.
  static String plainText(ChargingSession session) {
    final buffer = StringBuffer()
      ..writeln('ChargeNet receipt')
      ..writeln(resultLabel(session))
      ..writeln('${session.cpoName} · ${session.stationName}')
      ..writeln('Total: ${money(chargedOf(session), session.walletCurrency)}')
      ..writeln();

    for (final row in detailRows(session)) {
      buffer.writeln('${row.label}: ${row.value}');
    }

    return buffer.toString().trimRight();
  }

  Future<void> _copy(BuildContext context) async {
    // Taken before the await: if the sheet closes while the clipboard write is
    // in flight the button's context is already gone.
    final messenger = ScaffoldMessenger.maybeOf(context);

    await Clipboard.setData(ClipboardData(text: plainText(session)));

    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(copiedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final failed = isFailed(session);
    final completed = session.status == 'COMPLETED';
    final accent = failed
        ? danger
        : completed
        ? success
        : muted;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Icon(
                failed
                    ? Icons.error_outline_rounded
                    : completed
                    ? Icons.check_circle_rounded
                    : Icons.help_outline_rounded,
                size: 46,
                color: accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              resultLabel(session),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              paidRowLabel,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted),
            ),
            Text(
              money(chargedOf(session), session.walletCurrency),
              textAlign: TextAlign.center,
              style: AppTypography.receiptValue.copyWith(color: ink),
            ),
            const SizedBox(height: 12),
            Text(
              session.cpoName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              session.stationName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 16),
            const _DashedRule(key: dividerKey),
            const SizedBox(height: 6),
            for (final row in detailRows(session).where(
              (row) =>
                  row.label != paidRowLabel &&
                  row.label != dateRowLabel &&
                  row.label != chargerRowLabel &&
                  row.label != receiptNoRowLabel,
            ))
              _ReceiptRow(label: row.label, value: row.value),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Receipt details'),
              children: [
                for (final row in detailRows(session).where(
                  (row) =>
                      row.label == dateRowLabel ||
                      row.label == chargerRowLabel ||
                      row.label == receiptNoRowLabel,
                ))
                  _ReceiptRow(label: row.label, value: row.value),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(copyLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: const BorderSide(color: rule, width: 1.2),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text(doneLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: ChargingReceipt.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Flexible, not Expanded: a long receipt number wraps to the next
          // line instead of being clipped.
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ChargingReceipt.ink,
                fontFeatures: AppTypography.numbers,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1.4,
      width: double.infinity,
      child: CustomPaint(painter: _DashedRulePainter()),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter();

  static const double dash = 6;
  static const double gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ChargingReceipt.rule
      ..strokeWidth = size.height;
    final y = size.height / 2;

    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter oldDelegate) => false;
}
