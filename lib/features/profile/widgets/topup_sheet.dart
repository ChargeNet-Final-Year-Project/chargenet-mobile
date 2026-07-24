import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The simulated top-up flow.
///
/// Preset chips + a custom amount field, a payment-method radio list, a
/// minimum one-second processing state and a success animation. The wallet is
/// credited by `POST /wallet/topup`; nothing here is real money.
class TopUpSheet extends StatefulWidget {
  const TopUpSheet({super.key});

  /// The preset amounts offered as chips.
  static const List<double> presets = [20, 50, 100, 200];

  /// How long the "processing" state is held at minimum, so the simulated
  /// gateway never flashes past too fast to read.
  static const Duration processingDelay = Duration(seconds: 1);

  /// How long the success tick stays on screen before the sheet closes.
  static const Duration successDelay = Duration(milliseconds: 900);

  /// Amounts the backend accepts.
  static bool isValidAmount(double? amount) =>
      amount != null &&
      amount >= KConstants.minTopUpAmount &&
      amount <= KConstants.maxTopUpAmount;

  /// A field may hold at most 4 digits and 2 decimals.
  static bool isValidAmountText(String text) =>
      RegExp(r'^\d{0,4}(\.\d{0,2})?$').hasMatch(text.trim());

  /// `amount` → `Pay RM 50.00`.
  static String payLabel(double? amount) => isValidAmount(amount)
      ? 'Pay ${formatMoney(amount!, walletCurrencyNotifier.value)}'
      : 'Pay';

  /// Blocks a keystroke that would push the amount past two decimals.
  static final TextInputFormatter amountFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (newValue.text.isEmpty) return newValue;
        return TopUpSheet.isValidAmountText(newValue.text)
            ? newValue
            : oldValue;
      });

  static IconData iconFor(String paymentMethod) => switch (paymentMethod) {
    KConstants.paymentTouchNGo => Icons.wallet_outlined,
    KConstants.paymentCreditCard => Icons.credit_card_outlined,
    _ => Icons.account_balance_outlined,
  };

  /// Opens the sheet; resolves to `true` once a top-up has been credited.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const TopUpSheet(),
    );
  }

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  final TextEditingController _amountController = TextEditingController();

  String _method = KConstants.paymentMaybankFpx;
  bool _isProcessing = false;
  bool _isDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// The typed amount, or `null` while the field is empty/unparseable.
  double? get _amount => double.tryParse(_amountController.text.trim());

  void _selectPreset(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
    setState(() => _error = null);
  }

  Future<void> _pay() async {
    final amount = _amount;
    if (!TopUpSheet.isValidAmount(amount) || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Kick the request off first so the simulated gateway delay and the
      // minimum processing state overlap instead of stacking.
      final topUp = AppStateService.instance.topUp(amount!, _method);
      await Future<void>.delayed(TopUpSheet.processingDelay);
      await topUp;
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isDone = true;
      });
      await Future<void>.delayed(TopUpSheet.successDelay);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: _isDone ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final amount = _amount;
    final canPay = TopUpSheet.isValidAmount(amount) && !_isProcessing;

    return Column(
      key: const ValueKey('topup-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Top up wallet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Simulated payment — no real money moves.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in TopUpSheet.presets)
              ChoiceChip(
                label: Text(
                  '${walletCurrencyNotifier.value == 'MYR' ? 'RM' : walletCurrencyNotifier.value} ${preset.toStringAsFixed(0)}',
                ),
                selected: amount == preset,
                onSelected: (_) => _selectPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          enabled: !_isProcessing,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [TopUpSheet.amountFormatter],
          decoration: InputDecoration(
            labelText: 'Custom amount',
            prefixText: '${walletCurrencyNotifier.value} ',
            hintText: '0.00',
            helperText:
                'Between ${walletCurrencyNotifier.value} 5 and ${walletCurrencyNotifier.value} 2000',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment method',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        RadioGroup<String>(
          groupValue: _method,
          onChanged: (value) {
            if (value == null || _isProcessing) return;
            setState(() => _method = value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final method in KConstants.paymentMethods)
                RadioListTile<String>(
                  value: method,
                  title: Text(method, style: const TextStyle(fontSize: 14)),
                  secondary: Icon(
                    TopUpSheet.iconFor(method),
                    color: Colors.black54,
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canPay ? _pay : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(TopUpSheet.payLabel(amount)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final amount = _amount;

    return SizedBox(
      key: const ValueKey('topup-success'),
      height: 240,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: MediaQuery.disableAnimationsOf(context) ? 1.0 : 0.6,
              end: 1,
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const Icon(
              Icons.check_circle,
              color: AppDesign.success,
              size: 68,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Top up successful',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (amount != null)
            Text(
              '${formatMoney(amount, walletCurrencyNotifier.value)} '
              'added to your wallet',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
