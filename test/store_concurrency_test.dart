import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';

// Hold one write open, then fail it. Subsequent saves succeed and capture the
// payload that a real persistence backend would receive.
class FailingFirstStore extends AppStore {
  FailingFirstStore({super.directory});
  final started = Completer<void>();
  final release = Completer<void>();
  int writes = 0;
  Map<String, dynamic>? persisted;
  @override
  Future<void> save() async {
    if (writes++ == 0) {
      started.complete();
      await release.future;
      throw StateError('Simulated storage failure');
    }
    await super.save();
    persisted = snapshot();
  }
}

Level level(String id) => Level(
  id: id,
  title: id,
  questions: [
    Question(
      id: 'same-question-id',
      prompt: 'Place',
      answerType: AnswerType.point,
      geometry: Geometry('Point', [
        [const GeoPoint(15, 50)],
      ]),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('queued success after failure survives disk reload', () async {
    final directory = await Directory.systemTemp.createTemp(
      'slepamapa-concurrency-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FailingFirstStore(directory: directory);
    final first = store.put(level('failed'));
    final failed = expectLater(first, throwsStateError);
    await store.started.future;
    final second = store.put(level('survives'));
    store.release.complete();
    await failed;
    await second;
    final restored = AppStore(directory: directory);
    await restored.load();
    expect(restored.custom.map((l) => l.id), ['survives']);
    expect(restored.warning, isNull);
  });
  test('failed put cannot roll back a queued successful put', () async {
    final store = FailingFirstStore();
    final first = store.put(level('first'));
    final failed = expectLater(first, throwsStateError);
    await store.started.future;
    final second = store.put(level('second'));
    store.release.complete();
    await failed;
    await second;
    expect(store.custom.map((l) => l.id), ['second']);
    expect((store.persisted!['levels'] as List).map((l) => l['id']), [
      'second',
    ]);
  });

  test(
    'failed delete cannot resurrect a subsequent successful delete',
    () async {
      final store = FailingFirstStore();
      final firstLevel = level('first'), secondLevel = level('second');
      store.custom.addAll([firstLevel, secondLevel]);
      final first = store.delete(firstLevel);
      final failed = expectLater(first, throwsStateError);
      await store.started.future;
      final second = store.delete(secondLevel);
      store.release.complete();
      await failed;
      await second;
      expect(store.custom.map((l) => l.id), ['first']);
    },
  );

  test('duplicate record waits for failed write and can retry', () async {
    final store = FailingFirstStore();
    final pack = level('pack');
    Future<void> record() => store.record(
      session: 'session',
      level: pack,
      question: pack.questions.first,
      points: 800,
    );
    final first = record();
    final failed = expectLater(first, throwsStateError);
    await store.started.future;
    final retry = record();
    store.release.complete();
    await failed;
    await retry;
    expect(store.history, hasLength(1));
    expect(store.history.single['points'], 800);
  });

  test(
    'record identity includes level as well as session and question',
    () async {
      final store = AppStore();
      for (final pack in [level('a'), level('b')]) {
        await store.record(
          session: 's',
          level: pack,
          question: pack.questions.first,
          points: 700,
        );
      }
      expect(store.history, hasLength(2));
    },
  );
}
