import 'package:chargenet_mobile/features/charging/widgets/charging_quote_panel.dart';
import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/widgets/data_slice.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:chargenet_mobile/features/charging/evse_code_parser.dart';
import 'package:chargenet_mobile/features/charging/widgets/qr_viewfinder_widget.dart';
import 'package:chargenet_mobile/features/home/widgets/connector_tile_widget.dart';
import 'package:chargenet_mobile/features/profile/widgets/topup_sheet.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';

typedef EvseLookup = Future<({Station station, Connector connector})> Function(
  String evseUid,
);

typedef SessionStarter = Future<ChargingSession> Function(
  String evseUid, {
  String? vehicleId,
  int targetSoc,
});

enum ChargerActivationMode { scan, manual, confirm }

/// Pre-charge flow: identify the EVSE, pick a vehicle and a target, check the
/// wallet, then start.
///
/// Entry points are the "Start charging" button of a connector tile (the EVSE
/// uid is already known) and the home FAB "Scan QR to Charge" (no uid: the
/// camera opens instead).
class ChargerActivationScreen extends StatefulWidget {
  const ChargerActivationScreen({
    super.key,
    this.evseUid,
    this.lookupEvse,
    this.loadQuote,
    this.startSession,
    this.sessionStream,
  });

  final String? evseUid;

  final EvseLookup? lookupEvse;
  final Future<ChargingQuote> Function(String evseUid, {String estimatedKwh})?
  loadQuote;

  final SessionStarter? startSession;

  /// Overrides the telemetry stream in widget tests.
  final SessionStreamer? sessionStream;

  static const String noVehicle = '__none__';

  static const String scanMessage =
      'Point the camera at the QR code on the charger';

  static const String badCodeMessage =
      "That doesn't look like a ChargeNet charger code";

  static const String notFoundMessage = "We couldn't find that charger";

  static const String scannerBlockedMessage =
      'ChargeNet needs the camera to read a QR code. You can type the code '
      'printed on the charger instead.';

  /// The camera scanner only exists on Android and iOS; desktop, web and the
  /// widget-test platform fall back to manual entry.
  static bool get scannerSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Debug builds offer the seeded EVSE so the flow can be walked without a
  /// camera — only where the scanner cannot run, i.e. `scannerUsable` is false
  ///.
  static bool showSampleEvse({required bool scannerUsable}) =>
      kDebugMode && !scannerUsable;

  static bool hasEnoughBalance(double balance) =>
      balance >= KConstants.minStartBalance;

  static bool canStart({
    required Connector? connector,
    required double balance,
  }) => connector != null && connector.isAvailable && hasEnoughBalance(balance);

  static String? blocker({
    required Connector? connector,
    required double balance,
  }) {
    if (connector == null) return 'This charger is not ready yet.';
    if (!connector.isAvailable) {
      return 'This connector is '
          '${ConnectorTileWidget.statusLabel(connector.status).toLowerCase()}'
          ' right now — try another one.';
    }
    if (!hasEnoughBalance(balance)) {
      return 'Top up to at least ${formatMoney(KConstants.minStartBalance, walletCurrencyNotifier.value)} '
          'to start charging.';
    }
    return null;
  }

  static double estimateKwh({
    required double batteryKwh,
    required double fromSoc,
    required double toSoc,
  }) {
    final delta = toSoc - fromSoc;
    return delta <= 0 ? 0 : delta / 100 * batteryKwh;
  }

  static double estimateMinutes({
    required double kwh,
    required double maxPowerKw,
  }) {
    final averageKw = KConstants.chargingEfficiency * maxPowerKw;
    return averageKw <= 0 ? 0 : kwh / averageKw * 60;
  }

  static double estimateCost({
    required double kwh,
    required double tariffPerKwh,
  }) => round2(kwh * tariffPerKwh);

