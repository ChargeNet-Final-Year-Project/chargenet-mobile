import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/widgets/data_slice.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/profile/widgets/transaction_tile_widget.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';

/// The full wallet ledger, newest first.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  @override
  void initState() {
    super.initState();
    // Normally the profile already refreshed the ledger; this covers a cold
    // open (restart with this screen still on the stack, deep link, …).
    if (transactionsNotifier.value.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      await AppStateService.instance.refreshTransactions();
    } catch (_) {
      // The per-slice status exposes a persistent retry instead of an empty ledger.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet history')),
      body: DataSlice(
        state: transactionsLoadNotifier,
        label: 'wallet history',
        onRetry: _refresh,
        expand: true,
        child: ValueListenableBuilder<List<WalletTransaction>>(
          valueListenable: transactionsNotifier,
          builder: (context, transactions, child) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: transactions.isEmpty
                  ? const _EmptyLedger()
                  : _buildList(transactions),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<WalletTransaction> transactions) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: transactions.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) =>
          TransactionTileWidget(transaction: transactions[index]),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    // A ListView (not a Center) keeps the empty state pull-to-refreshable.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 120, 32, 32),
      children: const [
        Icon(Icons.receipt_long_outlined, size: 52, color: Colors.black26),
        SizedBox(height: 14),
        Text(
          'No transactions yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 6),
        Text(
          'Top up your wallet to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );
  }
}
