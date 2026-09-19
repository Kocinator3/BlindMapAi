import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/features/gameplay.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

Question pointQuestion() => Question(
  id: 'point',
  prompt: 'Find Cairo',
  answerType: AnswerType.point,
  geometry: Geometry('Point', [
    [const GeoPoint(31.2, 30.0)],
  ]),
);

Question areaQuestion() => Question(
  id: 'area',
  prompt: 'Mark the region',
  answerType: AnswerType.freehandArea,
  geometry: Geometry('Polygon', [
    closeRing([
      const GeoPoint(29, 29),
      const GeoPoint(33, 29),
      const GeoPoint(33, 31),
      const GeoPoint(29, 31),
    ]),
  ]),
);

Question lineQuestion() => Question(
  id: 'line',
  prompt: 'Trace the river',
  answerType: AnswerType.polyline,
  geometry: Geometry('LineString', [
    [const GeoPoint(29, 29), const GeoPoint(33, 31)],
  ]),
);

Level levelFor(Question question) =>
    Level(id: 'responsive', title: 'Responsive test', questions: [question]);

Future<void> pumpGameplay(
  WidgetTester tester,
  Size size,
  Question question, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: GameplayPage(
        level: levelFor(question),
        store: AppStore()..language = 'en',
        land: const [],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder paintedMap() => find
    .descendant(of: find.byType(MapCanvas), matching: find.byType(CustomPaint))
    .last;

void expectEditorToolsHidden(WidgetTester tester) {
  expect(find.text('Navigate'), findsNothing);
  expect(find.text('Draw'), findsNothing);
  expect(find.text('Move vertex'), findsNothing);
  expect(find.text('Add vertex'), findsNothing);
  expect(find.text('Delete vertex'), findsNothing);
  expect(find.byTooltip('Redo (Ctrl+Y)'), findsNothing);
}

void main() {
  testWidgets('point gameplay is map-first on narrow portrait', (tester) async {
    await pumpGameplay(tester, const Size(360, 800), pointQuestion());
    final mapSize = tester.getSize(paintedMap());
    expect(mapSize.height, greaterThan(400));
    expect(mapSize.width, greaterThan(300));
    expectEditorToolsHidden(tester);
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(find.text('Confirm answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('point gameplay gives landscape map the dominant area', (
    tester,
  ) async {
    await pumpGameplay(tester, const Size(800, 360), pointQuestion());
    final mapSize = tester.getSize(paintedMap());
    expect(mapSize.width, greaterThan(480));
    expect(mapSize.height, greaterThan(180));
    expectEditorToolsHidden(tester);
    expect(find.text('Confirm answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('area gameplay exposes only area actions in larger portrait', (
    tester,
  ) async {
    await pumpGameplay(tester, const Size(600, 1000), areaQuestion());
    final mapSize = tester.getSize(paintedMap());
    expect(mapSize.height, greaterThan(560));
    expectEditorToolsHidden(tester);
    expect(find.byTooltip('Undo (Ctrl+Z)'), findsOneWidget);
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(
      find.text(
        'Draw the area with one finger. Use two fingers to pan and zoom.',
      ),
      findsOneWidget,
    );
    expect(find.text('Confirm answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('polyline gameplay stays contextual on desktop', (tester) async {
    await pumpGameplay(
      tester,
      const Size(1200, 800),
      lineQuestion(),
      platform: TargetPlatform.linux,
    );
    final mapSize = tester.getSize(paintedMap());
    expect(mapSize.height, greaterThan(500));
    expectEditorToolsHidden(tester);
    expect(find.byTooltip('Undo (Ctrl+Z)'), findsOneWidget);
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(
      find.text('Click to add line vertices. Drag to pan.'),
      findsOneWidget,
    );
    expect(find.text('Confirm answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