  static String errorMessage(
    ApiException error, {
    Vehicle? vehicle,
    Connector? connector,
  }) {
    switch (error.code) {
      case 'INSUFFICIENT_BALANCE':
        final required = error.required;
        return required == null
            ? error.message
            : 'Your wallet needs at least ${formatMyr(required)} to start.';
      case 'CONNECTOR_UNAVAILABLE':
        return 'That connector was taken. Pick another one.';
      case 'SESSION_ALREADY_ACTIVE':
        return 'You already have a charging session running.';
      case 'INCOMPATIBLE_CONNECTOR':
        if (vehicle == null || connector == null) return error.message;
        return '${vehicle.name} '
            '(${ConnectorTileWidget.standardLabel(vehicle.connectorType)}) '
            'cannot use this '
            '${ConnectorTileWidget.standardLabel(connector.standard)} '
            'connector.';
      case 'CPO_UNREACHABLE':
        return 'This charge point operator is offline. Try again in a moment.';
      case 'EVSE_NOT_FOUND':
        return notFoundMessage;
      case 'VALIDATION_ERROR':
        final fields = error.fields.values;
        return fields.isEmpty ? error.message : fields.join(' ');
      default:
        return error.message;
    }
  }

  @override
  State<ChargerActivationScreen> createState() =>
      _ChargerActivationScreenState();
}

class _ChargerActivationScreenState extends State<ChargerActivationScreen> {
  late ChargerActivationMode _mode;
  final TextEditingController _manualController = TextEditingController();
  final ScrollController _confirmScroll = ScrollController();
  MobileScannerController? _scannerController;

  ChargingQuote? _quote;
  bool _quoteLoading = false;
  String? _quoteError;
  int _quoteGeneration = 0;
  Station? _station;
  Connector? _connector;

  String _resolvedUid = '';

  String _selectedVehicle = ChargerActivationScreen.noVehicle;

  double _targetSoc = KConstants.defaultTargetSoc;

  bool _loading = false;

  bool _starting = false;

  String? _error;

  String? _scanNotice;

  ApiService get _api => ApiService.instance;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = _defaultVehicleId();
    _targetSoc = KConstants.defaultTargetSoc;
    _mode = ChargerActivationMode.manual;

