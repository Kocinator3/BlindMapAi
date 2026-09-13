import 'dart:math' as math;

class GeoPoint {
  final double lon;
  final double lat;
  const GeoPoint(this.lon, this.lat);
  List<double> toJson() => [lon, lat];
  bool get valid =>
      lon.isFinite && lat.isFinite && lon.abs() <= 180 && lat.abs() <= 90;
}

const earthRadiusKm = 6371.0088;
double radians(double degrees) => degrees * math.pi / 180;
double longitudeDelta(double value) => (value + 540) % 360 - 180;
double distanceKm(GeoPoint a, GeoPoint b) {
  final dLat = radians(b.lat - a.lat);
  final dLon = radians(longitudeDelta(b.lon - a.lon));
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(a.lat)) *
          math.cos(radians(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(h.clamp(0, 1)));
}

class XY {
  final double x, y;
  const XY(this.x, this.y);
  double distance(XY other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
}

/// Local equirectangular projection, in km, centered on the target.
class LocalProjection {
  final GeoPoint origin;
  const LocalProjection(this.origin);
  XY project(GeoPoint p) => XY(
    earthRadiusKm *
        radians(longitudeDelta(p.lon - origin.lon)) *
        math.cos(radians(origin.lat)),
    earthRadiusKm * radians(p.lat - origin.lat),
  );
}

double segmentDistance(XY p, XY a, XY b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final length2 = dx * dx + dy * dy;
  if (length2 == 0) return p.distance(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / length2).clamp(0.0, 1.0);
  return p.distance(XY(a.x + t * dx, a.y + t * dy));
}

List<GeoPoint> simplify(List<GeoPoint> points, {double toleranceKm = 0.4}) {
  if (points.length < 3) return List.of(points);
  final projection = LocalProjection(points.first);
  final xy = points.map(projection.project).toList();
  final keep = <int>{0, points.length - 1};
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    var maxDistance = toleranceKm;
    var index = -1;
    for (var i = start + 1; i < end; i++) {
      final d = segmentDistance(xy[i], xy[start], xy[end]);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }
    if (index >= 0) {
      keep.add(index);
      stack.add((start, index));
      stack.add((index, end));
    }
  }
  return (keep.toList()..sort()).map((i) => points[i]).toList();
}

bool insidePolygon(XY p, List<XY> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i], b = ring[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

bool selfIntersects(List<GeoPoint> ring) {
  double cross(GeoPoint a, GeoPoint b, GeoPoint c) =>
      (b.lon - a.lon) * (c.lat - a.lat) - (b.lat - a.lat) * (c.lon - a.lon);
  for (var i = 0; i < ring.length - 1; i++) {
    for (var j = i + 2; j < ring.length - 1; j++) {
      if (i == 0 && j == ring.length - 2) continue;
      final a = ring[i], b = ring[i + 1], c = ring[j], d = ring[j + 1];
      if (cross(a, b, c) * cross(a, b, d) < 0 &&
          cross(c, d, a) * cross(c, d, b) < 0) {
        return true;
      }
    }
  }
  return false;
}

List<GeoPoint> closeRing(List<GeoPoint> points) {
  if (points.isEmpty) return [];
  final result = List<GeoPoint>.of(points);
  if (distanceKm(result.first, result.last) > 0.000001) {
    result.add(result.first);
  }
  return result;
}
