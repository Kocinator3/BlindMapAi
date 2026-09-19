import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/domain/scoring.dart';
import 'package:slepa_mapa/features/gameplay.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

import 'fixed_order_random.dart';

Level pack({bool hardcore = false, double multiplier = 1}) => Level(
  id: 'options',
  title: 'Options',
  hardcore: hardcore,
  toleranceMultiplier: multiplier,
  questions: [
    for (var i = 0; i < 8; i++)
      Question(
        id: 'q$i',
        prompt: 'Locate $i',
        answerType: AnswerType.point,
        geometry: Geometry('Point', [
          [const GeoPoint(15.5, 49.8)],
        ]),
      ),
  ],
);

void main() {
  test('shuffle visits every question once and never mutates the pack', () {
    final level = pack();
    final original = level.questions.map((q) => q.id).toList();
    final orders = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      final ids = level
          .shuffledQuestions(Random(seed))
          .map((q) => q.id)
          .toList();
      expect(ids.toSet(), original.toSet());
      expect(ids.length, original.length);
      orders.add(ids.join(','));
    }
    expect(orders.length, greaterThan(20));
    expect(level.questions.map((q) => q.id), original);
  });
  test('settings round trip, legacy defaults and malformed settings', () {
    final json = pack(hardcore: true, multiplier: 2).toJson();
    json['map'] = const MapConfig(rivers: false, cities: false).toJson();
    final decoded = LevelCodec().fromJson(json);
    expect(LevelCodec().decode(decoded.encode()).toJson(), json);
    final legacy = {...json}
      ..remove('hardcoreMode')
      ..remove('toleranceMultiplier');
    expect(LevelCodec().fromJson(legacy).hardcore, false);
    expect(LevelCodec().fromJson(legacy).toleranceMultiplier, 1);
    for (final value in [null, true, '2', 0, 4.1, double.nan]) {
      expect(
        () => LevelCodec().fromJson({...json, 'toleranceMultiplier': value}),
        throwsA(isA<LevelValidationException>()),
      );
    }
    for (final value in [null, 'true', 1]) {
      expect(
        () => LevelCodec().fromJson({...json, 'hardcoreMode': value}),
        throwsA(isA<LevelValidationException>()),
      );
    }
    for (final key in ['showCities', 'showRivers']) {
      expect(
        () => LevelCodec().fromJson({
          ...json,
          'map': {key: 'true'},
        }),
        throwsA(isA<LevelValidationException>()),
      );
    }
  });
  test('distance multiplier changes scoring monotonically and keeps exact answers perfect', () {
    for (final type in [
      AnswerType.point,
      AnswerType.multiPoint,
      AnswerType.polyline,
    ]) {
      final target = Geometry(
        type == AnswerType.point
            ? 'Point'
            : type == AnswerType.multiPoint
            ? 'MultiPoint'
            : 'LineString',
        [
          [
            const GeoPoint(15, 50),
            if (type != AnswerType.point) const GeoPoint(16, 50),
          ],
        ],
      );
      final answer = Geometry(target.type, [
        target.points.map((p) => GeoPoint(p.lon, p.lat + 0.2)).toList(),
      ]);
      final q = Question(
        id: 'q',
        prompt: 'q',
        answerType: type,
        geometry: target,
      );
      expect(
        scoreAnswer(q, answer, toleranceMultiplier: 2).points,
        greaterThan(scoreAnswer(q, answer, toleranceMultiplier: 0.5).points),
      );
      expect(scoreAnswer(q, target, toleranceMultiplier: 0.25).points, 1000);
    }
  });
  testWidgets(
    'a randomized complete run offers only its five lowest scoring locations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final level = pack();
      final visited = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: GameplayPage(
            level: level,
            store: AppStore()..language = 'en',
            land: const [],
            random: Random(42),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < level.questions.length; i++) {
        final active = level.questions.singleWhere(
          (q) => find.text(q.prompt).evaluate().isNotEmpty,
        );
        visited.add(active.id);
        final number = int.parse(active.id.substring(1));
        tester.widget<MapCanvas>(find.byType(MapCanvas)).onChanged([
          GeoPoint(15.5, 49.8 + number * 0.1),
        ]);
        await tester.pump();
        await tester.tap(find.text('Confirm answer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(visited.toSet(), level.questions.map((q) => q.id).toSet());
      expect(visited, isNot(level.questions.map((q) => q.id).toList()));
      await tester.tap(find.text('Practice weakest locations'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GameplayPage>(find.byType(GameplayPage))
            .level
            .questions
            .map((q) => q.id)
            .toSet(),
        {'q3', 'q4', 'q5', 'q6', 'q7'},
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'hardcore stops after one mistake and offers weakest practice and timed replay',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final level = pack(hardcore: true, multiplier: 0.5);
      final store = AppStore()..language = 'en';
      await tester.pumpWidget(
        MaterialApp(
          home: GameplayPage(
            level: level,
            store: store,
            land: const [],
            random: FixedOrderRandom(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final canvas = tester.widget<MapCanvas>(find.byType(MapCanvas));
      canvas.onChanged([const GeoPoint(0, 0)]);
      await tester.pump();
      await tester.tap(find.text('Confirm answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Answered 1 / 8'), findsOneWidget);
      expect(store.history.length, 1);
      expect(find.text('Timed challenge'), findsOneWidget);
      await tester.tap(find.text('Practice weakest locations'));
      await tester.pumpAndSettle();
      final page = tester.widget<GameplayPage>(find.byType(GameplayPage));
      expect(page.level.questions.map((q) => q.id), ['q0']);
      expect(page.level.hardcore, false);
      expect(page.level.toleranceMultiplier, 0.5);
      expect(page.mode, GameMode.practice);
      tester.widget<MapCanvas>(find.byType(MapCanvas)).onChanged([
        const GeoPoint(15.5, 49.8),
      ]);
      await tester.pump();
      await tester.tap(find.text('Confirm answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timed challenge'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GameplayPage>(find.byType(GameplayPage)).mode,
        GameMode.challenge,
      );
      await tester.pump(const Duration(seconds: 90));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      expect(store.history.last['points'], 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
