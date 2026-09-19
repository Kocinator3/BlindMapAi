import 'dart:math' as math;

import 'geo.dart';
import 'area_overlap.dart';
import 'level.dart';

class ScoreResult {
  final int points;
  final double? distance;
  final double coverage;
  final Map<String, double> metadata;
  const ScoreResult(
    this.points, {
    this.distance,
    this.coverage = 0,
    this.metadata = const {},
  });
  double get normalizedScore => points / 1000;
  String get feedback => points >= 850
      ? 'excellent'
      : points >= 600
      ? 'close'
      : points >= 300
      ? 'practice'
      : 'explore';
}

double proximity(double distance, double tolerance) =>
    math.exp(-math.pow(distance / tolerance, 1.35)).toDouble();

ScoreResult scoreAnswer(
  Question question,
  Geometry answer, {
  double toleranceMultiplier = 1,
}) {
  if (!toleranceMultiplier.isFinite ||
      toleranceMultiplier < 0.25 ||
      toleranceMultiplier > 4) {
    throw ArgumentError.value(
      toleranceMultiplier,
      'toleranceMultiplier',
      'Expected 0.25–4',
    );
  }
  if (answer.points.isEmpty || answer.points.any((p) => !p.valid)) {
    return const ScoreResult(0);
  }
  final target = question.geometry;
  final tolerance = question.toleranceKm * toleranceMultiplier;
  if (question.answerType == AnswerType.point) {
    final distance = distanceKm(target.points.first, answer.points.first);
    return ScoreResult(
      (1000 * proximity(distance, tolerance)).round(),
      distance: distance,
    );
  }
  if (question.answerType == AnswerType.multiPoint) {
    // Minimum-cost assignment, independent of the order in which cities were marked.
    final expected = target.points;
    final guesses = answer.points;
    if (expected.length > 12 || guesses.length > 12) {
      return const ScoreResult(0);
    }
    final n = math.max(expected.length, guesses.length);
    final memo = <int, double>{};
    double solve(int mask) {
      final row = mask.toRadixString(2).replaceAll('0', '').length;
      if (row == n) return 0;
      return memo.putIfAbsent(mask, () {
        var best = double.infinity;
        for (var col = 0; col < n; col++) {
          if (mask & (1 << col) != 0) continue;
          final cost = row < expected.length && col < guesses.length
              ? 1 -
                    proximity(
                      distanceKm(expected[row], guesses[col]),
                      tolerance,
                    )
              : 1.0;
          best = math.min(best, cost + solve(mask | (1 << col)));
        }
        return best;
      });
    }

    return ScoreResult((1000 * (1 - solve(0) / n)).round().clamp(0, 1000));
  }
  final projection = LocalProjection(target.points.first);
  final expected = target.parts
      .map((p) => p.map(projection.project).toList())
      .toList();
  final guessed = answer.parts
      .map((p) => p.map(projection.project).toList())
      .toList();
  if (question.answerType == AnswerType.polyline) {
    if (guessed.any((p) => p.length < 2)) return const ScoreResult(0);
    final targetSamples = _samples(expected);
    final guessSamples = _samples(guessed);
    double meanProximity(List<XY> samples, List<List<XY>> lines) =>
        samples
            .map((p) => proximity(_lineDistance(p, lines), tolerance))
            .reduce((a, b) => a + b) /
        samples.length;
    final precision = meanProximity(guessSamples, expected);
    final recall = meanProximity(targetSamples, guessed);
    final score = precision + recall == 0
        ? 0.0
        : 2 * precision * recall / (precision + recall);
    return ScoreResult(
      (1000 * score).round().clamp(0, 1000),
      coverage: recall,
      metadata: {'precision': precision, 'coverage': recall},
    );
  }
  if (answer.points.length < 3 ||
      selfIntersects(closeRing(answer.parts.first))) {
    return const ScoreResult(0);
  }
  // Integrate polygon cross-sections without a fixed grid that can miss thin
  // regions. Areas still use the documented regional projection.
  final a = expected.first, b = guessed.first;
  final targetArea = polygonArea(a), guessArea = polygonArea(b);
  if (targetArea <= 0 || guessArea <= 0) return const ScoreResult(0);
  final intersection = polygonIntersectionArea(
    a,
    b,
  ).clamp(0.0, math.min(targetArea, guessArea));
  final coverage = intersection / targetArea;
  final iou = intersection / (targetArea + guessArea - intersection);
  // Square root makes approximate educational outlines less punishing.
  return ScoreResult(
    (1000 * math.sqrt(iou.clamp(0, 1))).round(),
    coverage: coverage,
    metadata: {
      'iou': iou,
      'coverage': coverage,
      'targetAreaKm2': targetArea,
      'guessAreaKm2': guessArea,
    },
  );
}

double _lineDistance(XY p, List<List<XY>> lines) {
  var best = double.infinity;
  for (final line in lines) {
    for (var i = 1; i < line.length; i++) {
      best = math.min(best, segmentDistance(p, line[i - 1], line[i]));
    }
  }
  return best;
}

List<XY> _samples(List<List<XY>> parts) {
  final segments = <(XY, XY, double)>[];
  var length = 0.0;
  for (final part in parts) {
    for (var i = 1; i < part.length; i++) {
      final size = part[i - 1].distance(part[i]);
      if (size > 0) {
        segments.add((part[i - 1], part[i], size));
        length += size;
      }
    }
  }
  if (segments.isEmpty) return [parts.first.first];
  final result = <XY>[];
  var segment = 0, start = 0.0;
  for (var i = 0; i < 160; i++) {
    final position = length * i / 159;
    while (segment < segments.length - 1 &&
        position > start + segments[segment].$3) {
      start += segments[segment].$3;
      segment++;
    }
    final (a, b, size) = segments[segment];
    final t = ((position - start) / size).clamp(0.0, 1.0);
    result.add(XY(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
  }
  return result;
}
