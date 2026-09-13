import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../domain/geo.dart';
import '../domain/level.dart';
import '../domain/scoring.dart';
import '../map/map_canvas.dart';

enum GameMode { practice, learning, challenge }

class GameplayPage extends StatefulWidget {
  final Level level;
  final AppStore store;
  final List<List<GeoPoint>> land;
  final GameMode mode;
  final bool preview;
  const GameplayPage({
    super.key,
    required this.level,
    required this.store,
    required this.land,
    this.mode = GameMode.learning,
    this.preview = false,
  });
  @override
  State<GameplayPage> createState() => _GameplayPageState();
}

class _GameplayPageState extends State<GameplayPage> {
  int index = 0, total = 0, combo = 0, remaining = 90;
  List<GeoPoint> points = [];
  ScoreResult? result;
  bool busy = false, done = false;
  String? error;
  late final String session = DateTime.now().microsecondsSinceEpoch.toString();
  Timer? timer;
  String tr(String cs, String en) => widget.store.language == 'cs' ? cs : en;
  Question get question => widget.level.questions[index];
  bool get touchPlatform =>
      Theme.of(context).platform == TargetPlatform.android ||
      Theme.of(context).platform == TargetPlatform.iOS;
  String get interactionHint => switch (question.answerType) {
    AnswerType.point => tr(
      'Klikni do mapy a označ místo. Tažením mapu posuneš.',
      'Click the map to mark a place. Drag to pan.',
    ),
    AnswerType.polyline =>
      touchPlatform
          ? tr(
              'Nakresli linii jedním prstem. Dvěma prsty mapu posuneš a přiblížíš.',
              'Trace the line with one finger. Use two fingers to pan and zoom.',
            )
          : tr(
              'Klikáním přidej vrcholy linie. Tažením mapu posuneš.',
              'Click to add line vertices. Drag to pan.',
            ),
    AnswerType.polygon || AnswerType.freehandArea || AnswerType.circle =>
      touchPlatform
          ? tr(
              'Zakresli oblast jedním prstem. Dvěma prsty mapu posuneš a přiblížíš.',
              'Draw the area with one finger. Use two fingers to pan and zoom.',
            )
          : tr(
              'Zakresli oblast tažením po mapě. Space + tažení mapu posune.',
              'Draw the area by dragging. Space + drag pans the map.',
            ),
    AnswerType.multiPoint => tr(
      'Kliknutím označ všechna místa. Tažením mapu posuneš.',
      'Click to mark all places. Drag to pan.',
    ),
  };
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.mode == GameMode.challenge &&
          !done &&
          result == null &&
          !busy) {
        if (remaining > 0) {
          setState(() => remaining--);
        } else {
          submit(timedOut: true);
        }
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> submit({bool timedOut = false}) async {
    if (busy || result != null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final area = ![
        AnswerType.point,
        AnswerType.polyline,
        AnswerType.multiPoint,
      ].contains(question.answerType);
      final geometry = Geometry(question.geometry.type, [
        area ? closeRing(points) : points,
      ]);
      if (!timedOut) {
        final value = question.toJson();
        value['geometry'] = geometry.toJson();
        LevelCodec().fromJson({
          ...widget.level.toJson(),
          'questions': [value],
        });
      }
      final scored = timedOut
          ? const ScoreResult(0)
          : scoreAnswer(question, geometry);
      if (!widget.preview) {
        await widget.store.record(
          session: session,
          level: widget.level,
          question: question,
          points: scored.points,
        );
      }
      if (mounted) {
        setState(() {
          result = scored;
          total += scored.points;
          combo = scored.points >= 700 ? combo + 1 : 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Výsledky', 'Results'))),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 80),
                  Text(
                    '$total / ${widget.level.questions.length * 1000}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Text(
                    total >= widget.level.questions.length * 850
                        ? '★★★'
                        : total >= widget.level.questions.length * 600
                        ? '★★'
                        : '★',
                    style: const TextStyle(fontSize: 40),
                  ),
                  Text(
                    tr(
                      'Každý pokus se počítá. Prohlédni si chyby a zkus to znovu.',
                      'Every attempt counts. Review your mistakes and try again.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('Zpět na úvod', 'Back home')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.preview
              ? tr('Náhled otázky', 'Question preview')
              : widget.level.title,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('$total XP: ${widget.store.xp}'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value:
                    (index + (result == null ? 0 : 1)) /
                    widget.level.questions.length,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '${index + 1} / ${widget.level.questions.length} · ${question.answerType.name}',
                    ),
                    if (widget.mode == GameMode.challenge)
                      Text('⏱ $remaining s · Combo $combo'),
                  ],
                ),
              ),
              Text(
                question.prompt,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  interactionHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (result == null && question.hints.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        content: Text(question.hints.join('\n')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                    child: Text(tr('Nápověda', 'Hint')),
                  ),
                ),
              Expanded(
                child: MapCanvas(
                  key: ValueKey(index),
                  land: widget.land,
                  config: widget.level.map,
                  type: question.answerType,
                  points: points,
                  czech: widget.store.language == 'cs',
                  onChanged: (p) => setState(() => points = p),
                  target: result == null ? null : question.geometry,
                  readOnly: result != null,
                  showTools: question.answerType != AnswerType.point,
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (result != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result!.points} / 1000${result!.distance == null ? '' : ' · ${result!.distance!.toStringAsFixed(1)} km'}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        tr(
                          '● Modrá: tvůj pokus   ■ Oranžová: správná odpověď',
                          '● Blue: your attempt   ■ Orange: reference',
                        ),
                      ),
                      if (question.explanation.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 90),
                          child: SingleChildScrollView(
                            child: Text(question.explanation),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : result == null
                    ? (points.isEmpty ? null : submit)
                    : () {
                        setState(() {
                          if (index == widget.level.questions.length - 1) {
                            done = true;
                          } else {
                            index++;
                            points = [];
                            result = null;
                            remaining = 90;
                            error = null;
                          }
                        });
                      },
                icon: Icon(result == null ? Icons.check : Icons.arrow_forward),
                label: Text(
                  busy
                      ? tr('Ukládání…', 'Saving…')
                      : result == null
                      ? tr('Potvrdit odpověď', 'Confirm answer')
                      : tr('Pokračovat', 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
