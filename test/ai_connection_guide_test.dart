import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/ai_service.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/features/ai_connection_guide.dart';
import 'package:slepa_mapa/features/ai_page.dart';

void main() {
  test('guide URLs resolve to compatible chat endpoints', () {
    expect(
      aiConnectionPresets.map(
        (p) => AiProviderConfig(
          baseUrl: p.baseUrl,
          model: 'available-model',
        ).endpoint().toString(),
      ),
      [
        'https://api.openai.com/v1/chat/completions',
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
        'https://api.anthropic.com/v1/chat/completions',
        'https://api.deepseek.com/chat/completions',
        'http://localhost:11434/v1/chat/completions',
      ],
    );
  });

  testWidgets('guide applies provider without retaining old credentials', (
    tester,
  ) async {
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: AiPage(store: store, land: const []),
      ),
    );
    await tester.tap(find.text('Pomocí API'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byWidgetPredicate((w) => w is TextField && w.obscureText),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    final base = fields
        .singleWhere((f) => f.decoration?.labelText == 'Base URL')
        .controller!;
    final model = fields
        .singleWhere((f) => f.decoration?.labelText == 'Model')
        .controller!;
    final key = fields.singleWhere((f) => f.obscureText).controller!;
    model.text = 'old-model';
    key.text = 'test-only-old-provider-key';
    final guide = find.text('Jak připojit AI přes API');
    await tester.scrollUntilVisible(
      guide,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(guide);
    await tester.tap(guide);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Gemini'));
    await tester.pumpAndSettle();
    final apply = find.text('Použít nastavení');
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(
      base.text,
      'https://generativelanguage.googleapis.com/v1beta/openai',
    );
    expect(model.text, isEmpty);
    expect(key.text, isEmpty);
    expect(store.provider, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English tutorial fits a narrow mobile screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: AiConnectionGuide(czech: false)),
    );
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('Apply settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
