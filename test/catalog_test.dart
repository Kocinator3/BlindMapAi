import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/ai_service.dart';
import 'package:slepa_mapa/data/feature_catalog.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/features/catalog_picker.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeatureCatalog catalog;
  setUpAll(() async => catalog = await FeatureCatalog.load());

  test('every catalog geometry validates in the canonical offline model', () {
    expect(
      catalog.features.map((f) => f.id).toSet().length,
      catalog.features.length,
    );
    final failures = <String>[];
    for (final f in catalog.features) {
      try {
        LevelCodec().fromJson(
          Level(id: 'check', title: f.name, questions: [f.question()]).toJson(),
        );
      } catch (e) {
        failures.add('${f.id} ${f.name}: $e');
      }
    }
    expect(failures, isEmpty);
    expect(
      catalog.features.where((f) => f.kind == 'lake').length,
      greaterThan(1300),
    );
    expect(catalog.features.where((f) => f.kind == 'river').length, 2442);
    expect(catalog.features.where((f) => f.kind == 'city').length, 7341);
  });

  test('AI references copy geometry, reject unknown or missing IDs, roundtrip without catalog', () async {
    final selected = [
      for (final kind in ['river', 'lake', 'city'])
        catalog.features.firstWhere((f) => f.kind == kind),
    ];
    final draft = {
      'schemaVersion': 1,
      'id': 'draft',
      'title': 'Selected geography',
      'unverified': false,
      'questions': [
        for (final f in selected)
          {
            'id': f.id,
            'catalogId': f.id,
            'prompt': 'Find ${f.name}',
            'answerType': 'circle',
            'geometry': {
              'type': 'Point',
              'coordinates': [0, 0],
            },
          },
      ],
    };
    final level = await catalog.decode(
      jsonEncode(draft),
      requiredIds: selected.map((f) => f.id).toSet(),
    );
    expect(level.unverified, isTrue);
    for (var i = 0; i < selected.length; i++) {
      expect(
        level.questions[i].geometry.toJson(),
        selected[i].geometry.toJson(),
      );
      expect(level.questions[i].answerType, selected[i].question().answerType);
    }
    expect(level.encode(), isNot(contains('catalogId')));
    expect(LevelCodec().decode(level.encode()).encode(), level.encode());
    await expectLater(
      catalog.decode(jsonEncode(draft), requiredIds: {'wrong'}),
      throwsA(isA<LevelValidationException>()),
    );
    await expectLater(
      catalog.decode(
        jsonEncode({
          ...draft,
          'questions': [
            {'catalogId': 'unknown'},
          ],
        }),
      ),
      throwsA(isA<LevelValidationException>()),
    );
    await expectLater(
      catalog.decode(
        jsonEncode({
          ...draft,
          'questions': [
            {'catalogId': selected.first.id},
            {'catalogId': selected.first.id},
          ],
        }),
      ),
      throwsA(isA<LevelValidationException>()),
    );
    await expectLater(
      catalog.decode(
        jsonEncode({
          ...draft,
          'questions': [
            {'catalogId': selected.first.id, 'unexpected': true},
          ],
        }),
      ),
      throwsA(isA<LevelValidationException>()),
    );
  });

  test('prompt includes selected IDs and source resolution instructions', () {
    final selected = [catalog.features.firstWhere((f) => f.kind == 'lake')];
    final prompt = AiPromptService().generate(
      concepts: 'lakes and mountains',
      language: 'en',
      schema: '{}',
      catalogManifest: catalog.manifest(selected),
      selectionRequired: true,
    );
    expect(prompt, contains(selected.single.id));
    expect(prompt, contains('Include EVERY listed catalogId exactly once'));
    expect(prompt, contains('Mountains remain'));
    expect(prompt, contains('showLakes'));
    expect(prompt, isNot(contains(catalog.features.last.id)));
  });

  test(
    'lake visibility validates and survives legacy/default and false roundtrip',
    () {
      final json = Level(
        id: 'lake',
        title: 'Lake',
        questions: [catalog.features.first.question()],
      ).toJson();
      expect(
        LevelCodec().fromJson({...json, 'map': <String, dynamic>{}}).map.lakes,
        isTrue,
      );
      final hidden = LevelCodec().fromJson({
        ...json,
        'map': {'showLakes': false},
      });
      expect(LevelCodec().decode(hidden.encode()).map.lakes, isFalse);
      expect(
        () => LevelCodec().fromJson({
          ...json,
          'map': {'showLakes': 'yes'},
        }),
        throwsA(isA<LevelValidationException>()),
      );
    },
  );

  testWidgets(
    'search, checkbox, preview, filters and selected count work offline',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CatalogPicker(land: [], czech: false, limit: 2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Praha');
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1/2)'), findsOneWidget);
      expect(
        tester.widget<MapCanvas>(find.byType(MapCanvas)).target!.type,
        'Point',
      );
      await tester.tap(find.byTooltip('Close preview'));
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Lakes'));
      await tester.pumpAndSettle();
      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles, isNotEmpty);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Apply (2/2)'), findsOneWidget);
      expect(
        tester.widget<MapCanvas>(find.byType(MapCanvas)).target!.type,
        'Polygon',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
