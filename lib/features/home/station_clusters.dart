import 'dart:math' as math;

import 'package:chargenet_mobile/data/models.dart';

/// Merge nearby screen positions across grid boundaries so cluster centres
/// remain far enough apart to tap. Refresh never changes the camera.
List<List<Station>> clusterStations(List<Station> stations, double zoom) {
  if (zoom >= 18) return stations.map((s) => [s]).toList();
  final groups = <({List<Station> stations, double x, double y})>[];
  final scale = 256 * math.pow(2, zoom);
  for (final station in stations) {
    final x = (station.longitude + 180) / 360 * scale;
    final latitude = station.latitude.clamp(-85.0511, 85.0511) * math.pi / 180;
    final y =
        (1 - math.log(math.tan(latitude) + 1 / math.cos(latitude)) / math.pi) /
        2 *
        scale;
    groups.add((stations: [station], x: x, y: y));
  }
  var merged = true;
  while (merged) {
    merged = false;
    search:
    for (var i = 0; i < groups.length; i++) {
      for (var j = i + 1; j < groups.length; j++) {
        final a = groups[i], b = groups[j];
        final dx = a.x - b.x, dy = a.y - b.y;
        if (dx * dx + dy * dy >= 84 * 84) continue;
        final n = a.stations.length, m = b.stations.length;
        groups[i] = (
          stations: [...a.stations, ...b.stations],
          x: (a.x * n + b.x * m) / (n + m),
          y: (a.y * n + b.y * m) / (n + m),
        );
        groups.removeAt(j);
        merged = true;
        break search;
      }
    }
  }
  return groups.map((g) => g.stations).toList();
}
