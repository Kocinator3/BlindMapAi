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

/// Reduce detail over the entire route, keeping both endpoints. Never truncate
/// the tail when an input stroke or a reference exhausts its vertex budget.
List<GeoPoint> simplifyToBudget(List<GeoPoint> points, {int maxPoints = 500}) {
  if (maxPoints < 2) throw ArgumentError.value(maxPoints, 'maxPoints');
  if (points.length <= maxPoints) return List.of(points);
  var tolerance = 0.001;
  var result = List<GeoPoint>.of(points);
  while (result.length > maxPoints) {
    result = simplify(points, toleranceKm: tolerance);
    tolerance *= 2;
  }
  return result;
}

bool selfIntersects(List<GeoPoint> ring) {
  if (ring.length < 4) return false;
  final projection = LocalProjection(ring.first);
  final points = ring.map(projection.project).toList();
  double cross(XY a, XY b, XY c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  bool onSegment(XY a, XY b, XY p) =>
      cross(a, b, p).abs() < 1e-8 &&
      p.x >= math.min(a.x, b.x) - 1e-8 &&
      p.x <= math.max(a.x, b.x) + 1e-8 &&
      p.y >= math.min(a.y, b.y) - 1e-8 &&
      p.y <= math.max(a.y, b.y) + 1e-8;
  for (var i = 0; i < points.length - 1; i++) {
    for (var j = i + 2; j < points.length - 1; j++) {
      if (i == 0 && j == points.length - 2) continue;
      final a = points[i], b = points[i + 1], c = points[j], d = points[j + 1];
      if ((cross(a, b, c) * cross(a, b, d) < 0 &&
              cross(c, d, a) * cross(c, d, b) < 0) ||
          onSegment(a, b, c) ||
          onSegment(a, b, d) ||
          onSegment(c, d, a) ||
          onSegment(c, d, b)) {
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
