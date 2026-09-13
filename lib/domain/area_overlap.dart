import 'dart:math' as math;

import 'geo.dart';

double polygonArea(List<XY> ring) {
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[(i + 1) % ring.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

typedef _Edge = (XY, XY);

List<_Edge> _edges(List<XY> ring) => [
  for (var i = 0; i < ring.length; i++)
    if (ring[i].y != ring[(i + 1) % ring.length].y)
      (ring[i], ring[(i + 1) % ring.length]),
];

List<double> _crossings(List<_Edge> edges, double y) {
  final xs = <double>[];
  for (final (a, b) in edges) {
    if ((a.y <= y && y < b.y) || (b.y <= y && y < a.y)) {
      xs.add(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x));
    }
  }
  return xs..sort();
}

/// Intersection of two validated simple rings in projected coordinates.
/// Split at vertices and edge crossings. Within each horizontal band, endpoint
/// ordering is fixed and overlap width is linear, so midpoint integration is
/// exact up to floating-point rounding. No raster cells can miss thin regions.
/// Both ring orientations and open/closed coordinate lists are supported.
double polygonIntersectionArea(List<XY> a, List<XY> b) {
  if (a.length < 3 || b.length < 3) return 0;
  final low = math.max(
    a.map((p) => p.y).reduce(math.min),
    b.map((p) => p.y).reduce(math.min),
  );
  final high = math.min(
    a.map((p) => p.y).reduce(math.max),
    b.map((p) => p.y).reduce(math.max),
  );
  if (low >= high) return 0;
  final breaks = <double>{
    low,
    high,
    for (final p in [...a, ...b])
      if (p.y > low && p.y < high) p.y,
  };
  final ae = _edges(a), be = _edges(b);
  for (final (p, q) in ae) {
    for (final (r, s) in be) {
      if (math.max(p.y, q.y) < math.min(r.y, s.y) ||
          math.max(r.y, s.y) < math.min(p.y, q.y) ||
          math.max(p.x, q.x) < math.min(r.x, s.x) ||
          math.max(r.x, s.x) < math.min(p.x, q.x)) {
        continue;
      }
      final dx = q.x - p.x, dy = q.y - p.y;
      final ex = s.x - r.x, ey = s.y - r.y;
      final denominator = dx * ey - dy * ex;
      if (denominator == 0) continue;
      final t = ((r.x - p.x) * ey - (r.y - p.y) * ex) / denominator;
      final u = ((r.x - p.x) * dy - (r.y - p.y) * dx) / denominator;
      if (t > 0 && t < 1 && u > 0 && u < 1) {
        final y = p.y + t * dy;
        if (y > low && y < high) breaks.add(y);
      }
    }
  }
  final ys = breaks.toList()..sort();
  var area = 0.0;
  for (var band = 1; band < ys.length; band++) {
    final y = ys[band - 1] + (ys[band] - ys[band - 1]) / 2;
    final ax = _crossings(ae, y), bx = _crossings(be, y);
    var i = 0, j = 0, width = 0.0;
    while (i + 1 < ax.length && j + 1 < bx.length) {
      width += math.max(
        0,
        math.min(ax[i + 1], bx[j + 1]) - math.max(ax[i], bx[j]),
      );
      if (ax[i + 1] < bx[j + 1]) {
        i += 2;
      } else {
        j += 2;
      }
    }
    area += width * (ys[band] - ys[band - 1]);
  }
  return area;
}
