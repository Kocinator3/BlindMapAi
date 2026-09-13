import 'dart:convert';

import 'geo.dart';

enum AnswerType { point, polyline, polygon, freehandArea, circle, multiPoint }

class Geometry {
  final String type;
  final List<List<GeoPoint>> parts;
  Geometry(this.type, List<List<GeoPoint>> parts)
    : parts = List.unmodifiable(
        parts.map((p) => List<GeoPoint>.unmodifiable(p)),
      );
  List<GeoPoint> get points => parts.expand((p) => p).toList();
  Map<String, dynamic> toJson() {
    final lists = parts.map((p) => p.map((v) => v.toJson()).toList()).toList();
    return {
      'type': type,
      'coordinates': switch (type) {
        'Point' => lists.first.first,
        'LineString' || 'MultiPoint' => lists.first,
        _ => lists,
      },
    };
  }
}

class Question {
  final String id, prompt, category, explanation, difficulty;
  final AnswerType answerType;
  final Geometry geometry;
  final List<String> hints, tags;
  final double toleranceKm;
  Question({
    required this.id,
    required this.prompt,
    required this.answerType,
    required this.geometry,
    this.category = 'geography',
    this.explanation = '',
    this.difficulty = 'beginner',
    List<String> hints = const [],
    List<String> tags = const [],
    this.toleranceKm = 30,
  }) : hints = List.unmodifiable(hints),
       tags = List.unmodifiable(tags);
  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'answerType': answerType.name,
    'category': category,
    'geometry': geometry.toJson(),
    'explanation': explanation,
    'hints': hints,
    'tags': tags,
    'difficulty': difficulty,
    'scoring': {'toleranceKm': toleranceKm},
  };
}

class MapConfig {
  final GeoPoint center;
  final double span;
  final bool borders;
  const MapConfig({
    this.center = const GeoPoint(15.5, 49.8),
    this.span = 9,
    this.borders = true,
  });
  Map<String, dynamic> toJson() => {
    'center': center.toJson(),
    'longitudeSpan': span,
    'showCountryBorders': borders,
  };
}

class Level {
  final String id, title, description, language, difficulty;
  final bool unverified;
  final List<String> tags;
  final MapConfig map;
  final List<Question> questions;
  Level({
    required this.id,
    required this.title,
    required List<Question> questions,
    this.description = '',
    this.language = 'cs',
    this.difficulty = 'beginner',
    this.unverified = false,
    this.map = const MapConfig(),
    List<String> tags = const [],
  }) : questions = List.unmodifiable(questions),
       tags = List.unmodifiable(tags);
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'description': description,
    'language': language,
    'difficulty': difficulty,
    'unverified': unverified,
    'tags': tags,
    'map': map.toJson(),
    'questions': questions.map((q) => q.toJson()).toList(),
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class LevelValidationException implements Exception {
  final String message;
  const LevelValidationException(this.message);
  @override
  String toString() => message;
}

class LevelCodec {
  static const maxBytes = 2 * 1024 * 1024;
  static const maxQuestions = 100;
  static const maxVertices = 500;
  Never fail(String path, String reason) =>
      throw LevelValidationException('$path: $reason');
  Map<String, dynamic> object(dynamic value, String path) {
    if (value is! Map<String, dynamic>) fail(path, 'Expected a JSON object.');
    return value;
  }

  String string(dynamic value, String path, {String? fallback}) {
    if (value == null && fallback != null) return fallback;
    if (value is! String || value.trim().isEmpty || value.length > 4000) {
      fail(path, 'Expected nonempty text of at most 4000 characters.');
    }
    return value;
  }

