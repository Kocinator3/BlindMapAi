import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/level.dart';

class AppStore extends ChangeNotifier {
  final Directory? directory;
  AppStore({this.directory});
  final List<Level> bundled = [], custom = [];
  final List<Map<String, dynamic>> history = [];
  String language = 'cs';
  bool dark = false;
  String? warning;
  Map<String, dynamic> provider = {};
  Future<void> _pending = Future.value();
  Future<void> _mutations = Future.value();

  // Serialize the entire mutation, persistence and rollback boundary. Queuing
  // only filesystem writes allows an earlier rollback to erase a later edit.
  Future<void> _mutate(Future<void> Function() action) {
    final operation = _mutations
        .catchError((Object _) {})
        .then((_) => action());
    _mutations = operation;
    return operation;
  }

  List<Level> get levels => [...bundled, ...custom];
  int get xp => history.fold(0, (sum, r) => sum + (r['points'] as int) ~/ 10);
  int get playerLevel => 1 + xp ~/ 500;
  int best(String levelId) {
    final sessions = <String, int>{};
    for (final r in history.where((r) => r['level'] == levelId)) {
      final session = r['session'] as String;
      sessions[session] = (sessions[session] ?? 0) + (r['points'] as int);
    }
    return sessions.values.fold(0, (a, b) => a > b ? a : b);
  }

