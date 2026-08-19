import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/core/color_utils.dart';
import 'package:chargenet_mobile/core/format.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/activity/activity_screen.dart';
import 'package:chargenet_mobile/features/activity/widgets/history_tile.dart';
import 'package:chargenet_mobile/features/activity/widgets/ongoing_session_card.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session as `/sessions/history` reports it.
ChargingSession _session({
  String id = 'ses_1',
  String stationName = 'VoltGo Sungei Besi',
  String status = 'COMPLETED',
  DateTime? startTime,
  bool dated = true,
  int? durationSeconds = 872,
  double? kwh = 12.5,
  double? powerKw = 22.4,
  double? soc = 58,
  double? targetSoc = 80,
  double? totalCost,
}) => ChargingSession(
  id: id,
  userId: 'usr_1',
  cpoId: 'cpo_voltgo',
  cpoName: 'VoltGo',
  stationId: 'stn_vlt_sgb',
  stationName: stationName,
  connectorId: 'con_vlt_sgb_01',
  evseUid: 'VLT-SGB-01',
  connectorType: 'CCS2',
  status: status,
  startTime: dated ? (startTime ?? DateTime(2026, 10, 6, 15, 4)) : null,
  durationSeconds: durationSeconds,
  kwhDelivered: kwh,
  currentPowerKw: powerKw,
  batterySoc: soc,
  targetSoc: targetSoc,
  tariffPerKwh: 1.4,
  totalCost: totalCost,
);

CpoPartner _cpo({String id = 'cpo_voltgo', String colorHex = '#0D9488'}) =>
    CpoPartner(
      id: id,
      name: 'VoltGo',
      countryCode: 'MY',
      partyId: 'VLT',
      colorHex: colorHex,
    );

/// The tab on its own, with the three test seams the screen exposes.
Widget _host({
  Future<void> Function()? refresh,
  Future<int> Function()? loadMore,
  void Function(BuildContext context, ChargingSession session)? openMonitor,
}) => MaterialApp(
  home: ActivityScreen(
    refresh: refresh,
    loadMore: loadMore,
    openMonitor: openMonitor,
  ),
);

