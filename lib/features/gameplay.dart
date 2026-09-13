import 'dart:async';
import 'dart:math' as math;

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

  Widget _questionSummary({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      LinearProgressIndicator(
        value:
            (index + (result == null ? 0 : 1)) / widget.level.questions.length,
      ),
      Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${index + 1} / ${widget.level.questions.length} · ${question.answerType.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.mode == GameMode.challenge)
              Text('⏱ $remaining s · Combo $combo'),
          ],
        ),
      ),
      Text(
        question.prompt,
        maxLines: compact ? 3 : null,
        overflow: compact ? TextOverflow.ellipsis : null,
        style: compact
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.titleLarge,
      ),
      Padding(
        padding: EdgeInsets.only(top: compact ? 2 : 4, bottom: compact ? 2 : 4),
        child: Text(
          interactionHint,
          maxLines: compact ? 4 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      if (result == null && question.hints.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
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
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(tr('Nápověda', 'Hint')),
          ),
        ),
    ],
  );

  Widget _map() => MapCanvas(
    key: ValueKey(index),
    land: widget.land,
    config: widget.level.map,
    type: question.answerType,
    points: points,
    czech: widget.store.language == 'cs',
    onChanged: (p) => setState(() => points = p),
    target: result == null ? null : question.geometry,
    readOnly: result != null,
    showTools: false,
  );

  Widget _resultPanel({bool compact = false}) {
    if (result == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
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
              constraints: BoxConstraints(maxHeight: compact ? 90 : 120),
              child: SingleChildScrollView(child: Text(question.explanation)),
            ),
        ],
      ),
    );
  }

  Widget _confirmButton({bool compact = false}) => SizedBox(
    height: compact ? 44 : 48,
    child: FilledButton.icon(
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
  );

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLandscape =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 600;
            if (compactLandscape) {
              final panelWidth = math.min(
                330.0,
                math.max(235.0, constraints.maxWidth * 0.34),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: panelWidth,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _questionSummary(compact: true),
                            if (error != null)
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            const SizedBox(height: 4),
                            _resultPanel(compact: true),
                            const SizedBox(height: 6),
                            _confirmButton(compact: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: _map(),
                    ),
                  ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _questionSummary(compact: constraints.maxWidth < 600),
                  Expanded(child: _map()),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (result != null) ...[
                    const SizedBox(height: 4),
                    _resultPanel(),
                  ],
                  const SizedBox(height: 4),
                  _confirmButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
