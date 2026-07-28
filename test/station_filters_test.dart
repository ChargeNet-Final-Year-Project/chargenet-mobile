import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chargenet_mobile/core/app_theme.dart';
import 'package:chargenet_mobile/features/home/station_filter.dart';
import 'package:chargenet_mobile/features/home/widgets/station_filter_sheet.dart';
import 'package:chargenet_mobile/services/api_service.dart';

const regions = [
  StationRegion(
    countryCode: 'MY',
    name: 'Penang',
    stationCount: 11,
    south: 5.245,
    west: 100.25,
    north: 5.473,
    east: 100.461,
  ),
  StationRegion(
    countryCode: 'SG',
    name: 'Central',
    stationCount: 3,
    south: 1.27,
    west: 103.83,
    north: 1.3,
    east: 103.87,
  ),
];

void main() {
  test('changing country clears its region and retains other filters', () {
    const filter = StationFilter(
      country: 'MY',
      region: 'Penang',
      query: 'Demo',
      minPowerKw: 50,
      powerType: 'DC',
    );
    final changed = filter.copyWith(country: 'SG');
    expect(changed.region, isNull);
    expect(changed.country, 'SG');
    expect(changed.query, 'Demo');
    expect(changed.minPowerKw, 50);
    expect(filter.copyWith(clearCountry: true).region, isNull);
    expect(filter.copyWith(country: 'SG', region: 'Central').region, 'Central');
  });

  test('API sends geographic and power constraints in one request', () async {
    late Uri seen;
    final api = ApiService.withClient(
      MockClient((request) async {
        seen = request.url;
        return http.Response('[]', 200);
      }),
    );
    await api.fetchStations(
      country: 'SG',
      region: 'Central',
      powerType: 'DC',
      minPowerKw: 50,
      maxPowerKw: 150,
      availableOnly: true,
    );
    expect(seen.queryParameters, {
      'country': 'SG',
      'region': 'Central',
      'powerType': 'DC',
      'minPower': '50.0',
      'maxPower': '150.0',
      'availableOnly': 'true',
    });
    final metadata = ApiService.withClient(
      MockClient((request) async {
        expect(request.url.path, endsWith('/stations/regions'));
        return http.Response(
          jsonEncode([
            {
              'countryCode': 'MY',
              'name': 'Penang',
              'stationCount': 11,
              'south': 5.245,
              'west': 100.25,
              'north': 5.473,
              'east': 100.461,
            },
          ]),
          200,
        );
      }),
    );
    expect((await metadata.fetchStationRegions()).single.stationCount, 11);
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'filter sheet is scrollable with Apply visible at $size / $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showStationFilters(
                      context,
                      filter: const StationFilter(country: 'MY'),
                      cpos: const [],
                      loadRegions: () async => regions,
                    ),
                    child: const Text('Open filters'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open filters'));
          await tester.pumpAndSettle();
          expect(find.byType(DraggableScrollableSheet), findsOneWidget);
          final apply = tester.getRect(find.text('Apply filters'));
          expect(apply.top, greaterThan(0));
          expect(apply.bottom, lessThanOrEqualTo(size.height));
          await tester.scrollUntilVisible(
            find.text('Charging network'),
            180,
            scrollable: find.byType(Scrollable).last,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Close filters'));
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'country change clears region and Apply returns the combined draft',
    (tester) async {
      StationFilter? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showStationFilters(
                  context,
                  filter: const StationFilter(
                    country: 'MY',
                    region: 'Penang',
                    query: 'Demo',
                  ),
                  cpos: const [],
                  loadRegions: () async => regions,
                ),
                child: const Text('Open filters'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open filters'));
      await tester.pumpAndSettle();
      expect(find.text('Penang (11)'), findsOneWidget);
      await tester.tap(find.text('Malaysia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Singapore').last);
      await tester.pumpAndSettle();
      expect(find.text('Penang (11)'), findsNothing);
      await tester.tap(find.text('All regions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central (3)').last);
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.scrollUntilVisible(
        find.byType(RangeSlider),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
        const RangeValues(50, 150),
      );
      await tester.pump();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(result?.country, 'SG');
      expect(result?.region, 'Central');
      expect(result?.minPowerKw, 50);
      expect(result?.maxPowerKw, 150);
      expect(result?.query, 'Demo');
    },
  );

  testWidgets('Reset is a draft and dismissal cancels all changes', (
    tester,
  ) async {
    const original = StationFilter(
      country: 'TH',
      region: 'Bangkok',
      powerType: 'DC',
      query: 'Demo',
    );
    StationFilter? result = original;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showStationFilters(
                context,
                filter: original,
                cpos: const [],
                loadRegions: () async => regions,
              ),
              child: const Text('Open filters'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(result, same(original));
    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(original.region, 'Bangkok');
  });
}
