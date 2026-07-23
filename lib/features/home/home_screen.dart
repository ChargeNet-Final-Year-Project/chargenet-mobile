import 'package:chargenet_mobile/features/home/widgets/station_filter_sheet.dart';
import 'package:chargenet_mobile/features/home/station_clusters.dart';
import 'package:chargenet_mobile/services/discovery_controller.dart';
import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';
import 'package:chargenet_mobile/core/layout.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/charging/charger_activation_screen.dart';
import 'package:chargenet_mobile/features/home/home_notifiers.dart';
import 'package:chargenet_mobile/features/home/station_filter.dart';
import 'package:chargenet_mobile/features/home/widget/current_location_marker_widget.dart';
import 'package:chargenet_mobile/features/home/widgets/filter_chips_widget.dart';
import 'package:chargenet_mobile/features/home/widgets/search_pill_widget.dart';
import 'package:chargenet_mobile/features/home/widgets/station_detail_bottom_sheet.dart';
import 'package:chargenet_mobile/features/home/widgets/station_marker_widget.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Kuala Lumpur city centre: the map's opening position and the fallback
  /// search origin when location permission is refused.
  static const LatLng _klCentre = LatLng(3.1409, 101.6932);

  final MapController _mapController = MapController();

  bool _cameraChosenByDriver = false;
  bool _tileError = false;
  int _tileGeneration = 0;

  LatLng? _currentLocation;
  final _discovery = DiscoveryController();
  bool get _isLoadingStations => _discovery.loading;
  String? get _stationsError => _discovery.error;
  void _discoveryChanged() {
    if (mounted) setState(() {});
  }

  /// Search + chip selection applied to every station request.
  StationFilter _filter = const StationFilter();
  List<StationRegion> _regions = [];
  double _zoom = KConstants.defaultMapZoom;

  /// Owned here so [SearchPillWidget] can be cleared and disposed with the
  /// screen.
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showSearchResults = false;

  void _onSearchFocusChanged() {
    if (!_searchFocus.hasFocus) return;
    setState(
      () => _showSearchResults = _searchController.text.trim().isNotEmpty,
    );
    _onQueryChanged(_searchController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    _discovery.addListener(_discoveryChanged);
    _searchFocus.addListener(_onSearchFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }

  @override
  void dispose() {
    _discovery.removeListener(_discoveryChanged);
    _discovery.dispose();
    _searchController.dispose();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Location

  Future<void> _loadCurrentLocation() async {
    try {
      final location = await getCurrentPosition();

      if (!mounted) return;

      final latLng = LatLng(location.latitude, location.longitude);

      setState(() {
        _currentLocation = latLng;
      });

      if (!_cameraChosenByDriver) {
        _mapController.move(latLng, KConstants.defaultMapZoom);
      }

      await _fetchStations(origin: latLng);
    } on LocationPermissionDeniedException {
      if (!mounted) return;

      _showMessage(
        'Location permission is denied for this app. '
        'Please enable it in Settings to auto locate your position on the map.',
      );

      // A refused permission must not leave the map empty: fall back to KL.
      await _fetchStations();
    } on LocationPermissionDeniedForeverException {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location permission required'),
          content: const Text(
            'Location permission has been disabled for this app. '
            'Please enable it in Settings to auto locate your position on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();

                _loadCurrentLocation();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      await _fetchStations();
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Location unavailable. Showing chargers around Kuala Lumpur.',
      );
      await _fetchStations();
    }
  }

  // Stations

  /// Loads nearby stations into [stationsNotifier].
  ///
  /// [origin] defaults to the last fix, then to [_klCentre], so the map always
  /// has markers to show — permission granted or not.
  Future<void> _fetchStations({LatLng? origin}) async {
    final searchOrigin = origin ?? _currentLocation ?? _klCentre;

    final filter = _filter;
    await _discovery.load(
      () => ApiService.instance.fetchStations(
        query: filter.query.isEmpty ? null : filter.query,
        country: filter.country,
        region: filter.region,
        powerType: filter.powerType,
        maxPowerKw: filter.maxPowerKw,
        connectorType: filter.connectorType,
        cpoId: filter.cpoId,
        availableOnly: filter.availableOnly,
        minPowerKw: filter.minPowerKw,
        lat: searchOrigin.latitude,
        lng: searchOrigin.longitude,
      ),
      measuredOrigin: _currentLocation != null,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Map interaction

  /// Selecting a station publishes it on [selectedStationNotifier], which is
  /// what makes the detail sheet appear, and recentres the map on it.
  void _onMarkerTap(Station station) {
    setState(() => _showSearchResults = false);
    _searchFocus.unfocus();
    _cameraChosenByDriver = true;
    selectedStationNotifier.value = station;

    _mapController.move(
      LatLng(station.latitude, station.longitude),
      KConstants.defaultMapZoom,
    );
  }

  void _recentreOnUser() {
    final location = _currentLocation;

    if (location == null) {
      _showMessage('Your location is not available yet.');
      return;
    }

    _mapController.move(location, KConstants.defaultMapZoom);
  }

  // Discovery filters

  /// Debounced query from [SearchPillWidget]; lat/lng are preserved because
  /// [_fetchStations] falls back to the last fix.
  void _onQueryChanged(String query) {
    if (query == _filter.query) return;

    setState(() {
      _filter = _filter.copyWith(query: query);
      _showSearchResults = query.isNotEmpty;
    });

    selectedStationNotifier.value = null;
    _fetchStations();
  }

  Future<void> _openFilters() async {
    final before = _filter;
    final next = await showStationFilters(
      context,
      filter: before,
      cpos: cposNotifier.value,
      loadRegions: () async {
        final rows = await ApiService.instance.fetchStationRegions();
        _regions = rows;
        return rows;
      },
    );
    if (!mounted || next == null) return;
    _onFilterChanged(next);
    if (next.country == before.country && next.region == before.region) return;
    _cameraChosenByDriver = true;
    final region = _regions
        .where((r) => r.countryCode == next.country && r.name == next.region)
        .firstOrNull;
    if (region != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(region.south, region.west),
            LatLng(region.north, region.east),
          ),
          padding: const EdgeInsets.fromLTRB(48, 180, 48, 100),
          maxZoom: 13,
        ),
      );
    } else {
      switch (next.country) {
        case 'MY':
          _mapController.move(const LatLng(5.36, 100.36), 10.5);
        case 'SG':
          _mapController.move(const LatLng(1.35, 103.82), 10.7);
        case 'TH':
          _mapController.move(const LatLng(10.4, 100.5), 5.7);
      }
    }
  }

  /// Chip selection, applied immediately.
  void _onFilterChanged(StationFilter filter) {
    setState(() {
      _filter = filter;
      selectedStationNotifier.value = null;
    });

    _fetchStations();
  }

  /// "Start charging" on a connector tile.
  void _openChargerActivation(Connector connector) =>
      _pushChargerActivation(connector.evseUid);

  /// "Scan QR to Charge": no EVSE preselected.
  void _scanQrToCharge() => _pushChargerActivation(null);

  void _pushChargerActivation(String? evseUid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChargerActivationScreen(evseUid: evseUid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialZoom: KConstants.defaultMapZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              initialCenter: _klCentre,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _cameraChosenByDriver = true;
                if ((camera.zoom - _zoom).abs() > .2) {
                  setState(() => _zoom = camera.zoom);
                }
              },
              minZoom: KConstants.mapMinZoom,
              maxZoom: KConstants.mapMaxZoom,
              // Tapping the map (not a marker) dismisses the station sheet.
              onTap: (tapPosition, point) =>
                  selectedStationNotifier.value = null,
            ),
            children: [
              TileLayer(
                key: ValueKey(_tileGeneration),
                minZoom: KConstants.mapMinZoom,
                maxZoom: KConstants.mapMaxZoom,
                urlTemplate: KConstants.osmTileUrl,
                userAgentPackageName: 'com.chargenet.mobileapp',
                tileProvider: NetworkTileProvider(
                  headers: {'User-Agent': 'ChargeNetMobile/1.0'},
                ),
                errorTileCallback: (_, error, stackTrace) {
                  if (_tileError) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_tileError) {
                      setState(() => _tileError = true);
                    }
                  });
                },
              ),

              // Live stations, re-rendered whenever the notifier changes.
              ValueListenableBuilder<List<Station>>(
                valueListenable: stationsNotifier,
                builder: (context, stations, _) => MarkerLayer(
                  markers: [
                    for (final group in clusterStations(stations, _zoom))
                      if (group.length == 1)
                        Marker(
                          point: LatLng(
                            group.first.latitude,
                            group.first.longitude,
                          ),
                          width: 72,
                          height: 56,
                          child: StationMarkerWidget(
                            station: group.first,
                            onTap: () => _onMarkerTap(group.first),
                          ),
                        )
                      else
                        Marker(
                          point: LatLng(
                            group
                                    .map((s) => s.latitude)
                                    .reduce((a, b) => a + b) /
                                group.length,
                            group
                                    .map((s) => s.longitude)
                                    .reduce((a, b) => a + b) /
                                group.length,
                          ),
                          width: 52,
                          height: 52,
                          child: Semantics(
                            button: true,
                            label:
                                '${group.length} charging stations. Zoom in.',
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              onPressed: () {
                                _cameraChosenByDriver = true;
                                _mapController.fitCamera(
                                  CameraFit.bounds(
                                    bounds: LatLngBounds.fromPoints(
                                      group
                                          .map(
                                            (s) =>
                                                LatLng(s.latitude, s.longitude),
                                          )
                                          .toList(),
                                    ),
                                    padding: const EdgeInsets.all(72),
                                    maxZoom: 18,
                                  ),
                                );
                              },
                              child: Text('${group.length}'),
                            ),
                          ),
                        ),
                  ],
                ),
              ),

              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 28,
                      height: 28,
                      child: const CurrentLocationMarkerWidget(),
                    ),
                  ],
                ),
            ],
          ),
          _buildTopOverlay(),
          _buildStationSheet(),
          _buildBottomControls(),
          Positioned(
            bottom: 4,
            left: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              child: PopupMenuButton<void>(
                tooltip: 'Map attribution',
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    enabled: false,
                    child: Text(
                      '\u00a9 OpenStreetMap contributors',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
                child: const SizedBox(
                  height: 48,
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 14),
                      SizedBox(width: 4),
                      Text('OSM', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Search pill, filter chips and the loading / error feedback, under the
  /// status bar.
  Widget _buildTopOverlay() {
    final error = _stationsError;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.mapInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchPillWidget(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onQueryChanged: _onQueryChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MapIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh stations',
                    onPressed: _isLoadingStations ? null : _fetchStations,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_tileError)
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Map imagery is unavailable. Charging stations remain available.',
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _tileError = false;
                            _tileGeneration++;
                          }),
                          child: const Text('Retry map imagery'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showSearchResults && _filter.query.isNotEmpty)
                ValueListenableBuilder<List<Station>>(
                  valueListenable: stationsNotifier,
                  builder: (context, stations, _) => Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final station in stations.take(3))
                          ListTile(
                            title: Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${station.city} / ${station.countryCode}',
                            ),
                            onTap: () => _onMarkerTap(station),
                          ),
                      ],
                    ),
                  ),
                ),
              ValueListenableBuilder<List<CpoPartner>>(
                valueListenable: cposNotifier,
                builder: (context, cpos, _) => FilterChipsWidget(
                  filter: _filter,
                  cpos: cpos,
                  onChanged: _onFilterChanged,
                  onOpenFilters: _openFilters,
                ),
              ),
              ValueListenableBuilder<DataLoadState>(
                valueListenable: cposLoadNotifier,
                builder: (context, state, _) => state.error == null
                    ? const SizedBox.shrink()
                    : _StationsErrorBanner(
                        message:
                            'Operator filters may be incomplete. ${state.error}',
                        onRetry: () async {
                          try {
                            await AppStateService.instance.refreshCpos();
                          } catch (_) {}
                        },
                      ),
              ),
              if (_currentLocation == null && _filter.country == null)
                const Text(
                  'Device location is unavailable. Open Filters to choose a country or state.',
                ),
              if (!_isLoadingStations &&
                  error == null &&
                  _discovery.hasData &&
                  stationsNotifier.value.isEmpty) ...[
                const Text('No chargers match your search.'),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _onFilterChanged(const StationFilter());
                  },
                  child: const Text('Clear filters'),
                ),
              ],
              if (_isLoadingStations) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _StationsLoadingPill(),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                _StationsErrorBanner(message: error, onRetry: _fetchStations),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Station sheet for the marker the user tapped. Absent
  /// whenever [selectedStationNotifier] is null.
  Widget _buildStationSheet() {
    return ValueListenableBuilder<Station?>(
      valueListenable: selectedStationNotifier,
      builder: (context, station, _) {
        if (station == null) return const SizedBox.shrink();

        return StationDetailBottomSheet(
          station: station,
          userLocation: _currentLocation,
          onDismiss: () => selectedStationNotifier.value = null,
          onStartCharging: _isLoadingStations || _stationsError != null
              ? null
              : _openChargerActivation,
        );
      },
    );
  }

  /// "My location" and "Scan QR to Charge", stacked
  /// vertically and hidden while the station sheet is open.
  Widget _buildBottomControls() {
    return ValueListenableBuilder<Station?>(
      valueListenable: selectedStationNotifier,
      builder: (context, station, _) {
        if (station != null) return const SizedBox.shrink();

        return Positioned(
          left: AppSpacing.group,
          right: AppSpacing.group,
          bottom: AppSpacing.section,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MapIconButton(
                  icon: Icons.my_location,
                  tooltip: 'My location',
                  onPressed: _recentreOnUser,
                ),
                const SizedBox(height: AppSpacing.related),
                Center(
                  child: FloatingActionButton.extended(
                    heroTag: 'home-scan-qr',
                    onPressed: _scanQrToCharge,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR to Charge'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// White circular icon button that stays legible on top of the map tiles.
class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Shown while stations are being (re)fetched.
class _StationsLoadingPill extends StatelessWidget {
  const _StationsLoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading stations…'),
        ],
      ),
    );
  }
}

/// Persistent retry affordance for a backend that is down on cold start, where
/// a transient SnackBar is easy to miss.
class _StationsErrorBanner extends StatelessWidget {
  const _StationsErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(KConstants.circularBorderRadius),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
