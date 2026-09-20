import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/domain/area_overlap.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/domain/scoring.dart';

Geometry region(List<GeoPoint> points) =>
    Geometry('Polygon', [closeRing(points)]);
Geometry thinL(double width) => region([
  const GeoPoint(14, 49),
  const GeoPoint(16, 49),
  GeoPoint(16, 49 + width),
  GeoPoint(14 + width, 49 + width),
  GeoPoint(14 + width, 51),
  const GeoPoint(14, 51),
]);
Question question(Geometry target) => Question(
  id: 'generic',
  prompt: 'Area',
  answerType: AnswerType.freehandArea,
  geometry: target,
);

void main() {
  test(
    'nearby disjoint thin outlines are forgiven by km tolerance, not overlap',
    () {
      final target = thinL(.001);
      final shifted = Geometry('Polygon', [
        target.points.map((p) => GeoPoint(p.lon + .05, p.lat + .05)).toList(),
      ]);
      final q = question(target);
      final result = scoreAnswer(q, shifted);
      expect(result.points, greaterThan(950));
      expect(result.metadata.containsKey('iou'), isFalse);
      final far = Geometry('Polygon', [
        target.points.map((p) => GeoPoint(p.lon + 5, p.lat + 5)).toList(),
      ]);
      expect(scoreAnswer(q, far).points, lessThan(50));
      final moderate = Geometry('Polygon', [
        target.points.map((p) => GeoPoint(p.lon + .4, p.lat + .4)).toList(),
      ]);
      expect(
        scoreAnswer(q, moderate, toleranceMultiplier: 2).points,
        greaterThan(scoreAnswer(q, moderate, toleranceMultiplier: .5).points),
      );
    },
  );
  test('slanted edge crossings split integration bands', () {
    const a = [XY(0, 0), XY(2, 2), XY(2, 0)];
    const b = [XY(0, 2), XY(2, 0), XY(0, 0)];
    expect(polygonIntersectionArea(a, b), closeTo(1, 1e-10));
    expect(polygonIntersectionArea(b, a), closeTo(1, 1e-10));
  });
  test(
    'rectangle overlaps match analytical area across scales and offsets',
    () {
      final random = math.Random(804);
      List<XY> rect(double x, double y, double w, double h) => [
        XY(x, y),
        XY(x + w, y),
        XY(x + w, y + h),
        XY(x, y + h),
      ];
      for (var i = 0; i < 200; i++) {
        final x = random.nextDouble() * 4 - 2, y = random.nextDouble() * 4 - 2;
        final w = random.nextDouble() * 3 + .00001,
            h = random.nextDouble() * 3 + .00001;
        final expected =
            math.max(0, math.min(2, x + w) - math.max(0, x)) *
            math.max(0, math.min(2, y + h) - math.max(0, y));
        expect(
          polygonIntersectionArea(rect(0, 0, 2, 2), rect(x, y, w, h)),
          closeTo(expected, 1e-10),
        );
      }
    },
  );
  test('near-capacity concave rings produce bounded symmetric overlap', () {
    List<XY> star(double angle) => [
      for (var i = 0; i < 498; i++)
        XY(
          (i.isEven ? 1 : .7) * math.cos(i * 2 * math.pi / 498 + angle),
          (i.isEven ? 1 : .7) * math.sin(i * 2 * math.pi / 498 + angle),
        ),
    ];
    final a = star(0), b = star(.005);
    final overlap = polygonIntersectionArea(a, b);
    expect(overlap, greaterThan(0));
    expect(overlap, lessThanOrEqualTo(polygonArea(a)));
    expect(overlap, closeTo(polygonIntersectionArea(b, a), 1e-9));
  });
  test('regional overlap remains coherent across antimeridian and at high latitude', () {
    for (final latitude in [0.0, 75.0]) {
      final target = region([
        GeoPoint(179, latitude),
        GeoPoint(-179, latitude),
        GeoPoint(-179, latitude + 1),
        GeoPoint(179, latitude + 1),
      ]);
      final guess = region([
        GeoPoint(179.5, latitude),
        GeoPoint(-178.5, latitude),
        GeoPoint(-178.5, latitude + 1),
        GeoPoint(179.5, latitude + 1),
      ]);
      expect(scoreAnswer(question(target), target).points, 1000);
      expect(
        scoreAnswer(question(target), guess).metadata['boundaryErrorKm'],
        greaterThan(0),
      );
    }
  });
  test('thin concave exact region earns full score after serialization', () {
    final target = thinL(.001);
    final level = LevelCodec().decode(
      Level(id: 'thin', title: 'Thin', questions: [question(target)]).encode(),
    );
    expect(scoreAnswer(level.questions.single, target).points, 1000);
  });
  test('thin nested regions have analytical overlap, independent of grid alignment', () {
    final target = thinL(.001);
    final guess = thinL(.0005);
    final result = scoreAnswer(question(target), guess);
    expect(result.points, 1000);
    expect(result.metadata['boundaryErrorKm'], lessThan(0.1));
    expect(result.metadata.containsKey('iou'), isFalse);
  });
  test(
    'reversing ring orientation and starting vertex does not alter overlap',
    () {
      final target = thinL(.001);
      final p = target.parts.single.take(6).toList();
      final shifted = region([...p.skip(2), ...p.take(2)].reversed.toList());
      expect(scoreAnswer(question(target), shifted).points, 1000);
    },
  );
}
