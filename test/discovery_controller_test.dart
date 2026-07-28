import 'package:flutter/material.dart';
import 'package:chargenet_mobile/features/home/widgets/search_pill_widget.dart';

import 'dart:async';

import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/home/home_notifiers.dart';
import 'package:chargenet_mobile/services/discovery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/layout_fixtures.dart';

void main() {
  tearDown(() {
    stationsNotifier.value = [];
    selectedStationNotifier.value = null;
  });
  test('new search wins reversed completion and superseded errors', () async {
    final old = Completer<List<Station>>();
    final recent = Completer<List<Station>>();
    final controller = DiscoveryController();
    final first = controller.load(() => old.future);
    final second = controller.load(() => recent.future);
    recent.complete([layoutStation]);
    await second;
    old.completeError(StateError('old failure'));
    await first;
    expect(stationsNotifier.value.single.id, layoutStation.id);
    expect(controller.error, isNull);
    expect(controller.loading, isFalse);
    final late = Completer<List<Station>>();
    final third = controller.load(() => late.future);
    await controller.load(() async => []);
    late.complete([layoutStation]);
    await third;
    expect(stationsNotifier.value, isEmpty);
    expect(controller.hasData, isTrue);
    controller.dispose();
  });
  test('refresh updates selected connectors, dismisses missing selection, hides fallback distance', () async {
    final controller = DiscoveryController();
    selectedStationNotifier.value = layoutStation;
    final changed = Station.fromJson({
      ...layoutStation.toJson(),
      'connectors': [],
    });
    await controller.load(() async => [changed], measuredOrigin: false);
    expect(selectedStationNotifier.value?.connectors, isEmpty);
    expect(selectedStationNotifier.value?.distanceKm, isNull);
    await controller.load(() async => []);
    expect(selectedStationNotifier.value, isNull);
    final late = Completer<List<Station>>();
    final loading = controller.load(() => late.future);
    controller.dispose();
    late.complete([layoutStation]);
    await loading;
    expect(stationsNotifier.value, isEmpty);
  });
  testWidgets('clearing filters cancels a pending search debounce', (
    tester,
  ) async {
    final controller = TextEditingController();
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchPillWidget(
            controller: controller,
            onQueryChanged: queries.add,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'old query');
    controller.clear();
    await tester.pump(const Duration(seconds: 1));
    expect(queries, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
