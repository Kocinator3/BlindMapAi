import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ai_service.dart';
import '../data/store.dart';
import '../data/feature_catalog.dart';
import 'catalog_picker.dart';
import 'catalog_text_page.dart';
import 'catalog_repair.dart';
import '../domain/geo.dart';
import '../domain/level.dart';
import 'editor.dart';
import 'ai_connection_guide.dart';

class AiPage extends StatefulWidget {
  final AppStore store;
  final List<List<GeoPoint>> land;
  const AiPage({super.key, required this.store, required this.land});
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final concepts = TextEditingController();
  late final base = TextEditingController(
    text:
        widget.store.provider['baseUrl'] as String? ??
        'http://localhost:11434/v1',
  );
  late final model = TextEditingController(
    text: widget.store.provider['model'] as String? ?? '',
  );
  late final name = TextEditingController(
    text: widget.store.provider['name'] as String? ?? 'Compatible API',
  );
  late int timeout = widget.store.provider['timeout'] as int? ?? 60;
  List<CatalogFeature> selected = [];
  String contentLanguage = 'cs';
  final key = TextEditingController();
  final provider = CompatibleAiProvider();
  String? message;
  bool busy = false;
  int generation = 0;
  String tr(String cs, String en) => widget.store.language == 'cs' ? cs : en;
  @override
  void dispose() {
    generation++;
    provider.cancel();
    concepts.dispose();
    base.dispose();
    model.dispose();
    key.dispose();
    name.dispose();
    super.dispose();
  }

  Future<String> prompt() async {
    final catalog = await FeatureCatalog.load();
    return AiPromptService().generate(
      concepts: concepts.text,
      language: contentLanguage,
      schema: await rootBundle.loadString('docs/level.schema.json'),
      catalogManifest: catalog.manifest(selected),
      selectionRequired: selected.isNotEmpty,
    );
  }

  Future<void> chooseCatalog() async {
    final result = await showCatalogPicker(
      context,
      land: widget.land,
      czech: widget.store.language == 'cs',
      selected: selected,
    );
    if (mounted && result != null) setState(() => selected = result);
  }

