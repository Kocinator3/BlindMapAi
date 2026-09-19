import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/features/editor.dart';
import 'package:slepa_mapa/features/gameplay.dart';
import 'package:slepa_mapa/main.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native mountain strokes, temporary pan and question reset', (
    tester,
  ) async {
    final store = AppStore();
    await store.load();
    final level = store.bundled.firstWhere(
      (level) => level.id == 'czech-mountains',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GameplayPage(
          level: level,
          store: store,
          land: await MapCanvas.loadLand(),
          preview: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < level.questions.length; i++) {
      final map = find
          .descendant(
            of: find.byType(MapCanvas),
            matching: find.byType(CustomPaint),
          )
          .last;
      final center = tester.getCenter(map);
      expect(tester.widget<MapCanvas>(find.byType(MapCanvas)).points, isEmpty);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await gesture.down(center);
      await gesture.moveTo(center + const Offset(50, 0));
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(tester.widget<MapCanvas>(find.byType(MapCanvas)).points, isEmpty);
      await gesture.down(center - const Offset(60, 40));
      await gesture.moveTo(center + const Offset(60, -40));
      await gesture.moveTo(center + const Offset(60, 40));
      await gesture.moveTo(center + const Offset(-60, 40));
      await gesture.up();
      await tester.pump();
      expect(
        tester.widget<MapCanvas>(find.byType(MapCanvas)).points.length,
        greaterThanOrEqualTo(4),
      );
      if (i == 0) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find
              .descendant(
                of: find.byType(MapCanvas),
                matching: find.byType(RepaintBoundary),
              )
              .last,
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${Directory.systemTemp.path}/slepamapa-area-review.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }
      await tester.tap(find.text('Potvrdit odpověď'));
      await tester.pumpAndSettle();
      expect(find.text('Pokračovat'), findsOneWidget);
      await tester.tap(find.text('Pokračovat'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Výsledky'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('native launch, demo answer and durable reload', (tester) async {
    final directory = await Directory.systemTemp.createTemp(
      'slepamapa-integration-',
    );
    final store = AppStore(directory: directory);
    await store.load();
    store.language = 'en';
    final land = await MapCanvas.loadLand();
    await tester.pumpWidget(SlepaMapa(store: store, land: land));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play').first);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(MapCanvas)));
    await tester.pump();
    await tester.tap(find.text('Confirm answer'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byType(MapCanvas),
            matching: find.byType(RepaintBoundary),
          )
          .last,
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${Directory.systemTemp.path}/slepamapa-map-review.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();

    expect(store.history.length, 1);
    final restored = AppStore(directory: directory);
    await restored.load();
    expect(restored.history.length, 1);
    await tester.pumpWidget(const SizedBox());
    await directory.delete(recursive: true);
  });
  testWidgets('visual create, question, save, JSON roundtrip and play', (
    tester,
  ) async {
    final store = AppStore();
    await store.load();
    store.language = 'en';
    await tester.pumpWidget(SlepaMapa(store: store, land: const []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My levels'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create level'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'My geography');
    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Where is this point?',
    );
    await tester.tapAt(tester.getCenter(find.byType(MapCanvas)));
    await tester.pump();
    await tester.ensureVisible(find.text('Apply question'));
    await tester.tap(find.text('Apply question'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelEditor), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save level'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    expect(store.custom.length, 1);
    final exported = store.custom.single.encode();
    final imported = LevelCodec().decode(exported);
    expect(imported.questions.single.prompt, 'Where is this point?');
    await tester.tap(find.text('Import JSON'));
    await tester.pumpAndSettle();
    final second = LevelCodec().fromJson({
      ...imported.toJson(),
      'id': 'imported-copy',
      'title': 'Imported geography',
    });
    await tester.enterText(find.byType(TextField), second.encode());
    await tester.tap(find.text('Validate and apply'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save level'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    expect(store.custom.length, 2);

    await tester.tap(find.widgetWithText(FilledButton, 'Play').first);
    await tester.pumpAndSettle();
    expect(find.text('Where is this point?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
