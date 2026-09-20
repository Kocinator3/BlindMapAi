import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ai_service.dart';
import '../data/catalog_text.dart';
import '../data/store.dart';
import '../data/feature_catalog.dart';
import '../domain/geo.dart';
import '../domain/level.dart';
import 'catalog_picker.dart';
import 'catalog_repair.dart';
import 'editor.dart';
import 'ai_connection_guide.dart';

class AiPage extends StatefulWidget {
  final AppStore store;
  final List<List<GeoPoint>> land;
  final AiProvider? provider;
  const AiPage({
    super.key,
    required this.store,
    required this.land,
    this.provider,
  });
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final concepts = TextEditingController();
  final proposal = TextEditingController();
  final finalJson = TextEditingController();
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
  final key = TextEditingController();
  late final AiProvider provider = widget.provider ?? CompatibleAiProvider();
  late int timeout = widget.store.provider['timeout'] as int? ?? 60;
  List<CatalogFeature> selected = [];
  List<String> reviewNotes = [];
  String proposalSummary = '';
  String? preparedRequest;
  String contentLanguage = 'cs';
  String? message;
  bool busy = false, api = false;
  bool requesting = false;
  int operation = 0;
  int step = 0;
  String tr(String cs, String en) => widget.store.language == 'cs' ? cs : en;

