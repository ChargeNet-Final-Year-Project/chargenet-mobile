import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/widgets/data_slice.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/profile/screens/transactions_screen.dart';
import 'package:chargenet_mobile/features/profile/widgets/topup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The single wallet card that replaces the old stack of three fake
/// payment-method cards.
///
/// The light account panel shows the live balance from
/// [walletBalanceNotifier], a hide/show toggle that survives restarts, a
/// `Top Up` action and a link to the full ledger.
class WalletCardWidget extends StatefulWidget {
  const WalletCardWidget({super.key});

  /// What a hidden balance shows instead of the amount.
  static const String hiddenBalance = 'RM ••••';

  /// `85.5` → `RM 85.50`, `1234.5` → `RM 1,234.50`.
  static String formatBalance(double balance) =>
      formatMoney(balance, walletCurrencyNotifier.value);

  @override
  State<WalletCardWidget> createState() => _WalletCardWidgetState();
}

class _WalletCardWidgetState extends State<WalletCardWidget> {
  final _balanceScroll = ScrollController();
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    _restoreVisibility();
  }

  @override
  void dispose() {
    _balanceScroll.dispose();
    super.dispose();
  }

  /// The hide/show choice is remembered across launches.
  Future<void> _restoreVisibility() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(KConstants.walletBalanceVisible);
    if (!mounted || stored == null) return;
    setState(() => _balanceVisible = stored);
  }

  Future<void> _toggleVisibility() async {
    setState(() => _balanceVisible = !_balanceVisible);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KConstants.walletBalanceVisible, _balanceVisible);
  }

  Future<void> _openTopUp() async {
    final toppedUp = await TopUpSheet.show(context);
    // The sheet updates the notifiers itself; `toppedUp` only drives feedback.
    if (!mounted || toppedUp != true) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Wallet topped up')));
  }

  void _openHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TransactionsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return DataSlice(
      state: walletLoadNotifier,
      label: 'wallet',
      onRetry: AppStateService.instance.refreshWallet,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        decoration: BoxDecoration(
          color: AppDesign.surface,
          border: Border.all(color: AppDesign.border),
          borderRadius: BorderRadius.circular(KConstants.circularBorderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppDesign.secondaryText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ChargeNet Wallet',
                    style: AppTypography.label.copyWith(
                      color: AppDesign.secondaryText,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleVisibility,
                  tooltip: _balanceVisible ? 'Hide balance' : 'Show balance',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _balanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppDesign.secondaryText,
                    size: 20,
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<double>(
              valueListenable: walletBalanceNotifier,
              builder: (context, balance, child) => ScrollbarTheme(
                data: const ScrollbarThemeData(
                  thumbColor: WidgetStatePropertyAll(AppDesign.secondaryText),
                ),
                child: Scrollbar(
                  controller: _balanceScroll,
                  thumbVisibility: true,
                  thickness: 3,
                  child: SingleChildScrollView(
                    controller: _balanceScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _balanceVisible
                          ? WalletCardWidget.formatBalance(balance)
                          : walletCurrencyNotifier.value == 'MYR'
                          ? WalletCardWidget.hiddenBalance
                          : '${walletCurrencyNotifier.value} \u2022\u2022\u2022\u2022',
                      style: AppTypography.walletValue.copyWith(
                        color: AppDesign.ink,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: walletReservedNotifier,
              builder: (context, held, _) => held <= 0
                  ? const SizedBox.shrink()
                  : Text(
                      '${formatMoney(held, walletCurrencyNotifier.value)} held for charging',
                      style: AppTypography.caption,
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _openTopUp,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Top Up'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesign.primary,
                    foregroundColor: AppDesign.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesign.primary,
                  ),
                  child: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
