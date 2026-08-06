import 'package:flutter/material.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';

/// Displays the backend's estimate; pricing is checked again when starting.
class ChargingQuotePanel extends StatelessWidget {
  const ChargingQuotePanel({
    super.key,
    required this.quote,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final ChargingQuote? quote;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final theme = Theme.of(context);
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Estimated total', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Calculating estimated cost',
            ),
          if (error != null)
            Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          if (q != null) ...[
            Text(
              formatDecimalMoney(q.estimatedWalletCost, q.walletCurrency),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            line(
              'Charging rate',
              '${formatTariff(num.parse(q.tariffPerKwh), q.originalCurrency)} / kWh',
            ),
            if (q.hasConversion) ...[
              line(
                'Exchange rate',
                '1 ${q.originalCurrency} = ${num.parse(q.exchangeRate)} ${q.walletCurrency}',
              ),
              Text(
                'Simulated rate. Fixed for this session when you start.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'For about ${num.parse(q.estimatedKwh)} kWh. You pay for the energy delivered.',
              style: theme.textTheme.bodySmall,
            ),
            if (num.parse(q.estimatedWalletCost) > num.parse(q.budget))
              Text(
                'Your estimate exceeds your available funds. Charging will stop at the spending limit.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            Text(
              'Up to ${formatDecimalMoney(q.budget, q.walletCurrency)} will be reserved from your wallet. Unused funds are released after charging.',
              style: theme.textTheme.bodySmall,
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: const Text('Payment details'),
              children: [
                if (q.hasConversion) ...[
                  line(
                    'Estimated local cost',
                    formatDecimalMoney(
                      q.estimatedOriginalCost,
                      q.originalCurrency,
                    ),
                  ),
                  line(
                    'Wallet rate per kWh',
                    formatTariff(
                      num.parse(q.equivalentTariff),
                      q.walletCurrency,
                    ),
                  ),
                ],
                Text(
                  'Pricing is checked when you start. If it changes, review the updated total before confirming. The accepted charging rate${q.hasConversion ? ' and exchange rate stay' : ' stays'} fixed for this session.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: loading ? null : onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}
