import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/widgets/data_slice.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/activity/widgets/history_tile.dart';
import 'package:chargenet_mobile/features/activity/widgets/ongoing_session_card.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';

/// The Activity tab: the session running now, and the receipt archive behind it
///.
///
/// Everything it shows comes from the shared notifiers, so the tab needs no
/// load of its own — a sign-in or a pull-to-refresh fills them, and a running
/// session keeps `activeSessionNotifier` live.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.refresh,
    this.loadMore,
    this.openMonitor,
  });

  /// Test seam: replaces `AppStateService.refreshAll` behind pull-to-refresh.
  final Future<void> Function()? refresh;

  /// Test seam: replaces `AppStateService.loadMoreHistory`.
  final Future<int> Function()? loadMore;

  /// Test seam: replaces the push of [ActiveChargingScreen], whose telemetry
  /// stream would keep polling (and `pumpAndSettle`) alive in a widget test.
  final void Function(BuildContext, ChargingSession)? openMonitor;

  static const String ongoingTabLabel = 'Ongoing';
  static const String historyTabLabel = 'History';

  static const String noSessionTitle = 'No active charging session';
  static const String noSessionMessage =
      'Plug in and start a charge to watch it live here.';
  static const String findChargerLabel = 'Find a charger';

  static const String noHistoryTitle = 'No charging sessions yet';
  static const String noHistoryMessage =
      'Your digital receipts are kept here after your first charge.';

  /// Where the history list starts asking for the next page: a screenful before
  /// the end, so the rows are usually there by the time the driver arrives.
  static const double loadMoreThreshold = 320;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  /// 0 = Ongoing, 1 = History.
  int _tab = 0;

  final ScrollController _scroll = ScrollController();

  /// `true` once a short page has proved there is nothing older to load.
  bool _exhausted = false;

  bool _loadingMore = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  /// Fetches the next page once the driver is within a screenful of the bottom.
  ///
  /// Neither flag is `setState`d: nothing on screen renders from them, and an
  /// extra rebuild per scroll frame buys nothing.
  void _maybeLoadMore() {
    if (!_scroll.hasClients || _pageError != null) return;
    if (_scroll.position.extentAfter > ActivityScreen.loadMoreThreshold) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted) return;

    // Nothing to page from: the first page arrives with `refreshAll`.
    if (sessionHistoryNotifier.value.isEmpty) return;

    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final added =
          await (widget.loadMore ?? AppStateService.instance.loadMoreHistory)();
      // A short page is the end of the list — stop asking.
      if (added < AppStateService.historyPageSize) _exhausted = true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _pageError =
              'Could not load older sessions. Pull to refresh or retry.',
        );
      }
      // A failed page leaves what is already on screen alone; the driver can
      // pull to retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _exhausted = false;
      _pageError = null;
    });
    await (widget.refresh ?? AppStateService.instance.refreshAll)();
  }

  void _openMonitor(ChargingSession session) {
    final custom = widget.openMonitor;
    if (custom != null) {
      custom(context, session);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveChargingScreen(session: session),
      ),
    );
  }

  /// The empty state's escape hatch, the same deep link the live monitor uses
  /// when it pops back to Activity.
  void _goToHome() => dashboardTabNotifier.value = DashboardTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(
                      value: 0,
                      label: Text(ActivityScreen.ongoingTabLabel),
                      icon: Icon(Icons.bolt_outlined),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(ActivityScreen.historyTabLabel),
                      icon: Icon(Icons.receipt_long_outlined),
                    ),
                  ],
                  selected: {_tab},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _tab = selection.first),
                ),
              ),
            ),
            if (_tab == 1 && _pageError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(_pageError!),
                    TextButton(
                      onPressed: _loadMore,
                      child: const Text('Retry older sessions'),
                    ),
                  ],
                ),
              ),
            if (_tab == 1 && _loadingMore)
              const Text('Loading older sessions…'),
            Expanded(
              child: DataSlice(
                state: _tab == 0
                    ? activeSessionLoadNotifier
                    : historyLoadNotifier,
                label: _tab == 0 ? 'active session' : 'charging history',
                onRetry: _tab == 0
                    ? AppStateService.instance.refreshActiveSession
                    : AppStateService.instance.refreshHistory,
                expand: true,
                child: _tab == 0 ? _ongoingTab() : _historyTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The card for the session in flight, or the "nothing running" state.
  Widget _ongoingTab() {
    return ValueListenableBuilder<ChargingSession?>(
      valueListenable: activeSessionNotifier,
      builder: (context, session, child) {
        if (session == null) return _ongoingEmptyState();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            children: [
              const Text(
                OngoingSessionCard.title,
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // The accent colour comes from the roaming catalogue, which can
              // still be loading when the card first appears.
              ValueListenableBuilder<List<CpoPartner>>(
                valueListenable: cposNotifier,
                builder: (context, cpos, child) => OngoingSessionCard(
                  session: session,
                  cpos: cpos,
                  onOpen: () => _openMonitor(session),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ongoingEmptyState() {
    return _EmptyState(
      onRefresh: _refresh,
      icon: Icons.ev_station_outlined,
      title: ActivityScreen.noSessionTitle,
      message: ActivityScreen.noSessionMessage,
      action: FilledButton.icon(
        onPressed: _goToHome,
        icon: const Icon(Icons.search, size: 18),
        label: const Text(ActivityScreen.findChargerLabel),
      ),
    );
  }

  /// The receipt archive, newest first, grouped by month.
  Widget _historyTab() {
    return ValueListenableBuilder<List<ChargingSession>>(
      valueListenable: sessionHistoryNotifier,
      builder: (context, sessions, child) {
        if (sessions.isEmpty) {
          return _EmptyState(
            onRefresh: _refresh,
            icon: Icons.receipt_long_outlined,
            title: ActivityScreen.noHistoryTitle,
            message: ActivityScreen.noHistoryMessage,
          );
        }

        // One flat list of dividers and rows, so `ListView.builder` keeps every
        // receipt lazy.
        final rows = HistoryRow.flatten(HistoryMonth.group(sessions));

        return ValueListenableBuilder<List<CpoPartner>>(
          valueListenable: cposNotifier,
          builder: (context, cpos, child) => RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              itemCount: rows.length,
              itemBuilder: (context, index) => switch (rows[index]) {
                HistoryHeader(:final label) => _MonthHeader(label),
                HistorySession(:final session) => HistoryTile(
                  session: session,
                  cpos: cpos,
                  onTap: () => showChargingReceipt(context, session),
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

/// A month divider in the history list.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.black54,
        ),
      ),
    );
  }
}

/// A centered "nothing here (yet)" panel.
///
/// Uses a scroll view so pull-to-refresh works with an empty archive.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onRefresh,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Future<void> Function() onRefresh;
  final IconData icon;
  final String title;
  final String message;

  /// Optional call to action, e.g. "Find a charger".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 54, color: Colors.black26),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 18),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
