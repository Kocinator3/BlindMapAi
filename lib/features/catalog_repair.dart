import 'package:flutter/material.dart';

import '../data/catalog_text.dart';
import '../data/feature_catalog.dart';
import '../domain/level.dart';
import '../map/map_canvas.dart';
import 'catalog_picker.dart';

class CatalogRepair {
  final CatalogFeature? replacement;
  const CatalogRepair.replace(this.replacement);
  const CatalogRepair.delete() : replacement = null;
}

Future<CatalogRepair?> repairCatalogItem(
  BuildContext context, {
  required FeatureCatalog catalog,
  required String invalid,
  required String reason,
  String alternativeText = '',
  required bool czech,
  Set<String> exclude = const {},
}) => showDialog<CatalogRepair>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _RepairDialog(
    catalog: catalog,
    invalid: invalid,
    reason: reason,
    alternativeText: alternativeText,
    czech: czech,
    exclude: exclude,
  ),
);

class _RepairDialog extends StatefulWidget {
  final FeatureCatalog catalog;
  final String invalid, reason, alternativeText;
  final bool czech;
  final Set<String> exclude;
  const _RepairDialog({
    required this.catalog,
    required this.invalid,
    required this.reason,
    required this.alternativeText,
    required this.czech,
    required this.exclude,
  });
  @override
  State<_RepairDialog> createState() => _RepairDialogState();
}

