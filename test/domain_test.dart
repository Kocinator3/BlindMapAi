import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/domain/scoring.dart';
import 'package:slepa_mapa/data/ai_service.dart';
import 'package:slepa_mapa/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final codec = LevelCodec();
  Level cities() =>
      codec.decode(File('assets/levels/czech-cities.json').readAsStringSync());
  Geometry line(List<GeoPoint> p) => Geometry('LineString', [p]);
  Geometry polygon(double x, double y, double side) => Geometry('Polygon', [
    closeRing([
      GeoPoint(x, y),
      GeoPoint(x + side, y),
      GeoPoint(x + side, y + side),
      GeoPoint(x, y + side),
    ]),
  ]);
  test('all demo packs validate and round-trip', () {
    for (final file in Directory(
      'assets/levels',
    ).listSync().whereType<File>()) {
      final level = codec.decode(file.readAsStringSync());
      expect(codec.decode(level.encode()).toJson(), level.toJson());
    }
  });
  test('version zero migration', () {
    final json = cities().toJson();
    json['schemaVersion'] = 0;
    json['name'] = json.remove('title');
    expect(codec.fromJson(json).title, 'Česká města');
  });
  test('actionable mismatch and duplicate IDs', () {
    final json = cities().toJson();
    json['questions'][0]['answerType'] = 'polyline';
    expect(
      () => codec.fromJson(json),
      throwsA(
        isA<LevelValidationException>().having(
          (e) => e.message,
          'message',
          contains('LineString'),
        ),
      ),
    );
    final duplicate = cities().toJson();
    duplicate['questions'].add(duplicate['questions'][0]);
    expect(
      () => codec.fromJson(duplicate),
      throwsA(isA<LevelValidationException>()),
    );
  });
  test('coordinates and malicious input rejected', () {
    for (final coord in [
      [181, 0],
      [0, 91],
      [double.nan, 0],
      [1],
      [1, 2, 3],
    ]) {
      final json = cities().toJson();
      json['questions'][0]['geometry']['coordinates'] = coord;
      expect(
        () => codec.fromJson(json),
        throwsA(isA<LevelValidationException>()),
      );
    }
    expect(
      () => codec.decode('${'[' * 40}0${']' * 40}'),
      throwsA(isA<LevelValidationException>()),
    );
    expect(
      () => codec.decode(' ' * (LevelCodec.maxBytes + 1)),
      throwsA(isA<LevelValidationException>()),
    );
  });
  test('malformed fuzz inputs never escape validation exception', () {
    final random = Random(42);
    for (var i = 0; i < 300; i++) {
      final input = String.fromCharCodes(
        List.generate(random.nextInt(100), (_) => random.nextInt(128)),
      );
      expect(
        () => codec.decode(input),
        throwsA(isA<LevelValidationException>()),
      );
    }
  });
  test('Haversine known distance and antimeridian', () {
    expect(
      distanceKm(const GeoPoint(0, 0), const GeoPoint(1, 0)),
      closeTo(111.195, 0.01),
    );
    expect(
      distanceKm(const GeoPoint(179.9, 0), const GeoPoint(-179.9, 0)),
      closeTo(22.239, 0.01),
    );
    expect(
      distanceKm(const GeoPoint(0, 0), const GeoPoint(180, 0)).isFinite,
      isTrue,
    );
  });
  test('point score exact and monotonically decreasing', () {
    final q = cities().questions.first;
    var previous = 1001;
    for (var i = 0; i < 100; i++) {
      final p = q.geometry.points.first;
      final score = scoreAnswer(
        q,
        Geometry('Point', [
          [GeoPoint(p.lon + i * .01, p.lat)],
        ]),
      );
      expect(score.points, lessThanOrEqualTo(previous));
      previous = score.points;
    }
    expect(scoreAnswer(q, q.geometry).points, 1000);
  });
  test('multipoint assignment ignores order and penalizes missing guesses', () {
    final q = cities().questions.last;
    expect(
      scoreAnswer(
        q,
        Geometry('MultiPoint', [q.geometry.points.reversed.toList()]),
      ).points,
      1000,
    );
    expect(
      scoreAnswer(
        q,
        Geometry('MultiPoint', [
          [q.geometry.points.first],
        ]),
      ).points,
      lessThan(500),
    );
  });
  test('polyline scenarios favor coverage and nearby route', () {
    final reference = line([
      const GeoPoint(14, 50),
      const GeoPoint(15, 50),
      const GeoPoint(16, 50),
    ]);
    final q = Question(
      id: 'r',
      prompt: 'River',
      answerType: AnswerType.polyline,
      geometry: reference,
      toleranceKm: 10,
    );
    final exact = scoreAnswer(q, reference).points;
    final near = scoreAnswer(
      q,
      line([const GeoPoint(14, 50.02), const GeoPoint(16, 50.02)]),
    ).points;
    final half = scoreAnswer(
      q,
      line([const GeoPoint(14, 50), const GeoPoint(15, 50)]),
    ).points;
    final wrong = scoreAnswer(
      q,
      line([const GeoPoint(0, 0), const GeoPoint(1, 0)]),
    ).points;
    expect(exact, 1000);
    expect(near, greaterThan(850));
    expect(half, lessThan(near));
    expect(half, greaterThan(wrong));
  });
  test('polygon exact, overlap, oversized, tiny and disjoint', () {
    final reference = polygon(14, 49, 1);
    final q = Question(
      id: 'a',
      prompt: 'Area',
      answerType: AnswerType.polygon,
      geometry: reference,
    );
    expect(scoreAnswer(q, reference).points, 1000);
    expect(
      scoreAnswer(q, polygon(14.5, 49, 1)).points,
      inInclusiveRange(550, 610),
    );
    expect(
      scoreAnswer(q, polygon(13, 48, 3)).points,
      inInclusiveRange(320, 345),
    );
    expect(scoreAnswer(q, polygon(14.4, 49.4, .1)).points, lessThan(150));
    expect(scoreAnswer(q, polygon(0, 0, 1)).points, 0);
  });
  test('crossing and zero area rejected', () {
    final json = cities().toJson();
    json['questions'] = [
      {
        'id': 'bad',
        'prompt': 'Bad',
        'answerType': 'polygon',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [0, 0],
              [1, 1],
              [0, 1],
              [1, 0],
              [0, 0],
            ],
          ],
        },
      },
    ];
    expect(
      () => codec.fromJson(json),
      throwsA(isA<LevelValidationException>()),
    );
  });
  test('simplification retains endpoints and corners', () {
    final points = [for (var i = 0; i < 100; i++) GeoPoint(i * .01, 50)];
    final result = simplify(points);
    expect(result.length, 2);
    expect(result.first, points.first);
    expect(result.last, points.last);
  });
  test(
    'prompt includes canonical safety and parsing handles braces in strings',
    () {
      final prompt = AiPromptService().generate(
        concepts: 'Praha',
        language: 'cs',
        schema: 'SCHEMA',
      );
      expect(prompt, contains('[longitude, latitude]'));
      expect(prompt, contains('No Markdown fences'));
      expect(prompt, contains('SCHEMA'));
      expect(
        jsonDecode(
          extractJsonObject(
            'Here is JSON: ```json\n{"text":"} { ","x":1}\n```',
          ),
        ),
        {'text': '} { ', 'x': 1},
      );
      expect(
        () => extractJsonObject('{'),
        throwsA(isA<LevelValidationException>()),
      );
    },
  );
  test('provider rejects insecure remote URL and credentials', () {
    for (final url in [
      'http://example.com/v1',
      'https://secret@example.com',
      'file:///tmp/x',
      'https://example.com?key=secret',
    ]) {
      expect(
        () => AiProviderConfig(baseUrl: url, model: 'x').endpoint(),
        throwsA(isA<LevelValidationException>()),
      );
    }
    expect(
      AiProviderConfig(
        baseUrl: 'http://localhost:11434/v1/',
        model: 'x',
      ).endpoint().path,
      '/v1/chat/completions',
    );
  });
  test(
    'durable level and progress reload; duplicate submits idempotent',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'slepamapa-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = AppStore(directory: directory);
      final level = cities();
      await store.put(level);
      await store.record(
        session: 's',
        level: level,
        question: level.questions.first,
        points: 850,
      );
      await store.record(
        session: 's',
        level: level,
        question: level.questions.first,
        points: 850,
      );
      final loaded = AppStore(directory: directory);
      await loaded.load();
      expect(loaded.custom.length, 1);
      expect(loaded.best(level.id), 850);
      expect(loaded.xp, 85);
      expect(loaded.history.length, 1);
      expect(loaded.streak, 1);
    },
  );
}