  int questionBest(String levelId, String questionId) => history
      .where((r) => r['level'] == levelId && r['question'] == questionId)
      .fold(0, (a, r) => a > (r['points'] as int) ? a : r['points'] as int);
  int get streak {
    final dates = history
        .map((r) => DateTime.parse(r['date'] as String).toLocal())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!dates.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (dates.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  List<(Level, Question)> get mistakes {
    final result = <(Level, Question)>[];
    for (final level in levels) {
      for (final q in level.questions) {
        final attempts = history
            .where((r) => r['level'] == level.id && r['question'] == q.id)
            .toList();
        if (attempts.isNotEmpty &&
            ((attempts.last['points'] as int) < 700 ||
                DateTime.parse(attempts.last['date'] as String)
                    .add(
                      Duration(
                        days: 1 + (attempts.last['points'] as int) ~/ 150,
                      ),
                    )
                    .isBefore(DateTime.now()))) {
          result.add((level, q));
        }
      }
    }
    double priority((Level, Question) item) {
      final attempts = history
          .where((r) => r['level'] == item.$1.id && r['question'] == item.$2.id)
          .toList();
      return attempts.fold(0.0, (sum, r) => sum + 1000 - (r['points'] as int)) /
          attempts.length;
    }

    result.sort((a, b) => priority(b).compareTo(priority(a)));
    return result;
  }

  Future<void> load() async {
    for (final id in [
      'czech-cities',
      'czech-rivers',
      'czech-mountains',
      'europe',
    ]) {
      bundled.add(
        LevelCodec().decode(
          await rootBundle.loadString('assets/levels/$id.json'),
        ),
      );
    }
    if (directory == null) return;
    final file = File('${directory!.path}/state.json'),
        backup = File('${directory!.path}/state.backup.json');
    if (!await file.exists() && !await backup.exists()) return;
    try {
      _restore(await file.readAsString());
    } catch (_) {
      try {
        _restore(await backup.readAsString());
        warning = 'Recovered the previous local save. The damaged file was preserved.';
      } catch (_) {
        warning = 'Local save is damaged. Files were preserved. Export or recover them before overwriting.';
      }
    }
  }

  void _restore(String source) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    if (value['version'] != 1) {
      throw const FormatException('Unsupported save version');
    }
    final loaded = [
      for (final l in value['levels'] as List)
        LevelCodec().fromJson(l as Map<String, dynamic>),
    ];
    final records = [
      for (final r in value['history'] as List)
        Map<String, dynamic>.from(r as Map),
    ];
    for (final r in records) {
      if (r['points'] is! int ||
          (r['points'] as int) < 0 ||
          (r['points'] as int) > 1000 ||
          r['session'] is! String ||
          r['level'] is! String ||
          r['question'] is! String) {
        throw const FormatException('Invalid result');
      }
      DateTime.parse(r['date'] as String);
    }
    final restoredProvider = Map<String, dynamic>.from(
      value['provider'] as Map? ?? {},
    );
    restoredProvider.removeWhere(
      (key, _) => !['baseUrl', 'model', 'name', 'timeout'].contains(key),
    );
    for (final key in ['baseUrl', 'model', 'name']) {
      if (restoredProvider[key] != null && restoredProvider[key] is! String) {
        throw const FormatException('Invalid provider settings');
      }
    }
    if (restoredProvider['timeout'] != null &&
        ![30, 60, 120, 180].contains(restoredProvider['timeout'])) {
      throw const FormatException('Invalid provider timeout');
    }
    custom
      ..clear()
      ..addAll(loaded);
    history
      ..clear()
      ..addAll(records);
    language = value['language'] == 'en' ? 'en' : 'cs';
    dark = value['dark'] == true;
    provider = restoredProvider;
  }

  Map<String, dynamic> snapshot() => {
    'version': 1,
    'levels': custom.map((l) => l.toJson()).toList(),
    'history': history,
    'language': language,
    'dark': dark,
    'provider': {
      for (final key in ['baseUrl', 'model', 'name', 'timeout'])
        if (provider.containsKey(key)) key: provider[key],
    },
  };
  Future<void> save() {
    final payload = jsonEncode(snapshot());
    final operation = _pending.catchError((Object _) {}).then((_) async {
      if (directory != null) {
        await directory!.create(recursive: true);
        final file = File('${directory!.path}/state.json'),
            temp = File('${directory!.path}/state.tmp.json'),
            backup = File('${directory!.path}/state.backup.json');
        await temp.writeAsString(payload, flush: true);
        if (await file.exists()) {
          // Preserve unreadable primary files separately before replacing them.
          try {
            AppStore()._restore(await file.readAsString());
            await file.copy(backup.path);
          } catch (_) {
            await file.copy(
              '${directory!.path}/state.corrupt.${DateTime.now().microsecondsSinceEpoch}.json',
            );
          }
          if (Platform.isWindows) await file.delete();
        }
        await temp.rename(file.path);
      }
      notifyListeners();
    });
    _pending = operation;
    return operation;
  }

  Future<void> put(Level level) => _mutate(() async {
    LevelCodec().decode(level.encode());
    if (bundled.any((l) => l.id == level.id)) {
      throw const LevelValidationException(
        'Choose a unique level ID; bundled levels cannot be replaced.',
      );
    }
    final previous = List<Level>.of(custom);
    custom.removeWhere((l) => l.id == level.id);
    custom.add(level);
    try {
      await save();
    } catch (_) {
      custom
        ..clear()
        ..addAll(previous);
      rethrow;
    }
  });

  Future<void> delete(Level level) => _mutate(() async {
    final previous = List<Level>.of(custom);
    custom.removeWhere((l) => l.id == level.id);
    try {
      await save();
    } catch (_) {
      custom
        ..clear()
        ..addAll(previous);
      rethrow;
    }
  });

  Future<void> updateSettings({
    String? language,
    bool? dark,
    Map<String, dynamic>? providerSettings,
  }) {
    // Own the input before waiting in the mutation queue.
    final settings = providerSettings == null
        ? null
        : Map<String, dynamic>.of(providerSettings);
    return _mutate(() async {
      final oldLanguage = this.language,
          oldDark = this.dark,
          oldProvider = provider;
      if (language != null && !['cs', 'en'].contains(language)) {
        throw ArgumentError.value(language, 'language', 'Expected cs or en');
      }
      this.language = language ?? this.language;
      this.dark = dark ?? this.dark;
      if (settings != null) {
        provider = {
          for (final key in ['baseUrl', 'model', 'name', 'timeout'])
            if (settings.containsKey(key)) key: settings[key],
        };
      }
      try {
        await save();
      } catch (_) {
        this.language = oldLanguage;
        this.dark = oldDark;
        provider = oldProvider;
        rethrow;
      }
    });
  }

  Future<void> record({
    required String session,
    required Level level,
    required Question question,
    required int points,
  }) => _mutate(() async {
    if (history.any(
      (r) =>
          r['session'] == session &&
          r['level'] == level.id &&
          r['question'] == question.id,
    )) {
      return;
    }
    if (points < 0 || points > 1000) {
      throw ArgumentError.value(points, 'points', 'Expected 0–1000');
    }
    final result = <String, dynamic>{
      'session': session,
      'level': level.id,
      'question': question.id,
      'points': points,
      'date': DateTime.now().toUtc().toIso8601String(),
    };
    history.add(result);
    try {
      await save();
    } catch (_) {
      history.remove(result);
      rethrow;
    }
  });

  static Future<AppStore> open() async {
    final store = AppStore(directory: await getApplicationSupportDirectory());
    await store.load();
    return store;
  }
}
