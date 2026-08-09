import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chargenet_mobile/core/app_theme.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_progress.dart';
import 'package:chargenet_mobile/features/charging/widgets/telemetry_stat_widget.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:chargenet_mobile/services/session_stream_service.dart';
import 'package:chargenet_mobile/services/session_coordinator.dart';
import 'package:chargenet_mobile/widgets/slide_to_confirm.dart';

typedef SessionStreamer = Stream<ChargingSession> Function(String sessionId);

typedef SessionStopper = Future<ChargingSession> Function(String sessionId);

typedef SessionRefresher = Future<void> Function();

/// Shown once a session reaches a terminal status.
typedef SessionFinished = Future<void> Function(
  BuildContext context,
  ChargingSession session,
);

class ActiveChargingScreen extends StatefulWidget {
  const ActiveChargingScreen({
    super.key,
    required this.session,
    this.streamSession,
    this.stopSession,
    this.refreshState,
    this.onFinished,
    this.coordinator,
  });

  final ChargingSession session;

  final SessionStreamer? streamSession;

  final SessionStopper? stopSession;

  final SessionRefresher? refreshState;

  final SessionFinished? onFinished;
  final SessionCoordinator? coordinator;

  static const Color background = AppDesign.background;
  static const Color surface = AppDesign.surface;
  static const Color outline = AppDesign.border;
  static const Color emerald = AppDesign.success;
  static const Color cyan = AppDesign.info;
  static const Color danger = AppDesign.danger;
  static const Color muted = AppDesign.secondaryText;

  static const Duration animDuration = Duration(milliseconds: 600);

  static const String stopLabel = 'Slide to stop';
  static const String finishingLabel = 'Finishing up…';
  static const String reconnectLabel = 'Updates interrupted';

  static ThemeData get lightTheme => AppTheme.light;

  @override
  State<ActiveChargingScreen> createState() => _ActiveChargingScreenState();
}

