import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/features/editor.dart';

Future<void> openEditor(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => page),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unsaved imported level remains guarded without further edits', (
    tester,
  ) async {
    final level = Level(
      id: 'imported',
      title: 'Imported content',
      questions: [
        Question(
          id: 'q',
          prompt: 'Place',
          answerType: AnswerType.point,
          geometry: Geometry('Point', [
            [const GeoPoint(15, 50)],
          ]),
        ),
      ],
    );
    await openEditor(
      tester,
      LevelEditor(
        store: AppStore()..language = 'en',
        land: const [],
        level: level,
      ),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
  });

  testWidgets(
    'JSON apply preserves edited canonical metadata through visual save',
    (tester) async {
      final store = AppStore()..language = 'en';
      await openEditor(tester, LevelEditor(store: store, land: const []));
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();
      final level = Level(
        id: 'json-id',
        title: 'Imported metadata',
        difficulty: 'expert',
        tags: ['tag'],
        questions: [
          Question(
            id: 'q',
            prompt: 'Place',
            answerType: AnswerType.point,
            geometry: Geometry('Point', [
              [const GeoPoint(15, 50)],
            ]),
          ),
        ],
      );
      await tester.enterText(find.byType(TextField), level.encode());
      await tester.tap(find.text('Validate and apply'));
      await tester.pumpAndSettle();
      expect(find.byType(LevelEditor), findsOneWidget);
      expect(find.text('Discard unsaved changes?'), findsNothing);
      await tester.ensureVisible(find.text('Save level'));
      await tester.tap(find.text('Save level'));
      await tester.pumpAndSettle();
      expect(store.custom.single.toJson(), level.toJson());
    },
  );
  testWidgets('visual save preserves level metadata', (tester) async {
    final level = Level(
      id: 'custom',
      title: 'Original',
      difficulty: 'advanced',
      tags: ['regional', 'reviewed'],
      questions: [
        Question(
          id: 'q',
          prompt: 'Place',
          answerType: AnswerType.point,
          geometry: Geometry('Point', [
            [const GeoPoint(15, 50)],
          ]),
        ),
      ],
    );
    final store = AppStore()..language = 'en';
    store.custom.add(level);
    await openEditor(
      tester,
      LevelEditor(store: store, land: const [], level: level),
    );
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.ensureVisible(find.text('Save level'));
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    final saved = store.custom.single;
    expect(saved.title, 'Changed');
    expect(saved.difficulty, level.difficulty);
    expect(saved.tags, level.tags);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets(
    'description-only draft is protected and unchanged draft exits quietly',
    (tester) async {
      await openEditor(
        tester,
        LevelEditor(store: AppStore()..language = 'en', land: const []),
      );
      await tester.enterText(find.byType(TextField).at(1), 'Only description');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Discard unsaved changes?'), findsNothing);
    },
  );

  testWidgets('question explanation-only draft is protected', (tester) async {
    await openEditor(
      tester,
      QuestionEditor(
        store: AppStore()..language = 'en',
        land: const [],
        map: const MapConfig(),
      ),
    );
    final explanation = find.widgetWithText(TextField, 'Explanation');
    await tester.ensureVisible(explanation);
    await tester.enterText(explanation, 'Keep this teaching note');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
  });

  testWidgets('JSON draft survives back until explicit discard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showJsonEditor(context, null, czech: false),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{"work":"in progress"}');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('{"work":"in progress"}'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
