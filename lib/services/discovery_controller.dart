import 'package:flutter/foundation.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/home/home_notifiers.dart';
import 'package:chargenet_mobile/services/api_service.dart';

class DiscoveryController extends ChangeNotifier {
  int _request = 0;
  bool loading = false;
  bool hasData = false;
  String? error;

  Future<void> load(
    Future<List<Station>> Function() read, {
    bool measuredOrigin = true,
  }) async {
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      var stations = await read();
      if (request != _request) return;
      if (!measuredOrigin) {
        stations = stations
            .map(
              (station) =>
                  Station.fromJson({...station.toJson(), 'distanceKm': null}),
            )
            .toList();
      }
      stationsNotifier.value = stations;
      final selected = selectedStationNotifier.value;
      if (selected != null) {
        selectedStationNotifier.value = stations
            .where((station) => station.id == selected.id)
            .firstOrNull;
      }
      hasData = true;
    } catch (failure) {
      if (request != _request) return;
      error = failure is ApiException
          ? failure.message
          : 'Could not reach the ChargeNet server.';
    } finally {
      if (request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    ++_request;
    super.dispose();
  }
}