  double number(dynamic value, String path, double min, double max) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      fail(path, 'Expected a finite number between $min and $max.');
    }
    return value.toDouble();
  }

  List<String> strings(dynamic value, String path) {
    if (value == null) return [];
    if (value is! List || value.length > 50) {
      fail(path, 'Expected at most 50 text entries.');
    }
    return [
      for (var i = 0; i < value.length; i++) string(value[i], '$path[$i]'),
    ];
  }

  GeoPoint point(dynamic value, String path) {
    if (value is! List || value.length != 2) {
      fail(path, 'Expected [longitude, latitude].');
    }
    return GeoPoint(
      number(value[0], '$path.longitude', -180, 180),
      number(value[1], '$path.latitude', -85, 85),
    );
  }

  Map<String, dynamic> migrate(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version == 0) {
      // Legacy prototype named its title "name"; coordinate order was already GeoJSON.
      return {...json, 'schemaVersion': 1, 'title': json['name']};
    }
    if (version != 1) {
      fail('schemaVersion', 'Unsupported version $version. Supported: 0, 1.');
    }
    return json;
  }

  Level decode(String source) {
    if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
      fail('JSON', 'Input exceeds 2 MiB.');
    }
    // Bound nesting before the recursive JSON decoder sees untrusted input.
    var depth = 0, quoted = false, escaped = false;
    for (final c in source.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          quoted = false;
        }
      } else if (c == 34) {
        quoted = true;
      } else if (c == 123 || c == 91) {
        if (++depth > 32) fail('JSON', 'Nesting exceeds 32 levels.');
      } else if (c == 125 || c == 93) {
        depth--;
      }
    }
    try {
      return fromJson(object(jsonDecode(source), 'Level'));
    } on FormatException catch (e) {
      fail('JSON', 'Invalid syntax: ${e.message} (offset ${e.offset ?? 0}).');
    }
  }

  Level fromJson(Map<String, dynamic> input) {
    final json = migrate(input);
    final rawQuestions = json['questions'];
    if (rawQuestions is! List ||
        rawQuestions.isEmpty ||
        rawQuestions.length > maxQuestions) {
      fail('questions', 'Expected 1–$maxQuestions questions.');
    }
    final ids = <String>{};
    final questions = <Question>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      final q = object(rawQuestions[i], 'questions[$i]');
      final id = string(q['id'], 'questions[$i].id');
      final path = 'Question "$id"';
      if (!ids.add(id)) fail(path, 'Duplicate question ID.');
      final typeName = string(q['answerType'], '$path.answerType');
      final types = AnswerType.values.where((t) => t.name == typeName);
      if (types.isEmpty) fail(path, 'Unknown answerType "$typeName".');
      final type = types.first;
      final g = object(q['geometry'], '$path.geometry');
      final expected = switch (type) {
        AnswerType.point => ['Point'],
        AnswerType.polyline => ['LineString', 'MultiLineString'],
        AnswerType.multiPoint => ['MultiPoint'],
        _ => ['Polygon'],
      };
      if (!expected.contains(g['type'])) {
        fail(
          path,
          'answerType "$typeName" expects ${expected.join(' or ')}, received ${g['type']}.',
        );
      }
      final coordinates = g['coordinates'];
      List<dynamic> parts;
      if (g['type'] == 'Point') {
        parts = [
          [coordinates],
        ];
      } else if (g['type'] == 'LineString' || g['type'] == 'MultiPoint') {
        parts = [coordinates];
      } else {
        if (coordinates is! List ||
            coordinates.isEmpty ||
            coordinates.length > 20) {
          fail(path, 'Expected 1–20 geometry parts.');
        }
        parts = coordinates;
      }
      if (g['type'] == 'Polygon' && parts.length != 1) {
        fail(
          path,
          'Polygon holes are not supported in schema v1. Use one exterior ring.',
        );
      }
      var count = 0;
      final parsed = <List<GeoPoint>>[];
      for (final part in parts) {
        if (part is! List || part.isEmpty || part.length > maxVertices) {
          fail(path, 'Geometry part must contain 1–$maxVertices vertices.');
        }
        count += part.length;
        if (count > maxVertices) {
          fail(path, 'Geometry exceeds $maxVertices total vertices.');
        }
        final points = [
          for (var j = 0; j < part.length; j++)
            point(part[j], '$path.coordinates[$j]'),
        ];
        if (g['type'] == 'Polygon') {
          if (points.length < 4 ||
              distanceKm(points.first, points.last) > 0.000001) {
            fail(
              path,
              'Polygon needs at least three vertices and a closing copy of the first vertex.',
            );
          }
          if (selfIntersects(points)) {
            fail(
              path,
              'Polygon edges cross. Move or remove crossing vertices.',
            );
          }
          final projection = LocalProjection(points.first);
          final xy = points.map(projection.project).toList();
          var area = 0.0;
          for (var j = 1; j < xy.length; j++) {
            area += xy[j - 1].x * xy[j].y - xy[j].x * xy[j - 1].y;
          }
          if (area.abs() < 0.0001) {
            fail(path, 'Polygon must enclose a nonzero area.');
          }
          if (points.any((p) => distanceKm(points.first, p) > 3500)) {
            fail(
              path,
              'Area exceeds the supported regional scoring extent (3500 km).',
            );
          }
        } else if (g['type'] == 'LineString' ||
            g['type'] == 'MultiLineString') {
          if (points.length < 2 ||
              points
                  .skip(1)
                  .every((p) => distanceKm(p, points.first) < 0.000001)) {
            fail(path, 'Line needs at least two distinct points.');
          }
        }
        parsed.add(points);
      }
      final scoring = object(
        q['scoring'] ?? <String, dynamic>{},
        '$path.scoring',
      );
      questions.add(
        Question(
          id: id,
          prompt: string(q['prompt'], '$path.prompt'),
          answerType: type,
          geometry: Geometry(g['type'] as String, parsed),
          category: string(
            q['category'],
            '$path.category',
            fallback: 'geography',
          ),
          explanation: q['explanation'] == ''
              ? ''
              : string(q['explanation'], '$path.explanation', fallback: ''),
          hints: strings(q['hints'], '$path.hints'),
          tags: strings(q['tags'], '$path.tags'),
          difficulty: string(
            q['difficulty'],
            '$path.difficulty',
            fallback: 'beginner',
          ),
          toleranceKm: number(
            scoring['toleranceKm'] ?? 30,
            '$path.scoring.toleranceKm',
            0.1,
            2000,
          ),
        ),
      );
    }
    final map = object(json['map'] ?? <String, dynamic>{}, 'map');
    if (json['unverified'] != null && json['unverified'] is! bool) {
      fail('unverified', 'Expected a boolean.');
    }
    if (map['showCountryBorders'] != null &&
        map['showCountryBorders'] is! bool) {
      fail('map.showCountryBorders', 'Expected a boolean.');
    }
    return Level(
      id: string(json['id'], 'id'),
      title: string(json['title'], 'title'),
      description: json['description'] == ''
          ? ''
          : string(json['description'], 'description', fallback: ''),
      language: string(json['language'], 'language', fallback: 'cs'),
      difficulty: string(
        json['difficulty'],
        'difficulty',
        fallback: 'beginner',
      ),
      tags: strings(json['tags'], 'tags'),
      unverified: json['unverified'] == true,
      map: MapConfig(
        center: point(map['center'] ?? [15.5, 49.8], 'map.center'),
        span: number(map['longitudeSpan'] ?? 9, 'map.longitudeSpan', 0.1, 160),
        borders: map['showCountryBorders'] != false,
      ),
      questions: questions,
    );
  }
}