Future<void> _openHistory(WidgetTester tester) async {
  await tester.tap(find.text(ActivityScreen.historyTabLabel));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    for (final state in [
      walletLoadNotifier,
      vehiclesLoadNotifier,
      historyLoadNotifier,
      transactionsLoadNotifier,
      cposLoadNotifier,
      activeSessionLoadNotifier,
    ]) {
      state.value = const DataLoadState.ready();
    }
  });

  setUp(() {
    activeSessionNotifier.value = null;
    sessionHistoryNotifier.value = const <ChargingSession>[];
    cposNotifier.value = const <CpoPartner>[];
    // Not `home`: the empty state's button has to prove it moved the shell.
    dashboardTabNotifier.value = DashboardTab.profile;
  });

  tearDown(() {
    dashboardTabNotifier.value = DashboardTab.home;
  });

  group('the shared cost and date rules', () {
    test('energyCost rounds the way the backend rounds', () {
      expect(energyCost(12.5, 1.4), 17.5);
      expect(energyCost(0.835, 1.4), 1.17);
      expect(energyCost(null, 1.4), isNull);
    });

    test('formatDayMonth matches the wallet ledger', () {
      expect(formatDayMonth(DateTime(2026, 10, 6, 15, 4)), '06 Oct, 3:04 PM');
      expect(formatDayMonth(null), kNoValue);
    });

    test('cpoAccentColor finds the brand colour and falls back', () {
      expect(
        cpoAccentColor('cpo_voltgo', [_cpo(colorHex: '#0D9488')]),
        const Color(0xFF0D9488),
      );
      expect(cpoAccentColor('cpo_unknown', [_cpo()]), kFallbackCpoColor);
      expect(cpoAccentColor('cpo_voltgo', const []), kFallbackCpoColor);
    });
  });

  group('HistoryMonth', () {
    test('labelFor names the month and the year', () {
      expect(HistoryMonth.labelFor(DateTime(2026, 10, 6)), 'October 2026');
    });

    test('group buckets a newest-first list into consecutive months', () {
      final months = HistoryMonth.group([
        _session(id: 'a', startTime: DateTime(2026, 10, 6)),
        _session(id: 'b', startTime: DateTime(2026, 10, 1)),
        _session(id: 'c', startTime: DateTime(2026, 9, 30)),
        _session(id: 'd', startTime: DateTime(2026, 9, 2)),
      ]);

      expect(months.map((month) => month.label), [
        'October 2026',
        'September 2026',
      ]);
      expect(months.first.sessions.map((session) => session.id), ['a', 'b']);
      expect(months.last.sessions.map((session) => session.id), ['c', 'd']);
    });

    test('group parks an undated row under "Earlier"', () {
      final months = HistoryMonth.group([_session(dated: false)]);

      expect(months.single.label, HistoryMonth.undatedLabel);
      expect(months.single.sessions, hasLength(1));
    });

    test('flatten puts a divider in front of every month', () {
      final rows = HistoryRow.flatten(
        HistoryMonth.group([
          _session(id: 'a', startTime: DateTime(2026, 10, 6)),
          _session(id: 'b', startTime: DateTime(2026, 10, 1)),
          _session(id: 'c', startTime: DateTime(2026, 9, 30)),
        ]),
      );

      expect(rows, hasLength(5));
      expect(rows[0], isA<HistoryHeader>());
      expect(rows[1], isA<HistorySession>());
      expect(rows[2], isA<HistorySession>());
      expect(rows[3], isA<HistoryHeader>());
      expect((rows[0] as HistoryHeader).label, 'October 2026');
      expect((rows[3] as HistoryHeader).label, 'September 2026');
      expect((rows[4] as HistorySession).session.id, 'c');
    });

    test('flatten of an empty archive is empty', () {
      expect(HistoryRow.flatten(const <HistoryMonth>[]), isEmpty);
    });
  });

  group('HistoryTile', () {
    test('dateLabel and detailLabel summarise a row', () {
      final session = _session(
        startTime: DateTime(2026, 10, 6, 15, 4),
        kwh: 12.5,
        durationSeconds: 872,
      );

      expect(HistoryTile.dateLabel(session), '06 Oct, 3:04 PM');
      expect(HistoryTile.detailLabel(session), '12.5 kWh · 00:14:32');
    });

    test('a row the backend never dated still reads', () {
      final session = _session(dated: false, durationSeconds: null, kwh: null);

      expect(HistoryTile.dateLabel(session), kNoValue);
      expect(HistoryTile.detailLabel(session), '$kNoValue · 00:00:00');
    });

    test('costLabel prefers the priced total over the estimate', () {
      expect(HistoryTile.costLabel(_session(totalCost: 31.36)), 'RM 31.36');
      expect(HistoryTile.costLabel(_session()), 'RM 17.50');
      expect(HistoryTile.costLabel(_session(kwh: null)), kNoValue);
    });

    test('isFailed flags only a failed session', () {
      expect(HistoryTile.isFailed(_session(status: 'FAILED')), isTrue);
      expect(HistoryTile.isFailed(_session(status: 'COMPLETED')), isFalse);
    });
  });

  group('OngoingSessionCard', () {
    test('quotes the live numbers, and the estimate behind the cost', () {
      final session = _session(kwh: 12.5, powerKw: 22.4, soc: 58);

      expect(OngoingSessionCard.powerValue(session), '22.4 kW');
      expect(OngoingSessionCard.energyValue(session), '12.5 kWh');
      expect(OngoingSessionCard.costValue(session), 'RM 17.50');
      expect(OngoingSessionCard.costSoFar(session), 17.5);
    });

    test('a priced session reports the backend total', () {
      final session = _session(kwh: 19.6, totalCost: 31.36);

      expect(OngoingSessionCard.costSoFar(session), 31.36);
      expect(OngoingSessionCard.costValue(session), 'RM 31.36');
    });

    test('missing readings read as unknown, never as zero', () {
      final session = _session(
        kwh: null,
        powerKw: null,
        soc: null,
        targetSoc: null,
      );

      expect(OngoingSessionCard.powerValue(session), kNoValue);
      expect(OngoingSessionCard.energyValue(session), kNoValue);
      expect(OngoingSessionCard.costValue(session), kNoValue);
      expect(OngoingSessionCard.socLabel(session), kNoValue);
      expect(OngoingSessionCard.socFraction(session), isNull);
    });

    test('socLabel names the target and socFraction stays inside the bar', () {
      expect(
        OngoingSessionCard.socLabel(_session(soc: 58, targetSoc: 80)),
        '58% · target 80%',
      );
      expect(
        OngoingSessionCard.socLabel(_session(soc: 58, targetSoc: null)),
        '58%',
      );
      expect(OngoingSessionCard.socFraction(_session(soc: 40)), 0.4);
      // A charger reporting past 100% must not paint outside the bar.
      expect(OngoingSessionCard.socFraction(_session(soc: 150)), 1.0);
    });
  });

  group('ActivityScreen · Ongoing', () {
    testWidgets('offers a way back to the map when nothing is running', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      expect(find.text(ActivityScreen.noSessionTitle), findsOneWidget);
      expect(find.text(OngoingSessionCard.openLabel), findsNothing);

      await tester.tap(find.text(ActivityScreen.findChargerLabel));
      await tester.pump();

      expect(dashboardTabNotifier.value, DashboardTab.home);
    });

    testWidgets('follows the telemetry notifier while a session runs', (
      tester,
    ) async {
      activeSessionNotifier.value = _session();
      await tester.pumpWidget(_host());

      expect(find.text('VoltGo Sungei Besi'), findsOneWidget);
      expect(find.text('58% · target 80%'), findsOneWidget);
      expect(find.text('22.4 kW'), findsOneWidget);
      expect(find.text('12.5 kWh'), findsOneWidget);
      expect(find.text('RM 17.50'), findsOneWidget);

      // A telemetry frame raises the numbers without a pull-to-refresh.
      activeSessionNotifier.value = _session(powerKw: 40, kwh: 15, soc: 71);
      await tester.pump();

      expect(find.text('40.0 kW'), findsOneWidget);
      expect(find.text('15.0 kWh'), findsOneWidget);
      expect(find.text('RM 21.00'), findsOneWidget);
      expect(find.text('22.4 kW'), findsNothing);
    });

    testWidgets('hands the session to the live monitor', (tester) async {
      ChargingSession? opened;
      activeSessionNotifier.value = _session();
      await tester.pumpWidget(
        _host(openMonitor: (_, session) => opened = session),
      );

      await tester.tap(find.text(OngoingSessionCard.openLabel));
      await tester.pump();

      expect(opened?.id, 'ses_1');
    });

    testWidgets('paints the card in the CPO brand colour', (tester) async {
      cposNotifier.value = [_cpo(colorHex: '#0D9488')];
      activeSessionNotifier.value = _session();
      await tester.pumpWidget(_host());

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape! as RoundedRectangleBorder;

      expect(shape.side.color, const Color(0xFF0D9488).withValues(alpha: 0.35));
    });
  });

  group('ActivityScreen · History', () {
    testWidgets('lists finished sessions newest first, grouped by month', (
      tester,
    ) async {
      sessionHistoryNotifier.value = [
        _session(
          id: 'ses_2',
          stationName: 'VoltGo Mid Valley',
          startTime: DateTime(2026, 10, 6, 15, 4),
          totalCost: 31.36,
        ),
        _session(
          id: 'ses_1',
          startTime: DateTime(2026, 9, 30, 9, 12),
          totalCost: 11.2,
        ),
      ];
      await tester.pumpWidget(_host());
      await _openHistory(tester);

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('RM 31.36'), findsOneWidget);
      expect(find.text('RM 11.20'), findsOneWidget);

      // Newest first: October sits above September.
      expect(
        tester.getTopLeft(find.text('VoltGo Mid Valley')).dy,
        lessThan(tester.getTopLeft(find.text('VoltGo Sungei Besi')).dy),
      );
    });

    testWidgets('tapping a row opens its digital receipt', (tester) async {
      sessionHistoryNotifier.value = [_session(totalCost: 31.36)];
      await tester.pumpWidget(_host());
      await _openHistory(tester);

      await tester.tap(find.text('VoltGo Sungei Besi'));
      await tester.pumpAndSettle();

      expect(find.text(ChargingReceipt.completeLabel), findsOneWidget);
      expect(find.text('RM 31.36'), findsWidgets);
    });

    testWidgets('flags a failed session in the row', (tester) async {
      sessionHistoryNotifier.value = [
        _session(status: 'FAILED', kwh: null, totalCost: 0),
      ];
      await tester.pumpWidget(_host());
      await _openHistory(tester);

      expect(find.text(HistoryTile.failedLabel), findsOneWidget);
      expect(find.text('RM 0.00'), findsOneWidget);
    });

    testWidgets('pull-to-refresh reloads the tab', (tester) async {
      var refreshes = 0;
      sessionHistoryNotifier.value = [_session()];
      await tester.pumpWidget(_host(refresh: () async => refreshes += 1));
      await _openHistory(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
      await tester.pumpAndSettle();

      expect(refreshes, 1);
    });

    testWidgets('shows an empty state before the first charge', (tester) async {
      await tester.pumpWidget(_host());
      await _openHistory(tester);

      expect(find.text(ActivityScreen.noHistoryTitle), findsOneWidget);
      expect(find.text('October 2026'), findsNothing);
    });

    testWidgets('appends the next page at the end, then stops asking', (
      tester,
    ) async {
      sessionHistoryNotifier.value = [
        for (var i = 0; i < AppStateService.historyPageSize; i++)
          _session(
            id: 'ses_$i',
            stationName: 'Station $i',
            startTime: DateTime(2026, 10, 6).subtract(Duration(hours: i)),
          ),
      ];
      var loads = 0;

      await tester.pumpWidget(
        _host(
          loadMore: () async {
            loads += 1;
            sessionHistoryNotifier.value = [
              ...sessionHistoryNotifier.value,
              _session(
                id: 'ses_old',
                stationName: 'VoltGo Cheras',
                startTime: DateTime(2026, 8, 1),
              ),
            ];
            // A short page: the backend has nothing older.
            return 1;
          },
        ),
      );
      await _openHistory(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -1600));
      await tester.pumpAndSettle();

      expect(loads, 1);
      expect(
        sessionHistoryNotifier.value,
        hasLength(AppStateService.historyPageSize + 1),
      );

      // Scrolling on reaches the appended page — and asks the backend nothing
      // more, because a short page already proved the archive was exhausted.
      await tester.drag(find.byType(ListView), const Offset(0, -1600));
      await tester.pumpAndSettle();

      expect(loads, 1);
      expect(find.text('VoltGo Cheras'), findsOneWidget);
      expect(find.text('August 2026'), findsOneWidget);
    });
  });
}
