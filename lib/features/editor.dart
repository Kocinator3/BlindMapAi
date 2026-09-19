import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../domain/geo.dart';
import '../domain/level.dart';
import '../map/map_canvas.dart';
import 'gameplay.dart';
import 'unsaved_guard.dart';

Future<Level?> showJsonEditor(
  BuildContext context,
  Level? level, {
  bool czech = true,
}) => Navigator.push<Level>(
  context,
  MaterialPageRoute(
    builder: (_) => _JsonPage(level: level, czech: czech),
  ),
);

class _JsonPage extends StatefulWidget {
  final Level? level;
  final bool czech;
  const _JsonPage({this.level, required this.czech});
  @override
  State<_JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends State<_JsonPage> {
  late final text = TextEditingController(text: widget.level?.encode() ?? '');
  bool applied = false;
  String? message;
  String tr(String cs, String en) => widget.czech ? cs : en;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedGuard(
    czech: widget.czech,
    dirty: () => !applied && text.text != (widget.level?.encode() ?? ''),
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('JSON • import a export', 'JSON • import and export')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => run(() async {
                    final level = LevelCodec().decode(text.text);
                    text.text = level.encode();
                    setState(
                      () => message = tr('JSON je platný.', 'JSON is valid.'),
                    );
                  }),
                  child: Text(tr('Formátovat a ověřit', 'Format and validate')),
                ),
                TextButton(
                  onPressed: () => run(() async {
                    await Clipboard.setData(ClipboardData(text: text.text));
                    setState(() => message = tr('Zkopírováno.', 'Copied.'));
                  }),
                  child: Text(tr('Kopírovat', 'Copy')),
                ),
                TextButton(
                  onPressed: () => run(() async {
                    final value = await Clipboard.getData(Clipboard.kTextPlain);
                    if (value != null && value.text != null) {
                      if (value.text!.length > LevelCodec.maxBytes) {
                        throw const LevelValidationException(
                          'Clipboard exceeds 2 MiB.',
                        );
                      }
                      text.text = value.text!;
                    }
                  }),
                  child: Text(tr('Vložit', 'Paste')),
                ),
                TextButton(
                  onPressed: () => run(() async {
                    final file = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: 'JSON',
                          extensions: ['json'],
                          mimeTypes: ['application/json'],
                        ),
                      ],
                    );
                    if (file != null) {
                      if (await file.length() > LevelCodec.maxBytes) {
                        throw const LevelValidationException(
                          'File exceeds 2 MiB.',
                        );
                      }
                      text.text = await file.readAsString();
                    }
                  }),
                  child: Text(tr('Otevřít soubor', 'Open file')),
                ),
                TextButton(
                  onPressed: () => run(() async {
                    final level = LevelCodec().decode(text.text);
                    if (Platform.isAndroid) {
                      final saved =
                          await const MethodChannel('org.slepamapa/files')
                              .invokeMethod<bool>('exportJson', {
                                'content': level.encode(),
                              });
                      if (mounted && saved == true) {
                        setState(
                          () => message = tr('Soubor uložen.', 'File saved.'),
                        );
                      }
                      return;
                    }
                    final location = await getSaveLocation(
                      suggestedName: 'level.json',
                    );
                    if (location != null) {
                      await XFile.fromData(
                        utf8.encode(level.encode()),
                        mimeType: 'application/json',
                        name: 'level.json',
                      ).saveTo(location.path);
                      setState(
                        () => message = tr('Soubor uložen.', 'File saved.'),
                      );
                    }
                  }),
                  child: Text(tr('Uložit soubor', 'Save file')),
                ),
              ],
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(message!),
              ),
            Expanded(
              child: TextField(
                controller: text,
                maxLines: null,
                expands: true,
                maxLength: LevelCodec.maxBytes,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: tr('JSON úrovně', 'Level JSON'),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => run(() async {
                final level = LevelCodec().decode(text.text);
                setState(() => applied = true);
                Navigator.pop(context, level);
              }),
              child: Text(tr('Ověřit a použít', 'Validate and apply')),
            ),
          ],
        ),
      ),
    ),
  );
}

class LevelEditor extends StatefulWidget {
  final AppStore store;
  final List<List<GeoPoint>> land;
  final Level? level;
  const LevelEditor({
    super.key,
    required this.store,
    required this.land,
    this.level,
  });
  @override
  State<LevelEditor> createState() => _LevelEditorState();
}

