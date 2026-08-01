import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/home/home_notifiers.dart';
import 'package:chargenet_mobile/features/home/home_screen.dart';
import 'package:chargenet_mobile/features/home/widgets/station_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/layout_fixtures.dart';

void main() {
  testWidgets(
    'selecting a search result dismisses search and retains station selection',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() {
        stationsNotifier.value = [];
        selectedStationNotifier.value = null;
      });
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump(const Duration(seconds: 1));

      final field = find.byType(TextField);
      await tester.enterText(field, 'VoltGo');
      await tester.pump(const Duration(milliseconds: 450));
      stationsNotifier.value = [layoutStation];
      await tester.pump();
      final result = find.widgetWithText(ListTile, layoutStation.name);
      expect(result, findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(result);
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(result, findsNothing);
      expect(find.byType(StationDetailBottomSheet), findsOneWidget);
      expect(selectedStationNotifier.value?.id, layoutStation.id);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      expect(camera.center.latitude, closeTo(layoutStation.latitude, .00001));
      expect(camera.center.longitude, closeTo(layoutStation.longitude, .00001));
      expect(tester.widget<TextField>(field).controller!.text, 'VoltGo');

      // Searching again restores results. A selection made while newer typing is
      // still debouncing must not be cleared by that delayed query.
      await tester.tap(field);
      await tester.pump();
      expect(result, findsOneWidget);
      await tester.enterText(field, 'VoltGo station');
      await tester.tap(result);
      await tester.pump(const Duration(milliseconds: 500));
      expect(result, findsNothing);
      expect(selectedStationNotifier.value?.id, layoutStation.id);
      expect(find.byType(StationDetailBottomSheet), findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
