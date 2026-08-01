import 'package:flutter/material.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/home/station_filter.dart';

/// One scrollable row; detailed options live in the expanding filter sheet.
class FilterChipsWidget extends StatelessWidget {
  const FilterChipsWidget({
    super.key,
    required this.filter,
    required this.cpos,
    required this.onChanged,
    this.onOpenFilters,
  });
  final StationFilter filter;
  final List<CpoPartner> cpos;
  final ValueChanged<StationFilter> onChanged;
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: Text(
              filter.activeCount == 0
                  ? 'Filters'
                  : 'Filters (${filter.activeCount})',
            ),
            onPressed: onOpenFilters,
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
        if (filter.country != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.place_outlined, size: 18),
              label: Text(
                filter.region ??
                    switch (filter.country) {
                      'MY' => 'Malaysia',
                      'SG' => 'Singapore',
                      'TH' => 'Thailand',
                      _ => 'Anywhere',
                    },
              ),
              onPressed: onOpenFilters,
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        for (final type in ['AC', 'DC'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(type),
              selected: filter.powerType == type,
              onSelected: (selected) => onChanged(
                filter.copyWith(powerType: type, clearPowerType: !selected),
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        FilterChip(
          label: const Text('Available now'),
          selected: filter.availableOnly,
          onSelected: (selected) =>
              onChanged(filter.copyWith(availableOnly: selected)),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ],
    ),
  );
}