class _LevelEditorState extends State<LevelEditor> {
  late final title = TextEditingController(text: widget.level?.title ?? '');
  late final description = TextEditingController(
    text: widget.level?.description ?? '',
  );
  late String id =
      widget.level != null &&
          widget.store.custom.any((l) => l.id == widget.level!.id)
      ? widget.level!.id
      : 'level-${DateTime.now().microsecondsSinceEpoch}';
  late List<Question> questions = List.of(widget.level?.questions ?? []);
  late MapConfig map = widget.level?.map ?? const MapConfig();
  late String language = widget.level?.language ?? 'cs';
  late bool hardcore = widget.level?.hardcore ?? false;
  late double toleranceMultiplier = widget.level?.toleranceMultiplier ?? 1;
  late bool unverified = widget.level?.unverified ?? false;
  late String difficulty = widget.level?.difficulty ?? 'beginner';
  late List<String> tags = List.of(widget.level?.tags ?? const []);
  late final String initialDraft;
  @override
  void initState() {
    super.initState();
    initialDraft = value().encode();
  }

  bool saved = false;
  String? error;
  bool saving = false;
  String tr(String cs, String en) => widget.store.language == 'cs' ? cs : en;
  Level value() => Level(
    id: id,
    title: title.text,
    description: description.text,
    language: language,
    questions: questions,
    map: map,
    unverified: unverified,
    hardcore: hardcore,
    toleranceMultiplier: toleranceMultiplier,
    difficulty: difficulty,
    tags: tags,
  );
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> question([int? i]) async {
    final q = await Navigator.push<Question>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditor(
          store: widget.store,
          land: widget.land,
          map: map,
          question: i == null ? null : questions[i],
        ),
      ),
    );
    if (q != null && mounted) {
      setState(() {
        if (i == null) {
          questions.add(q);
        } else {
          questions[i] = q;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedGuard(
    czech: widget.store.language == 'cs',
    dirty: () =>
        !saved &&
        (value().encode() != initialDraft ||
            (widget.level != null &&
                !widget.store.custom.any(
                  (level) => level.encode() == initialDraft,
                ))),
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('Editor úrovně', 'Level editor')),
        actions: [
          TextButton(
            onPressed: () async {
              final level = await showJsonEditor(
                context,
                value(),
                czech: widget.store.language == 'cs',
              );
              if (level != null && mounted) {
                setState(() {
                  title.text = level.title;
                  description.text = level.description;
                  questions = List.of(level.questions);
                  map = level.map;
                  language = level.language;
                  unverified = level.unverified;
                  hardcore = level.hardcore;
                  toleranceMultiplier = level.toleranceMultiplier;
                  id = level.id;
                  difficulty = level.difficulty;
                  tags = List.of(level.tags);
                });
              }
            },
            child: const Text('JSON'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: tr('Název úrovně', 'Level title'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Popis', 'Description'),
                  border: const OutlineInputBorder(),
                ),
              ),
              ListTile(
                title: Text(tr('Jazyk obsahu', 'Content language')),
                trailing: DropdownButton<String>(
                  value: ['cs', 'en'].contains(language) ? language : 'cs',
                  items: const [
                    DropdownMenuItem(value: 'cs', child: Text('Čeština')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) => setState(() => language = v!),
                ),
              ),
              SwitchListTile(
                title: Text(
                  tr('Geografie čeká na ověření', 'Geography requires review'),
                ),
                value: unverified,
                onChanged: (v) => setState(() => unverified = v),
              ),
              ListTile(
                title: Text(tr('Výchozí mapa', 'Initial map')),
                trailing: DropdownButton<double>(
                  value: map.span == 55 ? 55 : 9,
                  items: [
                    DropdownMenuItem(
                      value: 9,
                      child: Text(tr('Česko', 'Czechia')),
                    ),
                    DropdownMenuItem(
                      value: 55,
                      child: Text(tr('Evropa', 'Europe')),
                    ),
                  ],
                  onChanged: (v) => setState(
                    () => map = MapConfig(
                      center: v == 55
                          ? const GeoPoint(12, 50)
                          : const GeoPoint(15.5, 49.8),
                      span: v!,
                      borders: map.borders,
                      rivers: map.rivers,
                      cities: map.cities,
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Hardcore mode'),
                subtitle: Text(
                  tr(
                    'Odpověď pod 700 / 1000 ukončí úroveň.',
                    'An answer below 700 / 1000 ends the level.',
                  ),
                ),
                value: hardcore,
                onChanged: (v) => setState(() => hardcore = v),
              ),
              Text(
                tr(
                  'Násobič tolerance: ${toleranceMultiplier.toStringAsFixed(2)}×',
                  'Tolerance multiplier: ${toleranceMultiplier.toStringAsFixed(2)}×',
                ),
              ),
              Text(
                tr(
                  'Pro body a řeky. Oblasti se hodnotí podle překryvu.',
                  'For points and rivers. Areas are scored by overlap.',
                ),
              ),
              Slider(
                value: toleranceMultiplier,
                min: 0.25,
                max: 4,
                divisions: 15,
                label: '${toleranceMultiplier.toStringAsFixed(2)}×',
                onChanged: (v) => setState(() => toleranceMultiplier = v),
              ),
              SwitchListTile(
                title: Text(tr('Řeky bez názvů', 'Unlabeled rivers')),
                value: map.rivers,
                onChanged: (v) => setState(
                  () => map = MapConfig(
                    center: map.center,
                    span: map.span,
                    borders: map.borders,
                    rivers: v,
                    cities: map.cities,
                  ),
                ),
              ),
              SwitchListTile(
                title: Text(tr('Města bez názvů', 'Unlabeled cities')),
                value: map.cities,
                onChanged: (v) => setState(
                  () => map = MapConfig(
                    center: map.center,
                    span: map.span,
                    borders: map.borders,
                    rivers: map.rivers,
                    cities: v,
                  ),
                ),
              ),
              const Divider(),
              for (var i = 0; i < questions.length; i++)
                Card(
                  child: ListTile(
                    title: Text(questions[i].prompt),
                    subtitle: Text(questions[i].answerType.name),
                    onTap: () => question(i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: tr('Kopie otázky', 'Duplicate question'),
                          icon: const Icon(Icons.copy),
                          onPressed: () => setState(() {
                            final json = questions[i].toJson();
                            json['id'] =
                                'q-${DateTime.now().microsecondsSinceEpoch}';
                            questions.add(
                              LevelCodec()
                                  .fromJson({
                                    ...value().toJson(),
                                    'questions': [json],
                                  })
                                  .questions
                                  .first,
                            );
                          }),
                        ),
                        IconButton(
                          tooltip: tr('Smazat otázku', 'Delete question'),
                          onPressed: () =>
                              setState(() => questions.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => question(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(tr('Přidat otázku', 'Add question')),
              ),
              if (error != null)
                SelectableText(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          await widget.store.put(
                            LevelCodec().decode(value().encode()),
                          );
                          if (context.mounted) {
                            setState(() => saved = true);
                            await WidgetsBinding.instance.endOfFrame;
                            if (context.mounted) Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) setState(() => error = e.toString());
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(tr('Uložit úroveň', 'Save level')),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final level = LevelCodec().decode(value().encode());
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => GameplayPage(
                          level: level,
                          store: widget.store,
                          land: widget.land,
                          preview: true,
                        ),
                      ),
                    );
                  } catch (e) {
                    setState(() => error = e.toString());
                  }
                },
                child: Text(tr('Náhled úrovně', 'Preview level')),
              ),
              if (widget.level != null)
                TextButton(
                  onPressed: () => setState(() {
                    id = 'level-${DateTime.now().microsecondsSinceEpoch}';
                    title.text = '${title.text} (${tr('kopie', 'copy')})';
                  }),
                  child: Text(tr('Uložit jako kopii', 'Save as duplicate')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class QuestionEditor extends StatefulWidget {
  final AppStore store;
  final List<List<GeoPoint>> land;
  final MapConfig map;
  final Question? question;
  const QuestionEditor({
    super.key,
    required this.store,
    required this.land,
    required this.map,
    this.question,
  });
  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  late final prompt = TextEditingController(
    text: widget.question?.prompt ?? '',
  );
  late final explanation = TextEditingController(
    text: widget.question?.explanation ?? '',
  );
  late final hints = TextEditingController(
    text: widget.question?.hints.join('\n') ?? '',
  );
  late final category = TextEditingController(
    text: widget.question?.category ?? 'geography',
  );
  late AnswerType type = widget.question?.answerType ?? AnswerType.point;
  late List<GeoPoint> points = _editablePoints();
  List<GeoPoint> _editablePoints() {
    final result = List<GeoPoint>.of(
      widget.question?.geometry.parts.first ?? [],
    );
    if (widget.question?.geometry.type == 'Polygon' &&
        result.length > 1 &&
        distanceKm(result.first, result.last) < 0.000001) {
      result.removeLast();
    }
    return result;
  }

  late final otherParts =
      widget.question?.geometry.parts
          .skip(1)
          .map((p) => List<GeoPoint>.of(p))
          .toList() ??
      <List<GeoPoint>>[];
  late double tolerance = widget.question?.toleranceKm ?? 30;
  bool applied = false;
  late final String initialDraft;
  String get draftSnapshot => jsonEncode([
    prompt.text,
    explanation.text,
    hints.text,
    category.text,
    type.name,
    points.map((p) => p.toJson()).toList(),
    otherParts.map((part) => part.map((p) => p.toJson()).toList()).toList(),
    tolerance,
  ]);
  @override
  void initState() {
    super.initState();
    initialDraft = draftSnapshot;
  }

  String? error;
  String tr(String cs, String en) => widget.store.language == 'cs' ? cs : en;
  @override
  void dispose() {
    prompt.dispose();
    explanation.dispose();
    hints.dispose();
    category.dispose();
    super.dispose();
  }

  Question value() {
    final isArea = ![
      AnswerType.point,
      AnswerType.polyline,
      AnswerType.multiPoint,
    ].contains(type);
    final q = Question(
      id: widget.question?.id ?? 'q-${DateTime.now().microsecondsSinceEpoch}',
      prompt: prompt.text,
      answerType: type,
      geometry: Geometry(
        switch (type) {
          AnswerType.point => 'Point',
          AnswerType.polyline =>
            otherParts.isEmpty ? 'LineString' : 'MultiLineString',
          AnswerType.multiPoint => 'MultiPoint',
          _ => 'Polygon',
        },
        [
          isArea ? closeRing(points) : points,
          if (type == AnswerType.polyline) ...otherParts,
        ],
      ),
      explanation: explanation.text,
      category: category.text,
      hints: hints.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
      toleranceKm: tolerance,
      difficulty: widget.question?.difficulty ?? 'beginner',
      tags: widget.question?.tags ?? const [],
    );
    return LevelCodec()
        .decode(Level(id: 'preview', title: 'Preview', questions: [q]).encode())
        .questions
        .first;
  }

  @override
  Widget build(BuildContext context) {
    final properties = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: prompt,
          decoration: InputDecoration(
            labelText: tr('Otázka', 'Prompt'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AnswerType>(
          initialValue: type,
          decoration: InputDecoration(
            labelText: tr('Typ odpovědi', 'Answer type'),
          ),
          items: [
            for (final t in AnswerType.values)
              DropdownMenuItem(value: t, child: Text(t.name)),
          ],
          onChanged: (v) => setState(() {
            type = v!;
            points = [];
            otherParts.clear();
          }),
        ),
        if (otherParts.isNotEmpty)
          Text(
            tr(
              'Vícedílná linie: upravuješ první část; ostatní části zůstanou zachovány. Pro úpravu dalších částí použij JSON.',
              'Multipart line: editing the first part; other parts are preserved. Use JSON to edit other parts.',
            ),
          ),
        TextField(
          controller: category,
          decoration: InputDecoration(labelText: tr('Kategorie', 'Category')),
        ),
        TextField(
          controller: explanation,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr('Vysvětlení', 'Explanation'),
          ),
        ),
        TextField(
          controller: hints,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: tr(
              'Nápovědy (jeden řádek = jedna)',
              'Hints (one per line)',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${tr('Tolerance', 'Tolerance')}: ${tolerance.toStringAsFixed(1)} km',
        ),
        Slider(
          value: tolerance.clamp(1, 300),
          min: 1,
          max: 300,
          onChanged: (v) => setState(() => tolerance = v),
        ),
        Text(
          tr(
            'Nakresli správnou odpověď. Body můžeš přesouvat nebo mazat nástroji nad mapou.',
            'Draw the reference answer. Move or delete vertices with the tools above the map.',
          ),
        ),
        if (error != null)
          SelectableText(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            try {
              final question = value();
              setState(() => applied = true);
              await WidgetsBinding.instance.endOfFrame;
              if (context.mounted) Navigator.pop(context, question);
            } catch (e) {
              setState(() => error = e.toString());
            }
          },
          child: Text(tr('Použít otázku', 'Apply question')),
        ),
        TextButton(
          onPressed: () {
            try {
              final q = value();
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GameplayPage(
                    level: Level(
                      id: 'preview',
                      title: tr('Náhled', 'Preview'),
                      questions: [q],
                      map: widget.map,
                    ),
                    store: widget.store,
                    land: widget.land,
                    preview: true,
                  ),
                ),
              );
            } catch (e) {
              setState(() => error = e.toString());
            }
          },
          child: Text(tr('Náhled otázky', 'Preview question')),
        ),
      ],
    );
    final map = MapCanvas(
      key: ValueKey(type),
      land: widget.land,
      config: widget.map,
      type: type,
      points: points,
      czech: widget.store.language == 'cs',
      onChanged: (p) => setState(() => points = p),
    );
    return UnsavedGuard(
      czech: widget.store.language == 'cs',
      dirty: () => !applied && draftSnapshot != initialDraft,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Editor otázky', 'Question editor'))),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 850
                ? Row(
                    children: [
                      SizedBox(width: 320, child: properties),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: map,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(height: c.maxHeight * 0.38, child: properties),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: map,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
