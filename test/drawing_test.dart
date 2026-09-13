import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/features/gameplay.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

void main() {
  testWidgets('desktop click places but click-drag pans without placement', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <List<GeoPoint>>[];
    var points = <GeoPoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: StatefulBuilder(
              builder: (context, setState) => MapCanvas(
                land: const [],
                config: const MapConfig(),
                type: AnswerType.point,
                points: points,
                onChanged: (value) {
                  points = value;
                  changes.add(value);
                  setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final map = find.byType(CustomPaint).last;
    final center = tester.getCenter(map);
    final click = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await click.moveTo(center);
    await click.down(center);
    await click.up();
    await tester.pump();
    expect(changes, hasLength(1));

    final jitter = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await jitter.moveTo(center + const Offset(80, 20));
    await jitter.down(center + const Offset(80, 20));
    await jitter.moveTo(center + const Offset(83, 23));
    await jitter.up();
    await tester.pump();
    expect(changes, hasLength(2));

    final drag = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await drag.moveTo(center + const Offset(-120, 0));
    await drag.down(center + const Offset(-120, 0));
    await drag.moveTo(center + const Offset(-40, 0));
    await drag.up();
    await tester.pump();
    expect(changes, hasLength(2));
  });

  testWidgets('desktop polyline clicks add vertices and drag remains pan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <List<GeoPoint>>[];
    var points = <GeoPoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: StatefulBuilder(
              builder: (context, setState) => MapCanvas(
                land: const [],
                config: const MapConfig(),
                type: AnswerType.polyline,
                points: points,
                onChanged: (value) {
                  points = value;
                  changes.add(value);
                  setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final map = find.byType(CustomPaint).last;
    final center = tester.getCenter(map);
    Future<void> clickAt(Offset point) async {
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveTo(point);
      await gesture.down(point);
      await gesture.up();
      await tester.pump();
    }

    await clickAt(center + const Offset(-80, 0));
    await clickAt(center);
    await clickAt(center + const Offset(80, 0));
    expect(changes, hasLength(3));
    expect(changes.last, hasLength(3));
  });

  for (final areaType in [AnswerType.freehandArea, AnswerType.circle]) {
    testWidgets('${areaType.name} desktop drag creates a closed area', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final changes = <List<GeoPoint>>[];
      var points = <GeoPoint>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 700,
              child: StatefulBuilder(
                builder: (context, setState) => MapCanvas(
                  land: const [],
                  config: const MapConfig(),
                  type: areaType,
                  points: points,
                  onChanged: (value) {
                    points = value;
                    changes.add(value);
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byType(CustomPaint).last;
      final center = tester.getCenter(map);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      final start = center + const Offset(-70, -40);
      await gesture.moveTo(start);
      await gesture.down(start);
      for (final point in [
        center + const Offset(70, -40),
        center + const Offset(70, 40),
        center + const Offset(-70, 40),
        if (areaType != AnswerType.circle) start,
      ]) {
        await gesture.moveTo(point);
      }
      await gesture.up();
      await tester.pump();
      expect(changes, hasLength(1));
      expect(changes.single.length, greaterThanOrEqualTo(4));
      expect(
        distanceKm(changes.single.first, changes.single.last),
        lessThan(0.000001),
      );
    });
  }

  testWidgets('area Space-drag pans without creating an answer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = <List<GeoPoint>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: MapCanvas(
              land: const [],
              config: const MapConfig(),
              type: AnswerType.freehandArea,
              points: const [],
              onChanged: (value) => changes.add(value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final map = find.byType(CustomPaint).last;
    final center = tester.getCenter(map);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(center + const Offset(-60, 0));
    await gesture.down(center + const Offset(-60, 0));
    await gesture.moveTo(center + const Offset(100, 0));
    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(changes, isEmpty);
  });

  testWidgets('gameplay transitions derive interaction hint from answer type', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final level = Level(
      id: 'transition',
      title: 'Transition',
      questions: [
        Question(
          id: 'point',
          prompt: 'Point',
          answerType: AnswerType.point,
          geometry: Geometry('Point', [
            [const GeoPoint(15, 50)],
          ]),
        ),
        Question(
          id: 'area-one',
          prompt: 'Area one',
          answerType: AnswerType.freehandArea,
          geometry: Geometry('Polygon', [
            closeRing([
              const GeoPoint(14, 49),
              const GeoPoint(16, 49),
              const GeoPoint(16, 51),
            ]),
          ]),
        ),
        Question(
          id: 'area-two',
          prompt: 'Area two',
          answerType: AnswerType.freehandArea,
          geometry: Geometry('Polygon', [
            closeRing([
              const GeoPoint(14, 49),
              const GeoPoint(16, 49),
              const GeoPoint(16, 51),
            ]),
          ]),
        ),
        Question(
          id: 'point-again',
          prompt: 'Point again',
          answerType: AnswerType.point,
          geometry: Geometry('Point', [
            [const GeoPoint(15, 50)],
          ]),
        ),
      ],
    );
    final store = AppStore()..language = 'en';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: GameplayPage(level: level, store: store, land: const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Click the map to mark a place. Drag to pan.'),
      findsOneWidget,
    );
    await tester.tapAt(tester.getCenter(find.byType(MapCanvas)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Draw the area by dragging. Space + drag pans the map.'),
      findsOneWidget,
    );
  });

  testWidgets('area to point transition resets the interaction mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final area = Question(
      id: 'area',
      prompt: 'Area',
      answerType: AnswerType.freehandArea,
      geometry: Geometry('Polygon', [
        closeRing([
          const GeoPoint(14, 49),
          const GeoPoint(16, 49),
          const GeoPoint(16, 51),
        ]),
      ]),
    );
    final point = Question(
      id: 'point',
      prompt: 'Point',
      answerType: AnswerType.point,
      geometry: Geometry('Point', [
        [const GeoPoint(15, 50)],
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPage(
          level: Level(
            id: 'area-point',
            title: 'Transition',
            questions: [area, point],
          ),
          store: AppStore()..language = 'en',
          land: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final areaCenter = tester.getCenter(find.byType(MapCanvas));
    final areaGesture = await tester.startGesture(
      areaCenter + const Offset(-50, -30),
    );
    for (final point in [
      areaCenter + const Offset(50, -30),
      areaCenter + const Offset(50, 30),
      areaCenter + const Offset(-50, 30),
      areaCenter + const Offset(-50, -30),
    ]) {
      await areaGesture.moveTo(point);
    }
    await areaGesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Click the map to mark a place. Drag to pan.'),
      findsOneWidget,
    );
    expect(
      find.text('Draw the area by dragging. Space + drag pans the map.'),
      findsNothing,
    );
  });

  for (final type in [
    AnswerType.polyline,
    AnswerType.polygon,
    AnswerType.freehandArea,
    AnswerType.circle,
  ]) {
    testWidgets('${type.name} drawing submits a valid answer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final reference = type == AnswerType.polyline
          ? Geometry('LineString', [
              [const GeoPoint(14, 49), const GeoPoint(16, 50)],
            ])
          : Geometry('Polygon', [
              closeRing([
                const GeoPoint(14, 49),
                const GeoPoint(16, 49),
                const GeoPoint(16, 50),
                const GeoPoint(14, 50),
              ]),
            ]);
      final level = Level(
        id: 'draw',
        title: 'Draw',
        questions: [
          Question(
            id: 'q',
            prompt: 'Draw the answer',
            answerType: type,
            geometry: reference,
          ),
        ],
      );
      final store = AppStore()..language = 'en';
      await tester.pumpWidget(
        MaterialApp(
          home: GameplayPage(level: level, store: store, land: const []),
        ),
      );
      await tester.pumpAndSettle();
      final center =
          tester.getCenter(find.byType(MapCanvas)) + const Offset(0, 30);
      final corners = [
        center + const Offset(-60, -50),
        center + const Offset(60, -50),
        center + const Offset(60, 50),
        center + const Offset(-60, 50),
      ];
      if (type == AnswerType.polygon) {
        for (final p in corners) {
          await tester.tapAt(p);
          await tester.pump();
        }
      } else if (type == AnswerType.freehandArea) {
        final gesture = await tester.startGesture(corners.first);
        // Intermediate moves exceed touch slop and exercise the freehand sampler.
        for (final p in [...corners.skip(1), corners.first]) {
          await gesture.moveTo(p);
          await tester.pump(const Duration(milliseconds: 30));
        }
        await gesture.up();
        await tester.pump();
      } else {
        await tester.dragFrom(corners.first, const Offset(120, 100));
        await tester.pump();
      }
      await tester.tap(find.text('Confirm answer'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      expect(store.history.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
