import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/map/map_canvas.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/features/gameplay.dart';

void main() {
  late List<GeoPoint> points;
  late List<List<GeoPoint>> changes;
  Future<void> mount(WidgetTester tester, AnswerType type) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    points = [];
    changes = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MapCanvas(
              land: const [],
              config: const MapConfig(),
              type: type,
              points: points,
              czech: false,
              onChanged: (value) {
                points = value;
                changes.add(value);
                setState(() {});
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder surface() => find
      .descendant(
        of: find.byType(MapCanvas),
        matching: find.byType(CustomPaint),
      )
      .last;
  Offset origin(WidgetTester tester) => tester.getCenter(surface());
  dynamic painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(surface()).painter;

  testWidgets('touch river stays open', (tester) async {
    await mount(tester, AnswerType.polyline);
    final p = origin(tester);
    final g = await tester.startGesture(p - const Offset(100, 0));
    await g.moveTo(p);
    await g.moveTo(p + const Offset(100, 60));
    await g.up();
    await tester.pump();
    expect(points.length, greaterThanOrEqualTo(2));
    expect(distanceKm(points.first, points.last), greaterThan(1));
  });

  for (final type in [
    AnswerType.polygon,
    AnswerType.freehandArea,
    AnswerType.circle,
  ]) {
    testWidgets('${type.name}: pinch cancels draft until all fingers lift', (
      tester,
    ) async {
      await mount(tester, type);
      final p = origin(tester);
      final first = await tester.startGesture(
        p - const Offset(100, 0),
        pointer: 1,
      );
      await first.moveTo(p - const Offset(60, 40));
      final second = await tester.startGesture(
        p + const Offset(100, 0),
        pointer: 2,
      );
      await second.moveTo(p + const Offset(160, 40));
      await first.moveTo(p - const Offset(120, 40));
      await second.up();
      await first.moveTo(p + const Offset(0, 80));
      await first.up();
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets(
      '${type.name}: desktop trace visible and closed; Space pan preserves answer',
      (tester) async {
        await mount(tester, type);
        final p = origin(tester);
        final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await g.down(p - const Offset(100, 60));
        await g.moveTo(p + const Offset(100, -60));
        await g.moveTo(p + const Offset(100, 60));
        await tester.pump();
        expect(painter(tester).points, isNotEmpty);
        await g.moveTo(p + const Offset(-100, 60));
        await g.up();
        await tester.pump();
        expect(points.length, greaterThanOrEqualTo(4));
        if (type != AnswerType.circle) {
          expect(points, hasLength(5));
          final center = painter(tester).center as GeoPoint;
          final scale =
              tester.getSize(surface()).width /
              (painter(tester).span as double);
          expect(points.first.lon, closeTo(center.lon - 100 / scale, 0.000001));
        }
        expect(distanceKm(points.first, points.last), lessThan(0.000001));
        final count = changes.length;
        final oldCenter = painter(tester).center as GeoPoint;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await g.down(p);
        await g.moveTo(p + const Offset(70, 0));
        await g.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(changes.length, count);
        expect(
          distanceKm(oldCenter, painter(tester).center as GeoPoint),
          greaterThan(0),
        );
      },
    );
  }

  testWidgets('mouse pan actually moves viewport; wheel changes scale', (
    tester,
  ) async {
    await mount(tester, AnswerType.point);
    final p = origin(tester);
    final oldCenter = painter(tester).center as GeoPoint;
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(p);
    await g.moveTo(p + const Offset(60, 0));
    await g.up();
    await tester.pump();
    expect(changes, isEmpty);
    expect(
      distanceKm(oldCenter, painter(tester).center as GeoPoint),
      greaterThan(0),
    );
    final span = painter(tester).span as double;
    await tester.sendEventToBinding(
      PointerScrollEvent(position: p, scrollDelta: const Offset(0, -100)),
    );
    await tester.pump();
    expect(painter(tester).span, lessThan(span));
  });

  testWidgets(
    'desktop polygon clicks and move/delete tools edit unique vertices',
    (tester) async {
      await mount(tester, AnswerType.polygon);
      final p = origin(tester);
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final corners = [
        p + const Offset(-80, -40),
        p + const Offset(80, -40),
        p + const Offset(80, 40),
        p + const Offset(-80, 40),
      ];
      for (final corner in corners) {
        await g.down(corner);
        await g.up();
        await tester.pump();
      }
      expect(points, hasLength(4));
      final original = points.first;
      await tester.tap(find.text('Move vertex'));
      await tester.pump();
      await g.down(corners.first);
      await g.moveTo(corners.first + const Offset(-30, -10));
      await g.up();
      await tester.pump();
      expect(points, hasLength(4));
      expect(distanceKm(points.first, original), greaterThan(0));
      await tester.tap(find.text('Delete vertex'));
      await tester.pump();
      await g.down(corners[1]);
      await g.up();
      await tester.pump();
      expect(points, hasLength(3));
    },
  );

  testWidgets('cancelled mouse stroke cannot leak into the next click', (
    tester,
  ) async {
    await mount(tester, AnswerType.freehandArea);
    final p = origin(tester);
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.down(p);
    await g.moveTo(p + const Offset(80, 40));
    await g.cancel();
    await tester.pump();
    expect(changes, isEmpty);
    await mount(tester, AnswerType.point);
    await tester.tapAt(origin(tester));
    await tester.pump();
    expect(points, hasLength(1));
  });

  testWidgets('type changes reset selected navigation tool and undo history', (
    tester,
  ) async {
    await mount(tester, AnswerType.point);
    await tester.tapAt(origin(tester));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move vertex'));
    await mount(tester, AnswerType.freehandArea);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Draw'))
          .selected,
      isTrue,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(changes, isEmpty);
  });

  testWidgets(
    'all question transitions reset answers and undo; both mountain questions submit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mountains = LevelCodec().decode(
        File('assets/levels/czech-mountains.json').readAsStringSync(),
      );
      final types = [
        AnswerType.point,
        AnswerType.freehandArea,
        AnswerType.freehandArea,
        AnswerType.point,
        AnswerType.polyline,
        AnswerType.polygon,
      ];
      final questions = [
        for (var i = 0; i < types.length; i++)
          Question(
            id: 'arbitrary-$i',
            prompt: 'Question $i',
            answerType: types[i],
            geometry: types[i] == AnswerType.point
                ? Geometry('Point', [
                    [const GeoPoint(15, 50)],
                  ])
                : types[i] == AnswerType.polyline
                ? Geometry('LineString', [
                    [const GeoPoint(14, 49), const GeoPoint(16, 51)],
                  ])
                : mountains.questions.first.geometry,
          ),
        ...mountains.questions,
      ];
      final store = AppStore()..language = 'en';
      await tester.pumpWidget(
        MaterialApp(
          home: GameplayPage(
            level: Level(
              id: 'generic-transitions',
              title: 'Generic transitions',
              questions: questions,
            ),
            store: store,
            land: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < questions.length; i++) {
        expect(find.text(questions[i].prompt), findsOneWidget);
        expect(
          tester.widget<MapCanvas>(find.byType(MapCanvas)).points,
          isEmpty,
        );
        await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
        await tester.pump();
        expect(
          tester.widget<MapCanvas>(find.byType(MapCanvas)).points,
          isEmpty,
        );
        final p = origin(tester);
        final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
        final type = questions[i].answerType;
        if (type == AnswerType.point || type == AnswerType.polyline) {
          for (final offset in [
            const Offset(-60, -40),
            if (type == AnswerType.polyline) const Offset(60, 40),
          ]) {
            await g.down(p + offset);
            await g.up();
            await tester.pump();
          }
        } else {
          await g.down(p - const Offset(60, 40));
          await g.moveTo(p + const Offset(60, -40));
          await g.moveTo(p + const Offset(60, 40));
          await g.moveTo(p + const Offset(-60, 40));
          await g.up();
          await tester.pump();
        }
        await tester.tap(find.text('Confirm answer'));
        await tester.pumpAndSettle();
        expect(store.history, hasLength(i + 1));
        expect(find.text('Continue'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Results'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
