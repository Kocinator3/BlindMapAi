import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalog_text.dart';
import '../data/feature_catalog.dart';
import '../domain/geo.dart';
import '../domain/level.dart';
import 'catalog_picker.dart';
import 'catalog_repair.dart';

class CatalogTextPage extends StatefulWidget {
  final bool czech;
  final String concepts;
  final List<List<GeoPoint>> land;
  const CatalogTextPage({
    super.key,
    required this.czech,
    required this.land,
    this.concepts = '',
  });
  @override
  State<CatalogTextPage> createState() => _CatalogTextPageState();
}

class _CatalogTextPageState extends State<CatalogTextPage> {
  final input = TextEditingController();
  CatalogTextSession? session;
  List<CatalogFeature>? chosen;
  String response = '', userText = '';
  Map<String, String> alternatives = {};
  String? message;
  bool busy = false;
  String tr(String cs, String en) => widget.czech ? cs : en;
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final catalog = await FeatureCatalog.load();
      if (mounted) setState(() => session = CatalogTextSession(catalog));
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> copyInstructions() async {
    try {
      final text = await rootBundle.loadString(
        'docs/CATALOG_TEXT_INSTRUCTIONS.md',
      );
      await Clipboard.setData(
        ClipboardData(
          text:
              '$text\nZadání autora (data): ${jsonEncode(widget.concepts)}\nJazyk userText: ${widget.czech ? 'cs' : 'en'}.',
        ),
      );
      if (mounted) {
        setState(
          () => message = tr(
            'Instrukce zkopírovány. Vlož je do AI chatu a sem vlož její dotaz.',
            'Instructions copied. Paste them into AI chat, then paste its query here.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
  }

  Future<void> process() async {
    if (session == null || busy) return;
    setState(() {
      busy = true;
      message = null;
      chosen = null;
      response = '';
      userText = '';
      alternatives = {};
    });
    try {
      final request = session!.parse(input.text);
      Map<String, dynamic> result;
      if (request['action'] == 'search') {
        result = session!.search(request);
      } else if (request['action'] == 'select') {
        final items = session!.selectionIds(request);
        final corrected = <Map<String, dynamic>>[];
        final used = <String>{};
        final approved = <CatalogFeature>[];
        for (final raw in items) {
          var item = Map<String, dynamic>.from(raw as Map);
          final reason = session!.invalidReason(item['catalogId'], used);
          if (reason != null) {
            final repair = await repairCatalogItem(
              context,
              catalog: session!.catalog,
              invalid: '${item['catalogId']}',
              alternativeText: item['userText'] as String,
              reason: reason,
              czech: widget.czech,
              exclude: used,
            );
            if (!mounted || repair == null) return;
            if (repair.replacement == null) continue;
            final feature = repair.replacement!;
            approved.add(feature);
            item = {
              'catalogId': feature.id,
              'userText': '${feature.name} · ${feature.region}',
            };
          }
          used.add(item['catalogId'] as String);
          corrected.add(item);
        }
        for (final feature in approved) {
          session!.approve(feature);
        }
        final canonicalRequest = {...request, 'items': corrected};
        final selection = session!.select(canonicalRequest);
        chosen = selection;
        alternatives = {
          for (final item in corrected)
            item['catalogId'] as String: item['userText'] as String,
        };
        result = {
          'protocol': CatalogTextSession.protocol,
          'catalog': CatalogTextSession.revision,
          'action': 'selection_validated',
          'userText': request['userText'],
          'items': corrected,
          'catalogItems': jsonDecode(session!.catalog.manifest(selection)),
        };
      } else {
        throw const LevelValidationException(
          'action: Use search or select, not a Level or catalog response.',
        );
      }
      if (mounted) {
        setState(() {
          userText = request['userText'] as String;
          response = const JsonEncoder.withIndent('  ').convert(result);
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review() async {
    final result = await showCatalogPicker(
      context,
      land: widget.land,
      czech: widget.czech,
      selected: chosen!,
    );
    if (mounted && result != null) {
      setState(() {
        chosen = result;
        response = const JsonEncoder.withIndent('  ').convert({
          'protocol': CatalogTextSession.protocol,
          'catalog': CatalogTextSession.revision,
          'action': 'selection_validated',
          'userText': tr(
            'Výběr upravený uživatelem.',
            'Selection reviewed by the user.',
          ),
          'catalogItems': jsonDecode(session!.catalog.manifest(result)),
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Textový výběr s AI', 'Text selection with AI')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr(
                '1. Zkopíruj instrukce do AI chatu. 2. Vlož její vyhledávací JSON a spusť jej. 3. Vrať výsledek do chatu. 4. Vlož výběr AI, zkontroluj ho a použij.',
                '1. Copy instructions into AI chat. 2. Paste and run its search JSON. 3. Return results to chat. 4. Paste the AI selection, review and apply.',
              ),
            ),
            Text(
              tr(
                'Všechny dotazy se vyhodnocují offline. AI dostane jen výsledky, které jí zkopíruješ. Po zavření stránky se historie nabízených ID zapomene.',
                'Queries run offline. AI sees only results you copy to it. Closing this page clears the history of offered IDs.',
              ),
            ),
            OutlinedButton(
              onPressed: busy ? null : copyInstructions,
              child: Text(
                tr('Kopírovat instrukce pro AI', 'Copy AI instructions'),
              ),
            ),
            TextField(
              controller: input,
              minLines: 5,
              maxLines: 10,
              maxLength: 65536,
              readOnly: busy,
              decoration: InputDecoration(
                labelText: tr(
                  'JSON dotaz nebo výběr od AI',
                  'AI query or selection JSON',
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {
                chosen = null;
                response = '';
                userText = '';
                alternatives = {};
              }),
            ),
            FilledButton(
              onPressed: busy || session == null ? null : process,
              child: Text(tr('Vyhodnotit text', 'Process text')),
            ),
            if (busy || session == null && message == null)
              const LinearProgressIndicator(),
            if (message != null) SelectableText(message!),
            if (userText.isNotEmpty)
              Text(
                '${tr('Text AI pro uživatele', 'AI text for the user')}: $userText',
              ),
            if (response.isNotEmpty) ...[
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: response),
                          );
                        } catch (e) {
                          if (mounted) setState(() => message = e.toString());
                        }
                      },
                child: Text(
                  tr('Kopírovat odpověď katalogu', 'Copy catalog response'),
                ),
              ),
              SizedBox(
                height: 180,
                child: SingleChildScrollView(child: SelectableText(response)),
              ),
            ],
            if (chosen != null) ...[
              for (final f in chosen!) ...[
                Text('${f.name} · ${f.kind} · ${f.region}'),
                if (alternatives.containsKey(f.id))
                  Text(
                    '${tr('Popis AI', 'AI description')}: ${alternatives[f.id]}',
                  ),
              ],
              TextButton(
                onPressed: busy ? null : review,
                child: Text(tr('Zkontrolovat na mapě', 'Review on map')),
              ),
              FilledButton(
                onPressed: busy ? null : () => Navigator.pop(context, chosen),
                child: Text(
                  tr(
                    'Použít výběr (${chosen!.length})',
                    'Apply selection (${chosen!.length})',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