class _ActiveChargingScreenState extends State<ActiveChargingScreen>
    with WidgetsBindingObserver {
  late ChargingSession _session;
  late final SessionCoordinator _coordinator;
  late final bool _ownsCoordinator;
  bool _stopping = false;
  bool _reconnecting = false;
  bool _finished = false;

  static final TextStyle _statValue = AppTypography.chargingStat.copyWith(
    color: AppDesign.ink,
  );

  static const TextStyle _footStyle = TextStyle(
    fontSize: 13,
    color: ActiveChargingScreen.muted,
  );

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _ownsCoordinator =
        widget.coordinator == null && widget.streamSession != null;
    _coordinator =
        widget.coordinator ??
        (_ownsCoordinator
            ? SessionCoordinator(
                streamSession: widget.streamSession!,
                stopSession:
                    widget.stopSession ?? ApiService.instance.stopSession,
                refreshState:
                    widget.refreshState ??
                    AppStateService.instance.refreshAfterSession,
              )
            : SessionCoordinator.instance);
    _coordinator.addListener(_onUpdate);
    WidgetsBinding.instance.addObserver(this);
    _coordinator.watch(widget.session);
    _session = _coordinator.session ?? widget.session;
    activeSessionNotifier.value = _session;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.removeListener(_onUpdate);
    if (_ownsCoordinator) _coordinator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Production reconnects once through the signed-in owner, even minimised.
    if (_ownsCoordinator && state == AppLifecycleState.resumed) {
      _coordinator.retry();
    }
  }

  void _onUpdate() {
    if (!mounted || _finished) return;
    setState(() {
      _session = _coordinator.session ?? _session;
      _stopping = _coordinator.stopping;
      _reconnecting = _coordinator.interrupted;
    });
    final receipt = _coordinator.takeReceipt();
    if (receipt != null) unawaited(_finish(receipt));
  }

  Future<void> _stop() async {
    try {
      await _coordinator.stop();
    } catch (error) {
      if (!mounted) return;
      _showError(
        error is ApiException && error.statusCode == 0
            ? error.message
            : 'Could not stop charging. Try again.',
      );
    }
  }

  Future<void> _finish(ChargingSession ended) async {
    if (_finished || !isSessionTerminal(ended.status)) return;
    setState(() {
      _finished = true;
      _session = ended;
      _stopping = false;
      _reconnecting = false;
    });
    final present = widget.onFinished ?? showChargingReceipt;
    await present(context, ended);
    if (!mounted) return;
    dashboardTabNotifier.value = DashboardTab.activity;
    Navigator.of(context).maybePop();
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppDesign.surface),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ActiveChargingScreen.danger,
      ),
    );
  }

  /// `totalCost` once the backend has priced the session, otherwise the same
  /// `kwh × tariff` estimate the confirmation panel showed.
  static double? _costOf(ChargingSession session) =>
      session.totalCost ??
      (session.originalCurrency == session.walletCurrency
          ? energyCost(session.kwhDelivered, session.tariffPerKwh)
          : null);

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Theme(
      data: ActiveChargingScreen.lightTheme,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            session: session,
                            reconnecting: _reconnecting,
                            onMinimise: () => Navigator.of(context).maybePop(),
                          ),
                          if (_reconnecting) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _coordinator.unavailable
                                    ? 'Session unavailable. Completion has not been confirmed. Last known readings are shown.'
                                    : 'Live updates interrupted. Last known readings are shown; charging may still be active.',
                              ),
                            ),
                            TextButton(
                              onPressed: _coordinator.retry,
                              child: const Text('Retry live updates'),
                            ),
                          ],
                          const SizedBox(height: 36),
                          Text(
                            'Cost',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _costOf(session) == null
                                ? kNoValue
                                : formatMoney(
                                    _costOf(session)!,
                                    session.walletCurrency,
                                  ),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 24),
                          ChargingProgress(
                            socPercent: session.batterySoc,
                            targetPercent: session.targetSoc,
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 20),
                          _stats(session),
                          if (session.originalCurrency !=
                              session.walletCurrency) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Locked rate: 1 ${session.originalCurrency} = ${num.parse(session.exchangeRate)} ${session.walletCurrency}',
                              style: _footStyle,
                            ),
                            if (session.originalCost != null)
                              Text(
                                'Local cost: ${formatMoney(session.originalCost!, session.originalCurrency)}',
                                style: _footStyle,
                              ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            '${formatTariff(session.tariffPerKwh, session.originalCurrency)} / kWh',
                            style: _footStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: SlideToConfirm(
                      label: ActiveChargingScreen.stopLabel,
                      confirmationTitle: 'Stop charging',
                      confirmationMessage:
                          '${session.stationName}\n${session.evseUid}\n'
                          'Tariff: ${formatTariff(session.tariffPerKwh, session.originalCurrency)} / kWh\n'
                          'Current cost: ${_costOf(session) == null ? kNoValue : formatMoney(_costOf(session)!, session.walletCurrency)}\n'
                          'Stop this charging session?',
                      icon: Icons.stop_rounded,
                      color: ActiveChargingScreen.danger,
                      enabled: !_finished,
                      loading: _stopping,
                      onConfirmed: _stop,
                    ),
                  ),
                ],
              ),
            ),
            if (_stopping) const _FinishingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _stats(ChargingSession session) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth >= 240 * scale ? 2 : 1;
      final stats = [
        TelemetryStatWidget(
          label: 'Charging speed',
          value: Text(
            session.currentPowerKw == null
                ? kNoValue
                : formatKw(session.currentPowerKw!),
            style: _statValue,
          ),
        ),
        TelemetryStatWidget(
          label: 'Energy added',
          value: Text(
            session.kwhDelivered == null
                ? kNoValue
                : formatKwh(session.kwhDelivered!),
            style: _statValue,
          ),
        ),
        TelemetryStatWidget(
          label: 'Duration',
          value: Text(
            session.durationSeconds == null
                ? kNoValue
                : formatClock(session.durationSeconds!),
            style: _statValue,
          ),
        ),
      ];
      return Wrap(
        runSpacing: 24,
        spacing: 16,
        children: [
          for (final stat in stats)
            SizedBox(
              width: (constraints.maxWidth - 16 * (columns - 1)) / columns,
              child: stat,
            ),
        ],
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.reconnecting,
    required this.onMinimise,
  });

  final ChargingSession session;
  final bool reconnecting;
  final VoidCallback onMinimise;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.stationName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppDesign.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${session.cpoName} · ${session.evseUid}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ActiveChargingScreen.muted,
                ),
              ),
              const SizedBox(height: 10),
              // Wrap, not Row: the status, the connector chip and the reconnect
              // pill all have to survive a narrow phone.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusDot(status: session.status),
                  Text(
                    _statusLabel(session.status),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppDesign.secondaryText,
                    ),
                  ),
                  _ConnectorChip(label: session.connectorType),
                  if (reconnecting) const _ReconnectPill(),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onMinimise,
          tooltip: 'Minimise',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          color: AppDesign.secondaryText,
        ),
      ],
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'CHARGING' => 'Charging',
  'PENDING' || 'STARTING' || 'PREPARING' => 'Connecting…',
  'COMPLETED' => 'Completed',
  'FAILED' => 'Failed',
  _ => status,
};

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'CHARGING' => ActiveChargingScreen.emerald,
      'COMPLETED' => ActiveChargingScreen.cyan,
      'FAILED' => ActiveChargingScreen.danger,
      _ => ActiveChargingScreen.muted,
    };

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ConnectorChip extends StatelessWidget {
  const _ConnectorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesign.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppDesign.secondaryText,
        ),
      ),
    );
  }
}

/// Static state avoids a perpetual animation in widget tests.
class _ReconnectPill extends StatelessWidget {
  const _ReconnectPill();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.wifi_tethering_rounded,
          size: 13,
          color: ActiveChargingScreen.danger,
        ),
        SizedBox(width: 4),
        Flexible(
          child: Text(
            ActiveChargingScreen.reconnectLabel,
            style: TextStyle(
              fontSize: 11.5,
              color: ActiveChargingScreen.danger,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Finishing up…" while `POST /sessions/{id}/stop` is in flight. It also swallows taps, so a second slide cannot race the first.
class _FinishingOverlay extends StatelessWidget {
  const _FinishingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(dismissible: false, color: Color(0xF2F6F8FA)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: ActiveChargingScreen.emerald,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  ActiveChargingScreen.finishingLabel,
                  style: TextStyle(fontSize: 15, color: AppDesign.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
