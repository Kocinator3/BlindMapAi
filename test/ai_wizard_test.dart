import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/ai_service.dart';
import 'package:slepa_mapa/data/catalog_text.dart';
import 'package:slepa_mapa/data/feature_catalog.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/features/ai_page.dart';
import 'package:slepa_mapa/features/editor.dart';

Map<String, dynamic> draft({bool missing = false}) => {
  'protocol': CatalogTextSession.protocol,
  'catalog': CatalogTextSession.revision,
  'action': 'propose',
  'userText': 'Praha a Brno ke kontrole.',
  'queries': [
    {
      'text': 'Praha',
      'kind': 'city',
      'countryCode': 'CZ',
      'userText': 'Praha, Česko',
    },
    if (missing)
      {
        'text': 'Nonexistent test city 91823',
        'kind': 'city',
        'userText': 'Neznámé město',
      },
    {
      'text': 'Brno',
      'kind': 'city',
      'countryCode': 'CZ',
      'userText': 'Brno, Česko',
    },
  ],
};

class FakeProvider implements AiProvider {
  final List<String> replies;
  final List<String> prompts = [];
  FakeProvider(this.replies);
  @override
  Future<String> generate(AiProviderConfig config, String prompt) async {
    prompts.add(prompt);
    return replies.removeAt(0);
  }

  @override
  void cancel() {}
}

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final target = find.text(text);
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  position.jumpTo(0);
  await tester.pumpAndSettle();
  for (var i = 0; target.evaluate().isEmpty && i < 30; i++) {
    position.jumpTo((position.pixels + 200).clamp(0, position.maxScrollExtent));
    await tester.pumpAndSettle();
  }
  final button = find.ancestor(of: target, matching: find.byType(FilledButton));
  await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeatureCatalog catalog;
  setUpAll(() async => catalog = await FeatureCatalog.load());
  setUp(() {
    rootBundle.evict('docs/CATALOG_TEXT_INSTRUCTIONS.md');
    rootBundle.evict('docs/level.schema.json');
  });

  testWidgets(
    'manual wizard batches queries, cancels repairs, deletes missing place and exports approved prompt',
    (tester) async {
      String clipboard = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AiPage(store: AppStore()..language = 'en', land: const []),
        ),
      );
      expect(find.text('Step 1 of 5 · Method'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await press(tester, 'Manual chat');
      await tester.enterText(
        find.byType(TextField),
        'Praha, Brno and an unknown city',
      );
      await press(tester, 'Continue to catalog proposal');
      await press(tester, 'Copy request and instructions for chat');
      expect(clipboard, contains('"action": "propose"'));
      expect(clipboard, contains('Praha, Brno and an unknown city'));
      final source = jsonEncode(draft(missing: true));
      await tester.enterText(find.byType(TextField), source);
      await press(tester, 'Validate complete catalog');
      expect(find.text('Invalid catalog item'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        source,
      );
      expect(find.text('Step 3 of 5 · Catalog proposal'), findsOneWidget);
      await press(tester, 'Validate complete catalog');
      await tester.tap(find.text('Delete item'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 5 · Review'), findsOneWidget);
      expect(find.text('Praha a Brno ke kontrole.'), findsOneWidget);
      await press(tester, 'Confirm catalog and continue');
      await press(tester, 'Copy approved catalog and final prompt');
      final matches = resolveCatalogProposal(
        catalog,
        jsonEncode(draft()),
      ).expand((i) => i.matches).toList();
      for (final item in matches) {
        expect(clipboard, contains(item.id));
      }
      expect(clipboard, contains('deleted'));
      expect(
        clipboard,
        contains('Include EVERY listed catalogId exactly once'),
      );
      expect(find.text('Step 5 of 5 · Final level'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'API needs one proposal call and explicit approval before final generation',
    (tester) async {
      final store = AppStore()..language = 'en';
      store.provider = {
        'baseUrl': 'https://example.invalid/v1',
        'model': 'test',
      };
      final items = resolveCatalogProposal(
        catalog,
        jsonEncode(draft()),
      ).expand((i) => i.matches).toList();
      final provider = FakeProvider([
        jsonEncode(draft()),
        jsonEncode({
          'schemaVersion': 1,
          'id': 'wizard-level',
          'title': 'Cities',
          'questions': [
            for (final f in items)
              {
                'id': f.id,
                'catalogId': f.id,
                'catalogText': f.name,
                'prompt': 'Mark ${f.name}',
              },
          ],
        }),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: AiPage(store: store, land: const [], provider: provider),
        ),
      );
      await press(tester, 'Use API');
      await tester.enterText(
        find.widgetWithText(TextField, 'List of places and level instructions'),
        'Praha and Brno',
      );
      await press(tester, 'Continue to catalog proposal');
      await press(tester, 'Generate complete proposal via API');
      expect(
        provider.prompts,
        hasLength(1),
        reason: tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data)
            .join('\n'),
      );
      expect(find.text('Step 4 of 5 · Review'), findsOneWidget);
      expect(find.text('Generate final level via API'), findsNothing);
      await press(tester, 'Confirm catalog and continue');
      expect(provider.prompts, hasLength(1));
      await press(tester, 'Generate final level via API');
      expect(provider.prompts, hasLength(2));
      expect(find.byType(LevelEditor), findsOneWidget);
      final level = tester.widget<LevelEditor>(find.byType(LevelEditor)).level!;
      expect(level.unverified, isTrue);
      expect(level.questions.length, items.length);
      for (var i = 0; i < items.length; i++) {
        expect(
          level.questions[i].geometry.toJson(),
          items[i].geometry.toJson(),
        );
        expect(provider.prompts.last, contains(items[i].id));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile wizard keeps progress visible and returning preserves proposal',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AiPage(store: AppStore()..language = 'en', land: const []),
        ),
      );
      await press(tester, 'Manual chat');
      await tester.enterText(find.byType(TextField), 'Praha and Brno');
      await press(tester, 'Continue to catalog proposal');
      await tester.enterText(find.byType(TextField), jsonEncode(draft()));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await press(tester, 'Continue to catalog proposal');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        jsonEncode(draft()),
      );
      expect(
        find.text('Step 3 of 5 · Catalog proposal').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
