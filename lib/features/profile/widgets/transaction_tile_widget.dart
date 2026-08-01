import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:flutter/material.dart';

/// One row of the wallet ledger.
///
/// The backend always stores the amount as a positive number and lets `type`
/// decide the sign, so the `+`/`−` prefix and the colouring are derived here.
class TransactionTileWidget extends StatelessWidget {
  const TransactionTileWidget({super.key, required this.transaction});

  final WalletTransaction transaction;

  /// Canonical transaction types.
  static const String topUpType = 'TOPUP';
  static const String chargingDebitType = 'CHARGING_DEBIT';

  /// Money in, money out.
  static const Color creditColor = AppDesign.success;
  static const Color debitColor = AppDesign.danger;

  static bool isCredit(WalletTransaction transaction) =>
      transaction.type == topUpType;

  /// `+ RM 50.00` for a top-up, `− RM 31.36` for a charge (U+2212 minus).
  static String amountLabel(WalletTransaction transaction) =>
      '${isCredit(transaction) ? '+' : '−'} '
      '${formatMoney(transaction.amount, transaction.currency)}';

  /// `RM 50.00` — shared with the wallet card so both read identically.
  static String formatAmount(double amount) => formatMyr(amount);

  /// `05 Oct, 3:04 PM` in the driver's local time (shared with the Activity
  /// history rows so every ledger and receipt date reads identically).
  static String dateLabel(DateTime createdAt) => formatDayMonth(createdAt);

  /// The gateway for a top-up, or the charging session for a debit (the
  /// backend labels wallet-funded debits `Wallet`, which reads poorly).
  static String titleLabel(WalletTransaction transaction) =>
      isCredit(transaction) ? transaction.paymentMethod : 'Charging session';

  static Color amountColor(WalletTransaction transaction) =>
      isCredit(transaction) ? creditColor : debitColor;

  static IconData icon(WalletTransaction transaction) =>
      isCredit(transaction) ? Icons.add_circle_outline : Icons.bolt_outlined;

  @override
  Widget build(BuildContext context) {
    final color = amountColor(transaction);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon(transaction), color: color, size: 20),
      ),
      title: Text(titleLabel(transaction), style: AppTypography.listTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel(transaction.createdAt),
            style: AppTypography.caption.copyWith(
              color: AppDesign.secondaryText,
            ),
          ),
          Text(
            'Ref ${transaction.referenceId}',
            style: AppTypography.caption.copyWith(
              color: AppDesign.secondaryText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Text(
        amountLabel(transaction),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 15,
          height: 1.35,
          fontFeatures: AppTypography.numbers,
        ),
      ),
      // The subtitle stacks two lines (date + reference).
      isThreeLine: true,
    );
  }
}