  Future<void> offlineDraft() async {
    if (selected.isEmpty) return;
    try {
      final level = LevelCodec().fromJson(
        Level(
          id: 'catalog-${DateTime.now().microsecondsSinceEpoch}',
          title: concepts.text.trim().isEmpty
              ? tr('Výběr z mapy', 'Map selection')
              : concepts.text.trim(),
          language: contentLanguage,
          unverified: true,
          map: selected.first.map,
          questions: [
            for (final f in selected)
              f.question(czech: contentLanguage == 'cs'),
          ],
        ).toJson(),
      );
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              LevelEditor(store: widget.store, land: widget.land, level: level),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
  }

  Future<void> generate({bool test = false}) async {
    final token = ++generation;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final config = AiProviderConfig(
        baseUrl: base.text.trim(),
        model: model.text.trim(),
        key: key.text,
        name: name.text,
        timeoutSeconds: timeout,
      );
      config.endpoint();
      await widget.store.updateSettings(
        providerSettings: {
          'baseUrl': config.baseUrl,
          'model': config.model,
          'name': config.name,
          'timeout': config.timeoutSeconds,
        },
      );
      if (!mounted || token != generation) return;
      final requestPrompt = test ? 'Reply with OK.' : await prompt();
      if (!mounted || token != generation) return;
      final response = await provider.generate(config, requestPrompt);
      if (!mounted || token != generation) return;
      if (test) {
        setState(
          () => message = tr('Spojení funguje.', 'Connection succeeded.'),
        );
        return;
      }
      final level = await decodeAuthoringWithRepair(
        context,
        extractJsonObject(response),
        czech: widget.store.language == 'cs',
        requireCatalogText: true,
        requiredIds: selected.isEmpty
            ? null
            : selected.map((f) => f.id).toSet(),
      );
      if (!mounted || token != generation || level == null) return;
      final unverified = LevelCodec().fromJson({
        ...level.toJson(),
        'unverified': true,
      });
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => LevelEditor(
              store: widget.store,
              land: widget.land,
              level: unverified,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && token == generation) {
        setState(() => message = e.toString());
      }
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('AI autor • volitelné', 'AI author • optional')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              tr('Tvoje nápady, tvoje mapa', 'Your ideas, your map'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'AI může chybovat v souřadnicích. Výsledek se vždy otevře v editoru jako neověřený. Hraní ani ruční tvorba AI nepotřebují.',
                'AI can invent coordinates. Results always open in the editor as unverified. Playing and manual authoring do not need AI.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: concepts,
              maxLines: 5,
              maxLength: 12000,
              decoration: InputDecoration(
                labelText: tr(
                  'Pojmy (Praha, Labe, Krkonoše…)',
                  'Concepts (Prague, Elbe, Krkonoše…)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : chooseCatalog,
              icon: const Icon(Icons.checklist),
              label: Text(
                tr(
                  'Vybrat řeky, jezera a města (${selected.length})',
                  'Choose rivers, lakes and cities (${selected.length})',
                ),
              ),
            ),
            Text(
              tr(
                'Řeky, jezera a města nejprve vyber z katalogu. AI dostane seznam zaškrtnutých objektů a použije mapová data. Pohoří popiš v pojmech.',
                'Choose rivers, lakes and cities from the catalog first. AI receives the checked list and uses map data. Describe mountains in the concepts.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final result = await Navigator.push<List<CatalogFeature>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CatalogTextPage(
                            czech: widget.store.language == 'cs',
                            land: widget.land,
                            concepts: concepts.text,
                          ),
                        ),
                      );
                      if (mounted && result != null) {
                        setState(() => selected = result);
                      }
                    },
              icon: const Icon(Icons.chat_outlined),
              label: Text(tr('Textový výběr s AI', 'Text selection with AI')),
            ),
            if (selected.isNotEmpty)
              TextButton(
                onPressed: busy ? null : offlineDraft,
                child: Text(
                  tr(
                    'Vytvořit z výběru bez AI',
                    'Create from selection without AI',
                  ),
                ),
              ),
            ListTile(
              title: Text(
                tr('Jazyk vytvořené úrovně', 'Generated content language'),
              ),
              trailing: DropdownButton<String>(
                value: contentLanguage,
                items: const [
                  DropdownMenuItem(value: 'cs', child: Text('Čeština')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) => setState(() => contentLanguage = v!),
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: await prompt()),
                        );
                        if (mounted) {
                          setState(
                            () => message = tr(
                              'Prompt zkopírován. Odpověď vlož přes Import JSON.',
                              'Prompt copied. Paste the response using Import JSON.',
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) setState(() => message = e.toString());
                      }
                    },
              icon: const Icon(Icons.copy),
              label: Text(
                tr(
                  'Kopírovat prompt pro libovolné AI',
                  'Copy prompt for any AI',
                ),
              ),
            ),
            const Divider(height: 32),
            Text(
              tr('Poskytovatel API', 'API provider'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final preset = await Navigator.push<AiConnectionPreset>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiConnectionGuide(
                            czech: widget.store.language == 'cs',
                          ),
                        ),
                      );
                      if (!mounted || preset == null) return;
                      setState(() {
                        name.text = preset.name;
                        base.text = preset.baseUrl;
                        model.clear();
                        key.clear();
                        message = null;
                      });
                    },
              icon: const Icon(Icons.help_outline),
              label: Text(tr('Jak připojit AI přes API', 'Connect AI via API')),
            ),
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: tr('Název poskytovatele', 'Provider name'),
              ),
            ),
            ListTile(
              title: Text(tr('Časový limit', 'Timeout')),
              trailing: DropdownButton<int>(
                value: timeout,
                items: [
                  for (final seconds in [30, 60, 120, 180])
                    DropdownMenuItem(value: seconds, child: Text('$seconds s')),
                ],
                onChanged: (v) => setState(() => timeout = v!),
              ),
            ),
            TextField(
              controller: base,
              decoration: const InputDecoration(labelText: 'Base URL'),
            ),
            TextField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            TextField(
              controller: key,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: tr(
                  'API klíč (pouze pro tuto relaci)',
                  'API key (this session only)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Generovat odešle zadané pojmy a schéma na vybraný server. Test spojení odešle krátký testovací text. Klíč zůstává jen v paměti; není v úrovních ani na disku.',
                'Generate sends your concepts and schema to the selected server. Test connection sends a short test message. The key stays in memory; it is never stored in levels or on disk.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => generate(test: true),
                  child: Text(tr('Test spojení', 'Test connection')),
                ),
                FilledButton(
                  onPressed: busy ? null : generate,
                  child: Text(
                    tr('Generovat / zkusit znovu', 'Generate / retry'),
                  ),
                ),
                if (busy)
                  TextButton(
                    onPressed: () {
                      generation++;
                      provider.cancel();
                      setState(() {
                        busy = false;
                        message = tr('Zrušeno.', 'Cancelled.');
                      });
                    },
                    child: Text(tr('Zrušit', 'Cancel')),
                  ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SelectableText(message!),
              ),
          ],
        ),
      ),
    ),
  );
}