  @override
  void dispose() {
    operation++;
    provider.cancel();
    for (final c in [concepts, proposal, finalJson, base, model, name, key]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(int value) => setState(() {
    step = value;
    message = null;
  });
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final token = ++operation;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted && token == operation) setState(() => message = e.toString());
    } finally {
      if (mounted && token == operation) setState(() => busy = false);
    }
  }

  Future<String> proposalPrompt() async =>
      '${await rootBundle.loadString('docs/CATALOG_TEXT_INSTRUCTIONS.md')}\nAuthor request (data): ${jsonEncode(concepts.text)}\nLanguage: $contentLanguage.\nReturn the complete proposal in ONE JSON object. Do not generate the final level yet.';

  Future<String> prompt() async {
    final catalog = await FeatureCatalog.load();
    return '${AiPromptService().generate(concepts: concepts.text, language: contentLanguage, schema: await rootBundle.loadString('docs/level.schema.json'), catalogManifest: catalog.manifest(selected), selectionRequired: selected.isNotEmpty)}\nAuthor reviewed this catalog. Review decisions (data): ${jsonEncode(reviewNotes)}\nDo not restore deleted or replaced objects. This is the final level generation stage.';
  }

  Future<String> request(String text) async {
    if (!mounted) throw const LevelValidationException('Cancelled.');
    final token = operation;
    final config = AiProviderConfig(
      baseUrl: base.text.trim(),
      model: model.text.trim(),
      name: name.text,
      key: key.text,
      timeoutSeconds: timeout,
    );
    config.endpoint();
    await widget.store.updateSettings(
      providerSettings: {
        'baseUrl': config.baseUrl,
        'model': config.model,
        'name': config.name,
        'timeout': timeout,
      },
    );
    if (!mounted || token != operation) {
      throw const LevelValidationException('Cancelled.');
    }
    setState(() => requesting = true);
    try {
      final response = await provider.generate(config, text);
      if (!mounted || token != operation) {
        throw const LevelValidationException('Cancelled.');
      }
      return response;
    } finally {
      if (mounted && token == operation) setState(() => requesting = false);
    }
  }

  Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      setState(
        () => message = tr(
          'Zkopírováno. Vlož do chatu a vrať sem celou odpověď JSON.',
          'Copied. Paste into chat and return the complete JSON response here.',
        ),
      );
    }
  }

  Future<void> validateProposal() async {
    final catalog = await FeatureCatalog.load();
    final items = resolveCatalogProposal(
      catalog,
      extractJsonObject(proposal.text),
    );
    final result = <CatalogFeature>[];
    final notes = <String>[];
    for (final item in items) {
      if (!mounted) return;
      List<CatalogFeature> chosen = item.matches;
      if (!item.resolved) {
        final repair = await repairCatalogItem(
          context,
          catalog: catalog,
          invalid: item.query,
          alternativeText: item.query,
          reason:
              '${item.userText}\n${item.matches.isEmpty ? tr('Nenalezeno. Vyber náhradu nebo smaž.', 'Not found. Replace or delete.') : tr('Více shod (${item.matches.length}). Vyber konkrétní položku nebo smaž.', 'Multiple matches (${item.matches.length}). Choose an item or delete.')}',
          czech: widget.store.language == 'cs',
          exclude: result.map((f) => f.id).toSet(),
        );
        if (!mounted || repair == null) return;
        chosen = repair.replacement == null ? [] : [repair.replacement!];
        notes.add(
          '${item.userText} → ${chosen.isEmpty ? 'deleted' : chosen.single.name}',
        );
      }
      for (final f in chosen) {
        if (!result.any((v) => v.id == f.id)) result.add(f);
      }
      if (item.resolved) {
        notes.add('${item.userText} → ${chosen.map((f) => f.name).join(', ')}');
      }
      if (result.length > 100) {
        throw const LevelValidationException(
          'Catalog exceeds 100 items. Narrow the proposal or split it into levels.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      selected = result;
      reviewNotes = notes;
      proposalSummary =
          LevelCodec().parse(extractJsonObject(proposal.text))['userText']
              as String;
      finalJson.clear();
      step = 3;
    });
  }

  Future<void> chooseCatalog() async {
    final result = await showCatalogPicker(
      context,
      land: widget.land,
      czech: widget.store.language == 'cs',
      selected: selected,
    );
    if (mounted && result != null) {
      setState(() {
        selected = result;
        finalJson.clear();
        reviewNotes.add(
          'Author manually reviewed the catalog; only the current selection is approved.',
        );
      });
    }
  }

  Future<void> openFinal() async {
    final level = await decodeAuthoringWithRepair(
      context,
      extractJsonObject(finalJson.text),
      czech: widget.store.language == 'cs',
      requireCatalogText: true,
      requiredIds: selected.map((f) => f.id).toSet(),
    );
    if (!mounted || level == null) return;
    final reviewed = LevelCodec().fromJson({
      ...level.toJson(),
      'unverified': true,
    });
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LevelEditor(
          store: widget.store,
          land: widget.land,
          level: reviewed,
        ),
      ),
    );
  }

  Widget button(String cs, String en, Future<void> Function() action) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FilledButton(
          onPressed: busy ? null : () => run(action),
          child: Text(tr(cs, en)),
        ),
      );

  List<Widget> connection() => [
    OutlinedButton.icon(
      onPressed: busy
          ? null
          : () async {
              final preset = await Navigator.push<AiConnectionPreset>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AiConnectionGuide(czech: widget.store.language == 'cs'),
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
      readOnly: busy,
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
        onChanged: busy ? null : (v) => setState(() => timeout = v!),
      ),
    ),
    TextField(
      controller: base,
      readOnly: busy,
      decoration: const InputDecoration(labelText: 'Base URL'),
    ),
    TextField(
      controller: model,
      readOnly: busy,
      decoration: const InputDecoration(labelText: 'Model'),
    ),
    TextField(
      controller: key,
      readOnly: busy,
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
    button('Test spojení', 'Test connection', () async {
      await request('Reply with OK.');
      if (mounted) {
        setState(
          () => message = tr('Spojení funguje.', 'Connection succeeded.'),
        );
      }
    }),
  ];

  List<Widget> currentStep() {
    switch (step) {
      case 0:
        return [
          Text(
            tr(
              'Jak chceš vytvořit úroveň?',
              'How would you like to create a level?',
            ),
          ),
          button('Pomocí API', 'Use API', () async {
            api = true;
            go(1);
          }),
          button('Ručně přes chat', 'Manual chat', () async {
            api = false;
            go(1);
          }),
          Text(
            tr(
              'Nejprve společný návrh katalogu, potom kontrola v aplikaci a až nakonec finální JSON úrovně.',
              'First a complete catalog proposal, then review in the app, and finally the level JSON.',
            ),
          ),
        ];
      case 1:
        return [
          TextField(
            controller: concepts,
            readOnly: busy,
            maxLines: 5,
            maxLength: 12000,
            decoration: InputDecoration(
              labelText: tr(
                'Seznam míst a zadání úrovně',
                'List of places and level instructions',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          DropdownButton<String>(
            value: contentLanguage,
            items: const [
              DropdownMenuItem(value: 'cs', child: Text('Čeština')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() => contentLanguage = v!),
          ),
          if (api) ...connection(),
          button(
            'Pokračovat k návrhu katalogu',
            'Continue to catalog proposal',
            () async {
              if (concepts.text.trim().isEmpty) {
                throw LevelValidationException(
                  tr(
                    'Zadej seznam míst nebo téma.',
                    'Enter places or a topic.',
                  ),
                );
              }
              if (api) {
                AiProviderConfig(
                  baseUrl: base.text.trim(),
                  model: model.text.trim(),
                ).endpoint();
              }
              final nextRequest = jsonEncode([concepts.text, contentLanguage]);
              if (preparedRequest != nextRequest) {
                preparedRequest = nextRequest;
                proposal.clear();
                finalJson.clear();
                selected = [];
                reviewNotes = [];
                proposalSummary = '';
              }
              go(2);
            },
          ),
        ];
      case 2:
        return [
          Text(
            tr(
              'AI připraví všechny položky najednou. Aplikace celý návrh ověří; pouze chybějící nebo nejednoznačná místa budeš opravovat.',
              'AI proposes all items at once. The app checks the entire proposal; only missing or ambiguous places need your decision.',
            ),
          ),
          if (api)
            button(
              'Vygenerovat celý návrh přes API',
              'Generate complete proposal via API',
              () async {
                final response = await request(await proposalPrompt());
                if (!mounted) return;
                proposal.text = extractJsonObject(response);
                await validateProposal();
              },
            )
          else
            button(
              'Kopírovat zadání a návod pro chat',
              'Copy request and instructions for chat',
              () async => copy(await proposalPrompt()),
            ),
          TextField(
            controller: proposal,
            readOnly: busy,
            minLines: 5,
            maxLines: 10,
            maxLength: 65536,
            decoration: InputDecoration(
              labelText: tr(
                'Celý návrh katalogu od AI (JSON)',
                'Complete AI catalog proposal (JSON)',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          button(
            'Ověřit celý katalog',
            'Validate complete catalog',
            validateProposal,
          ),
        ];
      case 3:
        return [
          if (proposalSummary.isNotEmpty) Text(proposalSummary),
          Text(
            tr(
              'Zkontroluj katalog (${selected.length} položek). Shody jsou z místních mapových dat. Ověř, že odpovídají tvému zadání.',
              'Review catalog (${selected.length} items). Matches come from local map data. Check that they match your request.',
            ),
          ),
          if (selected.isEmpty)
            Text(
              tr(
                'Katalog je prázdný. Vrať se a oprav návrh, nebo pokračuj pouze pro ručně kontrolované oblasti a pohoří.',
                'Catalog is empty. Go back to repair the proposal, or continue only for manually reviewed regions and mountains.',
              ),
            ),
          for (final f in selected)
            ListTile(
              title: Text(f.name),
              subtitle: Text('${f.kind} · ${f.region}\n${f.id}'),
            ),
          for (final note in reviewNotes) Text(note),
          button(
            'Zkontrolovat nebo upravit na mapě',
            'Review or edit on map',
            chooseCatalog,
          ),
          button(
            'Potvrdit katalog a pokračovat',
            'Confirm catalog and continue',
            () async {
              finalJson.clear();
              go(4);
            },
          ),
        ];
      default:
        return [
          Text(
            tr(
              'Potvrzený katalog obsahuje ${selected.length} položek. AI nyní dostane celý opravený katalog a návod pro finální úroveň.',
              'The approved catalog contains ${selected.length} items. AI now receives the entire corrected catalog and final level instructions.',
            ),
          ),
          if (api)
            button(
              'Vygenerovat finální úroveň přes API',
              'Generate final level via API',
              () async {
                final response = await request(await prompt());
                if (!mounted) return;
                finalJson.text = extractJsonObject(response);
                await openFinal();
              },
            )
          else
            button(
              'Kopírovat potvrzený katalog a finální prompt',
              'Copy approved catalog and final prompt',
              () async => copy(await prompt()),
            ),
          TextField(
            controller: finalJson,
            readOnly: busy,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: tr(
                'Finální JSON úrovně od AI',
                'Final level JSON from AI',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          button(
            'Ověřit úroveň a otevřít editor',
            'Validate level and open editor',
            openFinal,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      tr('Způsob', 'Method'),
      tr('Zadání', 'Request'),
      tr('Návrh katalogu', 'Catalog proposal'),
      tr('Revize', 'Review'),
      tr('Finální úroveň', 'Final level'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tvorba úrovně s AI', 'AI level wizard'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            key: ValueKey(step),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                labels[step],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ...currentStep(),
              if (busy) LinearProgressIndicator(value: requesting ? null : 0.5),
              if (requesting)
                TextButton(
                  onPressed: () {
                    operation++;
                    provider.cancel();
                    setState(() {
                      busy = false;
                      requesting = false;
                      message = tr('Požadavek zrušen.', 'Request cancelled.');
                    });
                  },
                  child: Text(tr('Zrušit požadavek', 'Cancel request')),
                ),
              if (message != null) SelectableText(message!),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(
                  'Krok ${step + 1} z 5 · ${labels[step]}',
                  'Step ${step + 1} of 5 · ${labels[step]}',
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Semantics(
                        label: labels[i],
                        selected: i == step,
                        child: Icon(
                          i < step
                              ? Icons.check_circle
                              : i == step
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              if (step > 0)
                TextButton(
                  onPressed: busy ? null : () => go(step - 1),
                  child: Text(tr('Zpět', 'Back')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