class _RepairDialogState extends State<_RepairDialog> {
  late final input = TextEditingController(
    text:
        (widget.alternativeText.isNotEmpty
                ? widget.alternativeText
                : widget.invalid)
            .substring(
              0,
              (widget.alternativeText.isNotEmpty
                      ? widget.alternativeText
                      : widget.invalid)
                  .length
                  .clamp(0, 120),
            ),
  );
  late List<CatalogFeature> suggestions = suggestCatalog(
    widget.catalog,
    input.text,
    exclude: widget.exclude,
  );
  String? error;
  bool opening = false;
  String tr(String cs, String en) => widget.czech ? cs : en;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void choose(CatalogFeature feature) =>
      Navigator.pop(context, CatalogRepair.replace(feature));
  Future<void> manual() async {
    setState(() => opening = true);
    try {
      final land = await MapCanvas.loadLand();
      if (!mounted) return;
      final result = await showCatalogPicker(
        context,
        land: land,
        czech: widget.czech,
        limit: 1,
      );
      if (!mounted || result == null || result.isEmpty) return;
      if (widget.exclude.contains(result.single.id)) {
        setState(
          () => error = tr(
            'Tato položka už je ve výběru.',
            'This item is already selected.',
          ),
        );
      } else {
        choose(result.single);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exact = widget.catalog.byId[input.text.trim()];
    return AlertDialog(
      title: Text(tr('Neplatná položka katalogu', 'Invalid catalog item')),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .55,
        child: ListView(
          children: [
            Text(widget.invalid, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (widget.alternativeText.isNotEmpty)
              Text(
                widget.alternativeText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            Text(widget.reason, maxLines: 3, overflow: TextOverflow.ellipsis),
            Text(
              tr(
                'Vyber náhradu, oprav ID nebo položku smaž. Podobnost není ověření. U otázky se náhradou obnoví její text a vysvětlení.',
                'Choose a replacement, correct the ID or delete the item. Similarity is not verification. Replacing a question resets its prompt and explanation.',
              ),
            ),
            TextField(
              controller: input,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: tr(
                  'Opravit ID nebo hledat název',
                  'Correct ID or search name',
                ),
              ),
              onChanged: (v) => setState(
                () => suggestions = suggestCatalog(
                  widget.catalog,
                  v,
                  exclude: widget.exclude,
                ),
              ),
            ),
            ...[
              for (final f in suggestions)
                ListTile(
                  title: Text(f.name),
                  subtitle: Text(
                    '${f.kind} · ${f.region.isEmpty ? f.map.center.toJson() : f.region}\n${f.id}${f.identifiers.containsKey('wikidata') ? ' · Wikidata ${f.identifiers['wikidata']}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: opening ? null : () => choose(f),
                ),
              if (suggestions.isEmpty)
                Text(
                  tr(
                    'Žádné návrhy. Zadej název nebo otevři katalog.',
                    'No suggestions. Enter a name or open the catalog.',
                  ),
                ),
            ],
            if (error != null) Text(error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: opening ? null : () => Navigator.pop(context),
          child: Text(tr('Zrušit', 'Cancel')),
        ),
        TextButton(
          onPressed: opening
              ? null
              : () => Navigator.pop(context, const CatalogRepair.delete()),
          child: Text(tr('Smazat položku', 'Delete item')),
        ),
        TextButton(
          onPressed: opening ? null : manual,
          child: Text(
            tr('Vybrat ručně z katalogu', 'Choose manually from catalog'),
          ),
        ),
        FilledButton(
          onPressed:
              !opening && exact != null && !widget.exclude.contains(exact.id)
              ? () => choose(exact)
              : null,
          child: Text(tr('Použít zadané ID', 'Use entered ID')),
        ),
      ],
    );
  }
}

/// Corrections are transactional: cancel leaves the caller's draft untouched.
Future<Level?> decodeAuthoringWithRepair(
  BuildContext context,
  String source, {
  required bool czech,
  Set<String>? requiredIds,
  bool requireCatalogText = false,
}) async {
  final codec = LevelCodec();
  final json = codec.parse(source);
  final raw = json['questions'];
  if (raw is! List || !raw.any((q) => q is Map && q.containsKey('catalogId'))) {
    return LevelCodec(requiredCatalogIds: requiredIds).fromJson(json);
  }
  if (raw.length > LevelCodec.maxQuestions) {
    codec.fail('questions', 'Expected at most 100 questions.');
  }
  final catalog = await FeatureCatalog.load();
  final questions = <dynamic>[];
  final used = <String>{};
  var changed = false;
  for (final original in raw) {
    if (original is! Map<String, dynamic> ||
        !original.containsKey('catalogId')) {
      questions.add(original);
      continue;
    }
    var q = Map<String, dynamic>.of(original);
    final id = q['catalogId'];
    if (id is! String || !catalog.byId.containsKey(id) || used.contains(id)) {
      if (!context.mounted) return null;
      final repair = await repairCatalogItem(
        context,
        catalog: catalog,
        invalid: '$id',
        alternativeText: q['catalogText'] is String
            ? q['catalogText'] as String
            : q['prompt'] is String
            ? q['prompt'] as String
            : '',
        reason: used.contains(id)
            ? (czech ? 'Duplicitní položka.' : 'Duplicate item.')
            : (czech
                  ? 'ID v katalogu neexistuje.'
                  : 'ID does not exist in the catalog.'),
        czech: czech,
        exclude: used,
      );
      if (repair == null) return null;
      changed = true;
      if (repair.replacement == null) continue;
      final f = repair.replacement!;
      final replacement = f.question(czech: json['language'] != 'en');
      q = {
        ...q,
        'catalogId': f.id,
        'catalogText': '${f.name} · ${f.kind} · ${f.region}',
        'prompt': replacement.prompt,
        'explanation': replacement.explanation,
        'hints': <String>[],
      };
    }
    used.add(q['catalogId'] as String);
    questions.add(q);
  }
  if (questions.isEmpty) {
    codec.fail(
      'questions',
      czech
          ? 'Po smazání nezůstala žádná otázka. Importuj alespoň jednu platnou položku.'
          : 'Deletion left no questions. Import at least one valid item.',
    );
  }
  // Explicit human corrections supersede the original AI selection contract.
  return LevelCodec(
    catalog: catalog.questions(czech: json['language'] != 'en'),
    requiredCatalogIds: changed ? null : requiredIds,
    requireCatalogText: requireCatalogText,
  ).fromJson({...json, 'questions': questions});
}
