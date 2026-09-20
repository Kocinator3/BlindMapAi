import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/ai_service.dart';
import 'package:slepa_mapa/data/feature_catalog.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/scoring.dart';
import 'package:slepa_mapa/data/catalog_text.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/features/editor.dart';
import 'package:slepa_mapa/features/catalog_picker.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeatureCatalog catalog;
  setUpAll(() async => catalog = await FeatureCatalog.load());

  test(
    'Nile reference covers the named main course, not a short source segment',
    () async {
      final result = resolveCatalogProposal(
        catalog,
        jsonEncode({
          'protocol': 'slepamapa.catalog/1',
          'catalog': 'ne-v1',
          'action': 'propose',
          'userText': 'Nile',
          'queries': [
            {
              'text': 'Nile',
              'kind': 'river',
              'scope': 'allParts',
              'userText': 'Celý Nil',
            },
          ],
        }),
      );
      expect(result.single.resolved, isTrue);
      final nile = result.single.matches.single;
      expect(nile.geometry.type, 'MultiLineString');
      expect(nile.geometry.points.length, lessThanOrEqualTo(500));
      expect(
        nile.geometry.points.map((p) => p.lat).reduce((a, b) => a < b ? a : b),
        lessThan(1),
      );
      expect(
        nile.geometry.points.map((p) => p.lat).reduce((a, b) => a > b ? a : b),
        greaterThan(31),
      );
      final projection = LocalProjection(nile.geometry.points.first);
      for (final p in [
        const GeoPoint(32.49, 15.63),
        const GeoPoint(31.12, 9.43),
        const GeoPoint(31.23, 30.12),
      ]) {
        final distances = [
          for (final part in nile.geometry.parts)
            for (var i = 1; i < part.length; i++)
              segmentDistance(
                projection.project(p),
                projection.project(part[i - 1]),
                projection.project(part[i]),
              ),
        ];
        expect(distances.reduce((a, b) => a < b ? a : b), lessThan(15));
      }
      expect(scoreAnswer(nile.question(), nile.geometry).points, 1000);
      final short = catalog.byId['ne-v1-river-731-0']!;
      expect(
        scoreAnswer(nile.question(), short.geometry).points,
        lessThan(400),
      );
      final imported = await catalog.decode(
        jsonEncode({
          'schemaVersion': 1,
          'id': 'legacy',
          'title': 'Nile',
          'questions': [
            {'catalogId': short.id},
          ],
        }),
      );
      expect(
        imported.questions.single.geometry.toJson(),
        nile.geometry.toJson(),
      );
      expect(imported.questions.single.id, short.id);
    },
  );

  test(
    'whole river simplification preserves every original component endpoint',
    () {
      for (final old in catalog.features.where(
        (f) => f.replacementId != null,
      )) {
        final whole = catalog.byId[old.replacementId]!;
        for (final part in old.geometry.parts) {
          for (final endpoint in [part.first, part.last]) {
            expect(
              whole.geometry.points.any((p) => distanceKm(p, endpoint) < .01),
              isTrue,
              reason: '${old.id} endpoint missing from ${whole.id}',
            );
          }
        }
      }
    },
  );

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
    expect(
      catalog.selectableFeatures.where((f) => f.kind == 'river').length,
      1192,
    );
    expect(catalog.features.where((f) => f.kind == 'city').length, 7341);
  });

  test(
    'saved segment levels explicitly upgrade and deduplicate full rivers',
    () {
      final a = catalog.byId['ne-v1-river-731-0']!;
      final b = catalog.byId['ne-v1-river-732-0']!;
      final legacy = Level(
        id: 'old',
        title: 'Nile',
        questions: [a.question(), b.question()],
      );
      final updated = catalog.updateLegacyRivers(legacy);
      expect(legacy.questions.length, 2);
      expect(updated.questions.length, 1);
      expect(updated.questions.single.id, legacy.questions.first.id);
      expect(updated.questions.single.geometry.type, 'MultiLineString');
      expect(
        updated.questions.single.geometry.points.length,
        lessThanOrEqualTo(500),
      );
      expect(updated.unverified, isTrue);
      expect(identical(catalog.updateLegacyRivers(updated), updated), isTrue);
    },
  );

  testWidgets(
    'editor offers whole-course repair for already saved river segments',
    (tester) async {
      final old = catalog.byId['ne-v1-river-731-0']!;
      await tester.pumpWidget(
        MaterialApp(
          home: LevelEditor(
            store: AppStore()..language = 'en',
            land: const [],
            level: Level(
              id: 'old-nile',
              title: 'Nile',
              questions: [old.question()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Replace segments with whole rivers');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(button), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();
      final level = LevelCodec().decode(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
      );
      expect(
        level.questions.single.geometry.toJson(),
        catalog.byId['ne-v2-river-nile-whole']!.geometry.toJson(),
      );
      expect(level.unverified, isTrue);
    },
  );

  test('AI references copy geometry, reject unknown or missing IDs, roundtrip without catalog', () async {
    final selected = [
      for (final kind in ['river', 'lake', 'city'])
        catalog.selectableFeatures.firstWhere((f) => f.kind == kind),
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