    final preset = widget.evseUid;
    if (preset != null) {
      _mode = ChargerActivationMode.confirm;
      _resolve(preset);
    } else if (ChargerActivationScreen.scannerSupported) {
      _mode = ChargerActivationMode.scan;
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    _confirmScroll.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  String _defaultVehicleId() {
    final vehicles = vehiclesNotifier.value;
    if (vehicles.isEmpty) return ChargerActivationScreen.noVehicle;
    for (final vehicle in vehicles) {
      if (vehicle.isDefault) return vehicle.id;
    }
    return vehicles.first.id;
  }

  Vehicle? get _vehicle {
    for (final vehicle in vehiclesNotifier.value) {
      if (vehicle.id == _selectedVehicle) return vehicle;
    }
    return null;
  }

  String? get _vehicleIdForStart =>
      _selectedVehicle == ChargerActivationScreen.noVehicle
      ? null
      : _selectedVehicle;

  Future<({Station station, Connector connector})> _lookup(String uid) {
    final injected = widget.lookupEvse;
    return injected != null ? injected(uid) : _api.lookupEvse(uid);
  }

  Future<ChargingSession> _start({
    required String evseUid,
    required int targetSoc,
    String? vehicleId,
  }) {
    final injected = widget.startSession;
    if (injected != null) {
      return injected(evseUid, vehicleId: vehicleId, targetSoc: targetSoc);
    }
    return AppStateService.instance.startSession(
      evseUid,
      quoteId: _quote!.id,
      vehicleId: vehicleId,
      targetSoc: targetSoc,
    );
  }

  Future<void> _resolve(String code) async {
    final uid = EvseCodeParser.parse(code);
    if (uid == null) {
      setState(() {
        _error = ChargerActivationScreen.badCodeMessage;
        _mode = ChargerActivationMode.manual;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _lookup(uid);
      if (!mounted) return;
      setState(() {
        _station = result.station;
        _connector = result.connector;
        _resolvedUid = uid;
        _selectedVehicle = _defaultVehicleId();
        _loading = false;
        _mode = ChargerActivationMode.confirm;
      });
      await _refreshQuote();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.code == 'EVSE_NOT_FOUND'
            ? ChargerActivationScreen.notFoundMessage
            : e.message;
        _manualController.text = uid;
        _mode = ChargerActivationMode.manual;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not reach ChargeNet. Check your connection and try again.';
        _manualController.text = uid;
        _mode = ChargerActivationMode.manual;
      });
    }
  }

  void _submitManual() {
    if (_manualController.text.trim().isEmpty) {
      setState(() => _error = 'Type the code printed on the charger.');
      return;
    }
    _resolve(_manualController.text);
  }

  void _openManual() {
    setState(() {
      _mode = ChargerActivationMode.manual;
      _error = null;
    });
  }

  /// Debug-only shortcut to the seeded EVSE.
  void _useSampleEvse() {
    _manualController.text = KConstants.sampleEvseUid;
    _resolve(KConstants.sampleEvseUid);
  }

  void _scanAgain() {
    setState(() {
      _station = null;
      _connector = null;
      _resolvedUid = '';
      _error = null;
      _mode = ChargerActivationScreen.scannerSupported
          ? ChargerActivationMode.scan
          : ChargerActivationMode.manual;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_loading) return;

    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    final uid = EvseCodeParser.parse(raw);
    if (uid == null) {
      _flashScanNotice();
      return;
    }

    await _scannerController?.stop();
    await _resolve(uid);
  }

  /// Tells the driver a scanned code was not ours — once, not once per frame
  /// (the camera sees the same barcode many times a second).
  void _flashScanNotice() {
    if (_scanNotice != null) return;
    setState(() => _scanNotice = ChargerActivationScreen.badCodeMessage);
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _scanNotice = null);
    });
  }

  Future<void> _confirmStart() async {
    if (_starting || _quoteLoading) return;
    if (_quote == null) {
      setState(
        () => _quoteError =
            'Review your estimated charging cost before starting.',
      );
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final session = await _start(
        evseUid: _resolvedUid,
        targetSoc: _targetSoc.round(),
        vehicleId: _vehicleIdForStart,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ActiveChargingScreen(
            session: session,
            streamSession: widget.sessionStream,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      if (e.code == 'QUOTE_CHANGED') {
        await _refreshQuote();
        if (!mounted) return;
        setState(
          () => _error = 'Pricing has changed. Review the updated estimated total, then confirm again.',
        );
        if (_confirmScroll.hasClients) {
          unawaited(
            _confirmScroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          );
        }
        return;
      }
      if (e.code.startsWith('QUOTE_')) {
        setState(() {
          _quote = null;
          _quoteError = e.message;
        });
        return;
      }
      final alreadyActive = e.code == 'SESSION_ALREADY_ACTIVE';
      _showError(
        ChargerActivationScreen.errorMessage(
          e,
          vehicle: _vehicle,
          connector: _connector,
        ),
        actionLabel: alreadyActive ? 'Go to active session' : null,
        onAction: alreadyActive ? _openActiveSession : null,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      _showError(
        'Could not start charging. Check your connection and try again.',
      );
    }
  }

  /// Picks up the session that blocked the start and opens the monitor.
  Future<void> _openActiveSession() async {
    var session = activeSessionNotifier.value;
    if (session == null) {
      try {
        await AppStateService.instance.refreshActiveSession();
      } catch (_) {
        // Left null: the message below still explains what happened.
      }
      session = activeSessionNotifier.value;
    }
    if (!mounted) return;

    final active = session;
    if (active == null) {
      _showError('That session has already finished.');
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ActiveChargingScreen(
          session: active,
          streamSession: widget.sessionStream,
        ),
      ),
    );
  }

  void _showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scanning = _mode == ChargerActivationMode.scan;

    return Scaffold(
      appBar: AppBar(
        title: Text(scanning ? 'Scan charger QR' : 'Start charging'),
        // The scanner wants dark chrome so the preview carries the screen.
        backgroundColor: scanning ? Colors.black : null,
        foregroundColor: scanning ? Colors.white : null,
      ),
      body: switch (_mode) {
        ChargerActivationMode.scan => _buildScanView(),
        ChargerActivationMode.manual => _buildManualView(),
        ChargerActivationMode.confirm => _buildConfirmView(),
      },
    );
  }

  Widget _buildScanView() {
    final controller = _scannerController;
    if (controller == null) return _scannerUnavailable(null);

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        // The controller reports camera failures (permission denial included)
        // through its state, so the fallback card replaces the preview.
        final error = state.error;
        if (error != null) return _scannerUnavailable(error);

        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, failure) => _scannerUnavailable(failure),
            ),
            Column(
              children: [
                Expanded(
                  child: QrViewfinderWidget(
                    message: _scanNotice ?? ChargerActivationScreen.scanMessage,
                    torchOn: state.torchState == TorchState.on,
                    onToggleTorch: state.torchState == TorchState.unavailable
                        ? null
                        : controller.toggleTorch,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openManual,
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('Enter code manually'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black.withValues(alpha: .55),
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _scannerUnavailable(MobileScannerException? error) {
    final denied = error?.errorCode == MobileScannerErrorCode.permissionDenied;

    return _ScannerUnavailableCard(
      title: denied
          ? 'Camera access is turned off'
          : 'Scanning is unavailable here',
      onManualEntry: _openManual,
      // The camera just failed, so a debug build may as well offer the seeded
      // EVSE shortcut.
      onUseSample: ChargerActivationScreen.showSampleEvse(scannerUsable: false)
          ? _useSampleEvse
          : null,
    );
  }

  Widget _buildManualView() {
    final theme = Theme.of(context);
    final sampleAvailable = ChargerActivationScreen.showSampleEvse(
      scannerUsable: ChargerActivationScreen.scannerSupported,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.qr_code_2, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Enter the charger code', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'It is printed on the charger, beside the QR code.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _manualController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: const [_UpperCaseFormatter()],
          onSubmitted: (_) => _submitManual(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            letterSpacing: 1.5,
          ),
          decoration: InputDecoration(
            labelText: 'EVSE code',
            hintText: KConstants.sampleEvseUid,
            prefixIcon: const Icon(Icons.ev_station),
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loading ? null : _submitManual,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: const Text('Find charger'),
        ),
        const SizedBox(height: 12),
        Text(
          'You can also paste a ChargeNet link, e.g. '
          'chargenet://${KConstants.evseCodeHost}/${KConstants.sampleEvseUid}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (sampleAvailable)
          TextButton.icon(
            onPressed: _loading ? null : _useSampleEvse,
            icon: const Icon(Icons.bug_report_outlined),
            label: Text('Use sample EVSE (${KConstants.sampleEvseUid})'),
          ),
        if (ChargerActivationScreen.scannerSupported)
          TextButton.icon(
            onPressed: _scanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan a QR code instead'),
          ),
      ],
    );
  }

  /// "About 35.7 kWh · ~115 min · RM 25.00" for the current vehicle/target, or
  /// `null` when no vehicle is selected.
  String? get _estimateLine {
    final connector = _connector;
    final vehicle = _vehicle;
    if (connector == null || vehicle == null) return null;

    final kwh = ChargerActivationScreen.estimateKwh(
      batteryKwh: vehicle.batteryCapacity,
      fromSoc: KConstants.assumedStartSoc,
      toSoc: _targetSoc,
    );
    final minutes = ChargerActivationScreen.estimateMinutes(
      kwh: kwh,
      maxPowerKw: connector.maxPowerKw,
    );
    return 'About ${formatKwh(kwh)} \u00b7 ~${minutes.round()} min';
  }

  Widget _buildConfirmView() {
    final station = _station;
    final connector = _connector;
    if (_loading || station == null || connector == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return DataSlice(
      state: walletLoadNotifier,
      label: 'wallet',
      onRetry: AppStateService.instance.refreshWallet,
      expand: true,
      child: ValueListenableBuilder<double>(
        valueListenable: walletBalanceNotifier,
        builder: (context, balance, _) {
          final blocker = ChargerActivationScreen.blocker(
            connector: connector,
            balance: balance - walletReservedNotifier.value,
          );

          return ListView(
            controller: _confirmScroll,
            padding: const EdgeInsets.all(16),
            children: [
              _StationHeader(
                station: station,
                connector: connector,
                evseUid: _resolvedUid,
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ChargingQuotePanel(
                quote: _quote,
                loading: _quoteLoading,
                error: _quoteError,
                onRetry: () => unawaited(_refreshQuote()),
              ),
              const SizedBox(height: 24),
              _vehicleField(),
              const SizedBox(height: 24),
              _targetSocField(),
              const SizedBox(height: 20),
              _WalletCheckRow(
                balance: balance - walletReservedNotifier.value,
                onTopUp: _openTopUp,
              ),
              const SizedBox(height: 24),
              SlideToConfirm(
                label: 'Confirm and start',
                confirmationTitle: 'Start charging',
                confirmationMessage:
                    '${station.name}\n'
                    '${_quote == null ? '' : 'Estimated total: ${formatDecimalMoney(_quote!.estimatedWalletCost, _quote!.walletCurrency)}\nCharging rate: ${formatTariff(num.parse(_quote!.tariffPerKwh), _quote!.originalCurrency)} / kWh\n${_quote!.hasConversion ? '1 ${_quote!.originalCurrency} = ${num.parse(_quote!.exchangeRate)} ${_quote!.walletCurrency} (simulated)\n' : ''}Spending limit: ${formatDecimalMoney(_quote!.budget, _quote!.walletCurrency)}'}\n'
                    'Start charging with these payment details?',
                enabled: blocker == null && _quote != null && !_quoteLoading,
                loading: _starting,
                hint: blocker,
                onConfirmed: _confirmStart,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _starting ? null : _scanAgain,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(
                  ChargerActivationScreen.scannerSupported
                      ? 'Scan a different charger'
                      : 'Enter a different code',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Vehicle picker; "No vehicle" is allowed.
  Widget _vehicleField() {
    return ValueListenableBuilder<List<Vehicle>>(
      valueListenable: vehiclesNotifier,
      builder: (context, vehicles, _) {
        final known = vehicles.any((vehicle) => vehicle.id == _selectedVehicle);
        final value = known
            ? _selectedVehicle
            : ChargerActivationScreen.noVehicle;

        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Vehicle',
            prefixIcon: Icon(Icons.directions_car_outlined),
            border: OutlineInputBorder(),
            helperText: 'Used for the compatibility check and the estimate.',
            helperMaxLines: 3,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: ChargerActivationScreen.noVehicle,
              child: Text('No vehicle'),
            ),
            for (final vehicle in vehicles)
              DropdownMenuItem<String>(
                value: vehicle.id,
                child: Text(
                  '${vehicle.name} · '
                  '${ConnectorTileWidget.standardLabel(vehicle.connectorType)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _starting
              ? null
              : (value) {
                  setState(
                    () => _selectedVehicle =
                        value ?? ChargerActivationScreen.noVehicle,
                  );
                  unawaited(_refreshQuote());
                },
        );
      },
    );
  }

  Widget _targetSocField() {
    final theme = Theme.of(context);
    final estimate = _estimateLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Charge to', style: theme.textTheme.titleMedium),
            Text(
              '${_targetSoc.round()} %',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: _targetSoc,
          min: KConstants.minTargetSoc,
          max: KConstants.maxTargetSoc,
          divisions: KConstants.targetSocDivisions,
          label: '${_targetSoc.round()} %',
          onChanged: _starting
              ? null
              : (value) => setState(() {
                  _targetSoc = value;
                  _quote = null;
                  _quoteGeneration++;
                  _quoteLoading = false;
                }),
          onChangeEnd: _starting ? null : (_) => unawaited(_refreshQuote()),
        ),
        Text(
          estimate == null
              ? 'The cost estimate assumes 15 kWh. Select a vehicle for an energy and time estimate.'
              : '$estimate · assumes the car starts near '
                    '${KConstants.assumedStartSoc.round()} %.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _openTopUp() async {
    await TopUpSheet.show(context);
    if (mounted) await _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    if (_starting || _resolvedUid.isEmpty) return;
    final generation = ++_quoteGeneration;
    final uid = _resolvedUid;
    setState(() {
      _quoteLoading = true;
      _quote = null;
      _quoteError = null;
    });
    try {
      final v = _vehicle;
      final energy = v == null
          ? 15.0
          : ChargerActivationScreen.estimateKwh(
              batteryKwh: v.batteryCapacity,
              fromSoc: KConstants.assumedStartSoc,
              toSoc: _targetSoc,
            );
      final loader = widget.loadQuote ?? _api.createQuote;
      final quote = await loader(
        uid,
        estimatedKwh: energy.clamp(0.001, 250).toStringAsFixed(3),
      );
      if (!mounted || generation != _quoteGeneration || uid != _resolvedUid) {
        return;
      }
      setState(() {
        _quote = quote;
        _quoteLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _quoteGeneration) return;
      setState(() {
        _quoteLoading = false;
        _quoteError = error is ApiException
            ? error.message
            : 'Could not calculate the estimated cost. Please try again.';
      });
    }
  }
}

/// CPO-coloured summary of the charger the driver is about to use.
class _StationHeader extends StatelessWidget {
  const _StationHeader({
    required this.station,
    required this.connector,
    required this.evseUid,
  });

  final Station station;
  final Connector connector;
  final String evseUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(station.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${ConnectorTileWidget.standardLabel(connector.standard)} \u00b7 ${formatKw(connector.maxPowerKw)} \u00b7 ${ConnectorTileWidget.statusLabel(connector.status)}',
          style: theme.textTheme.bodyMedium,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Charger details'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${station.cpoName}\n${station.address}\nEVSE $evseUid',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WalletCheckRow extends StatelessWidget {
  const _WalletCheckRow({required this.balance, required this.onTopUp});

  final double balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enough = ChargerActivationScreen.hasEnoughBalance(balance);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              enough
                  ? Icons.account_balance_wallet_outlined
                  : Icons.error_outline,
              color: enough
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available wallet funds',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    formatMoney(balance, walletCurrencyNotifier.value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!enough)
                    Text(
                      'At least ${formatMoney(KConstants.minStartBalance, walletCurrencyNotifier.value)} is '
                      'needed to start.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            if (!enough)
              FilledButton(onPressed: onTopUp, child: const Text('Top up')),
          ],
        ),
      ),
    );
  }
}

class _ScannerUnavailableCard extends StatelessWidget {
  const _ScannerUnavailableCard({
    required this.title,
    required this.onManualEntry,
    this.onUseSample,
  });

  final String title;
  final VoidCallback onManualEntry;

  final VoidCallback? onUseSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              ChargerActivationScreen.scannerBlockedMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onManualEntry,
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Enter code manually'),
            ),
            if (onUseSample != null)
              TextButton.icon(
                onPressed: onUseSample,
                icon: const Icon(Icons.bug_report_outlined),
                label: Text('Use sample EVSE (${KConstants.sampleEvseUid})'),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
