import 'package:flutter/material.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/home/station_filter.dart';

Future<StationFilter?> showStationFilters(
  BuildContext context, {
  required StationFilter filter,
  required List<CpoPartner> cpos,
  required Future<List<StationRegion>> Function() loadRegions,
}) => showModalBottomSheet<StationFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      StationFilterSheet(filter: filter, cpos: cpos, loadRegions: loadRegions),
);

/// Draft changes stay inside the sheet until Apply; dismissing cancels them.
class StationFilterSheet extends StatefulWidget {
  const StationFilterSheet({
    super.key,
    required this.filter,
    required this.cpos,
    required this.loadRegions,
  });
  final StationFilter filter;
  final List<CpoPartner> cpos;
  final Future<List<StationRegion>> Function() loadRegions;
  @override
  State<StationFilterSheet> createState() => _StationFilterSheetState();
}

class _StationFilterSheetState extends State<StationFilterSheet> {
  late StationFilter _draft = widget.filter;
  late Future<List<StationRegion>> _regions = widget.loadRegions();
  static const double _powerCeiling = 400;

  void _changePower(RangeValues values) {
    final upper = values.end.clamp(5, _powerCeiling).toDouble();
    final lower = values.start.clamp(0, upper - 5).toDouble();
    setState(
      () => _draft = _draft.copyWith(
        minPowerKw: lower,
        maxPowerKw: upper,
        clearMinPower: lower == 0,
        clearMaxPower: upper == _powerCeiling,
      ),
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _select({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String?>? onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(
              entry.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .78,
    minChildSize: .45,
    maxChildSize: .96,
    builder: (context, controller) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filter stations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _draft = StationFilter(query: widget.filter.query),
                ),
                child: const Text('Reset'),
              ),
              IconButton(
                tooltip: 'Close filters',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              _heading('Location'),
              _select(
                label: 'Country',
                value: _draft.country ?? '',
                options: const {
                  '': 'All countries',
                  'MY': 'Malaysia',
                  'SG': 'Singapore',
                  'TH': 'Thailand',
                },
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(
                    country: value,
                    clearCountry: value == '',
                    clearRegion: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<StationRegion>>(
                future: _regions,
                builder: (context, snapshot) {
                  final regions = (snapshot.data ?? []).where(
                    (r) => r.countryCode == _draft.country,
                  );
                  final label = switch (_draft.country) {
                    'MY' => 'State / territory',
                    'TH' => 'Province',
                    _ => 'Region',
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _select(
                        label: label,
                        value: regions.any((r) => r.name == _draft.region)
                            ? _draft.region!
                            : '',
                        options: {
                          '':
                              'All ${_draft.country == 'MY'
                                  ? 'states'
                                  : _draft.country == 'TH'
                                  ? 'provinces'
                                  : 'regions'}',
                          for (final region in regions)
                            region.name:
                                '${region.name} (${region.stationCount})',
                        },
                        onChanged:
                            _draft.country == null || snapshot.data == null
                            ? null
                            : (value) => setState(
                                () => _draft = _draft.copyWith(
                                  region: value,
                                  clearRegion: value == '',
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.hasError) ...[
                        const Text(
                          'Regions could not be loaded. You can still filter by country.',
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _regions = widget.loadRegions()),
                          child: const Text('Retry regions'),
                        ),
                      ] else if (!snapshot.hasData)
                        const LinearProgressIndicator()
                      else
                        Text(
                          _draft.country == null
                              ? 'Choose a country to see its states or regions.'
                              : 'Showing areas with stations in this network.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  );
                },
              ),
              _heading('Charging'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in ['', 'AC', 'DC'])
                    ChoiceChip(
                      label: Text(type.isEmpty ? 'AC & DC' : type),
                      selected: (_draft.powerType ?? '') == type,
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(
                          powerType: type,
                          clearPowerType: type.isEmpty,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Power range',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${(_draft.minPowerKw ?? 0).round()}–${(_draft.maxPowerKw ?? _powerCeiling).round()}${_draft.maxPowerKw == null ? '+' : ''} kW',
              ),
              RangeSlider(
                min: 0,
                max: _powerCeiling,
                divisions: 80,
                semanticFormatterCallback: (value) =>
                    '${value.round()} kilowatts',
                labels: RangeLabels(
                  '${(_draft.minPowerKw ?? 0).round()} kW',
                  '${(_draft.maxPowerKw ?? _powerCeiling).round()}${_draft.maxPowerKw == null ? '+' : ''} kW',
                ),
                values: RangeValues(
                  (_draft.minPowerKw ?? 0).clamp(0, _powerCeiling),
                  (_draft.maxPowerKw ?? _powerCeiling).clamp(0, _powerCeiling),
                ),
                onChanged: _changePower,
              ),
              Text(
                'Rated connector power. The upper end includes chargers above 400 kW.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              _select(
                label: 'Connector',
                value: _draft.connectorType ?? '',
                options: const {
                  '': 'Any connector',
                  'TYPE2': 'Type 2',
                  'CCS2': 'CCS2',
                  'CCS1': 'CCS1',
                  'CHADEMO': 'CHAdeMO',
                  'NACS': 'NACS',
                  'GBT': 'GB/T',
                },
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(
                    connectorType: value,
                    clearConnectorType: value == '',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available now'),
                subtitle: const Text(
                  'At least one matching connector is free.',
                ),
                value: _draft.availableOnly,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(availableOnly: value),
                ),
              ),
              _heading('Operator'),
              _select(
                label: 'Charging network',
                value: widget.cpos.any((c) => c.id == _draft.cpoId)
                    ? _draft.cpoId!
                    : '',
                options: {
                  '': 'All operators',
                  for (final cpo in widget.cpos) cpo.id: cpo.name,
                },
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(
                    cpoId: value,
                    clearCpoId: value == '',
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _draft),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Apply filters'),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
