import 'dart:convert';
import 'dart:math' as math;

import '../domain/level.dart';
import 'feature_catalog.dart';

/// A local, bounded conversation with the bundled catalog. No network or AI.
class CatalogTextSession {
  static const protocol = 'slepamapa.catalog/1';
  static const revision = 'ne-v1';
  final FeatureCatalog catalog;
  final Set<String> _offered = {};
  CatalogTextSession(this.catalog);

  void approve(CatalogFeature feature) => _offered.add(feature.id);

  Map<String, dynamic> parse(String text) {
    if (text.length > 65536 || utf8.encode(text).length > 65536) {
      throw const LevelValidationException(
        'Text selection input exceeds 64 KiB.',
      );
    }
    return LevelCodec().parse(text);
  }

  Map<String, dynamic> search(Map<String, dynamic> request) {
    final codec = LevelCodec();
    codec.keys(request, [
      'protocol',
      'catalog',
      'action',
      'text',
      'kind',
      'match',
      'region',
      'offset',
      'limit',
      'userText',
      'identifier',
      'countryCode',
    ], 'Search');
    _header(request, 'search');
    final hasText = request.containsKey('text');
    if (hasText == request.containsKey('identifier')) {
      codec.fail('Search', 'Supply exactly one of text or identifier.');
    }
    final text = hasText ? codec.string(request['text'], 'text') : '';
    Map<String, dynamic>? identifier;
    if (!hasText) {
      identifier = codec.object(request['identifier'], 'identifier');
      codec.keys(identifier, ['system', 'value'], 'identifier');
      if (!['wikidata', 'naturalEarth'].contains(identifier['system'])) {
        codec.fail('identifier.system', 'Use wikidata or naturalEarth.');
      }
      codec.string(identifier['value'], 'identifier.value');
    }
    if (text.length > 120) codec.fail('text', 'Use at most 120 characters.');
    final kind = request['kind'];
    if (!['city', 'river', 'lake'].contains(kind)) {
      codec.fail(
        'kind',
        'Use city, river or lake. Mountains use manual polygon authoring.',
      );
    }
    final mode = request['match'] ?? 'exact';
    if (!['exact', 'contains'].contains(mode)) {
      codec.fail('match', 'Use exact or contains. No fuzzy auto-selection.');
    }
    if (identifier != null && mode != 'exact') {
      codec.fail('match', 'Identifier lookup is exact.');
    }
    String normalized(String value) =>
        CatalogFeature.normalize(value).trim().replaceAll(RegExp(r'\s+'), ' ');
    final term = normalized(text);
    final region = request.containsKey('region')
        ? normalized(codec.string(request['region'], 'region'))
        : null;
    final countryCode = request.containsKey('countryCode')
        ? codec.string(request['countryCode'], 'countryCode')
        : null;
    final offset = _integer(
      request['offset'] ?? 0,
      'offset',
      0,
      catalog.features.length,
    );
    final limit = _integer(request['limit'] ?? 20, 'limit', 1, 50);
    final matches = catalog.features.where((f) {
      if (f.kind != kind ||
          (region != null && normalized(f.region) != region) ||
          (countryCode != null && f.countryCode != countryCode)) {
        return false;
      }
      if (identifier != null) {
        return f.identifiers[identifier['system']] == identifier['value'];
      }
      return [f.name, ...f.aliases].any(
        (name) => mode == 'exact'
            ? normalized(name) == term
            : normalized(name).contains(term),
      );
    }).toList()..sort((a, b) => a.id.compareTo(b.id));
    if (offset > matches.length) {
      codec.fail(
        'offset',
        'Offset exceeds total ${matches.length}. Start at 0.',
      );
    }
    final page = matches.skip(offset).take(limit).toList();
    _offered.addAll(page.map((f) => f.id));
    return {
      'protocol': protocol,
      'catalog': revision,
      'action': 'results',
      'query': {
        if (hasText) 'text': text,
        'identifier': ?identifier,
        'countryCode': ?countryCode,
        'kind': kind,
        'match': mode,
        if (region != null) 'region': request['region'],
      },
      'status': matches.isEmpty ? 'not_found' : 'found',
      'total': matches.length,
      'offset': offset,
      'limit': limit,
      'nextOffset': offset + page.length < matches.length
          ? offset + page.length
          : null,
      'items': jsonDecode(catalog.manifest(page)),
      'selectionRule': 'Only returned IDs may be selected. Multiple matches or parts are not proof of equivalence. Ask the author when scope/location is uncertain. An empty region means unknown, not worldwide membership.',
    };
  }

  List<dynamic> selectionIds(Map<String, dynamic> request) {
    final codec = LevelCodec();
    codec.keys(request, [
      'protocol',
      'catalog',
      'action',
      'items',
      'userText',
    ], 'Selection');
    _header(request, 'select');
    final ids = request['items'];
    if (ids is! List || ids.length > LevelCodec.maxQuestions) {
      codec.fail('items', 'Expected an array of at most 100 items.');
    }
    for (var i = 0; i < ids.length; i++) {
      final item = codec.object(ids[i], 'items[$i]');
      codec.keys(item, ['catalogId', 'userText'], 'items[$i]');
      codec.string(item['userText'], 'items[$i].userText');
    }
    return ids;
  }

  String? invalidReason(dynamic id, Set<String> used) {
    if (id is! String || !catalog.byId.containsKey(id)) {
      return 'Unknown catalog ID.';
    }
    if (used.contains(id)) return 'Duplicate catalog ID.';
    if (!_offered.contains(id)) {
      return 'This ID was not returned by a search in this session. Search first or confirm it manually.';
    }
    return null;
  }

  List<CatalogFeature> select(Map<String, dynamic> request) {
    final used = <String>{};
    return [
      for (final id in selectionIds(request)) _selectOne(id['catalogId'], used),
    ];
  }

  CatalogFeature _selectOne(dynamic id, Set<String> used) {
    final reason = invalidReason(id, used);
    if (reason != null) {
      throw LevelValidationException('items.catalogId: $reason ($id)');
    }
    used.add(id as String);
    return catalog.byId[id]!;
  }

  void _header(Map<String, dynamic> request, String action) {
    LevelCodec().string(request['userText'], 'userText');
    if (request['protocol'] != protocol ||
        request['catalog'] != revision ||
        request['action'] != action) {
      throw const LevelValidationException(
        'Use protocol slepamapa.catalog/1, catalog ne-v1 and the documented action.',
      );
    }
  }

  int _integer(dynamic value, String path, int min, int max) {
    if (value is! int || value < min || value > max) {
      LevelCodec().fail(path, 'Expected an integer $min..$max.');
    }
    return value;
  }
}

/// Suggestions are deliberately separate from resolution: never auto-accept.
List<CatalogFeature> suggestCatalog(
  FeatureCatalog catalog,
  String query, {
  Set<String> exclude = const {},
  int limit = 8,
}) {
  final needle = CatalogFeature.normalize(query).trim();
  if (needle.isEmpty) return [];
  int score(String candidate) {
    final value = CatalogFeature.normalize(candidate);
    if (needle == value) return 0;
    if (value.contains(needle)) return 1 + value.length - needle.length;
    if (value.length >= 3 && needle.contains(value)) {
      return 1 + needle.length - value.length;
    }
    return 100 + _editDistance(needle, value);
  }

  final ranked = [
    for (final f in catalog.features.where((f) => !exclude.contains(f.id)))
      (f, [f.id, f.name, ...f.aliases].map(score).reduce(math.min)),
  ];
  ranked.sort((a, b) {
    final order = a.$2.compareTo(b.$2);
    return order != 0 ? order : a.$1.id.compareTo(b.$1.id);
  });
  return ranked.take(limit).map((f) => f.$1).toList();
}

int _editDistance(String a, String b) {
  // Bound work for malformed IDs or pasted paragraphs.
  a = a.substring(0, math.min(a.length, 120));
  b = b.substring(0, math.min(b.length, 120));
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final row = <int>[i + 1];
    for (var j = 0; j < b.length; j++) {
      row.add(
        math.min(
          math.min(row[j] + 1, previous[j + 1] + 1),
          previous[j] + (a[i] == b[j] ? 0 : 1),
        ),
      );
    }
    previous = row;
  }
  return previous.last;
}

/// A complete draft is validated before any UI repair is started.
class CatalogProposalItem {
  final String userText, query;
  final List<CatalogFeature> matches;
  final bool allParts;
  const CatalogProposalItem(
    this.userText,
    this.query,
    this.matches,
    this.allParts,
  );
  bool get resolved =>
      matches.length == 1 ||
      (allParts &&
          matches.isNotEmpty &&
          matches.map((f) => f.sourceGroupId).toSet().length == 1);
}

List<CatalogProposalItem> resolveCatalogProposal(
  FeatureCatalog catalog,
  String source,
) {
  final session = CatalogTextSession(catalog);
  final codec = LevelCodec();
  final json = session.parse(source);
  codec.keys(json, [
    'protocol',
    'catalog',
    'action',
    'userText',
    'queries',
  ], 'Proposal');
  if (json['protocol'] != CatalogTextSession.protocol ||
      json['catalog'] != CatalogTextSession.revision ||
      json['action'] != 'propose') {
    codec.fail(
      'Proposal',
      'Use slepamapa.catalog/1, ne-v1 and action propose.',
    );
  }
  codec.string(json['userText'], 'userText');
  final queries = json['queries'];
  if (queries is! List || queries.length > 100) {
    codec.fail('queries', 'Expected at most 100 queries.');
  }
  return [
    for (var i = 0; i < queries.length; i++)
      (() {
        final q = codec.object(queries[i], 'queries[$i]');
        codec.keys(q, [
          'text',
          'identifier',
          'kind',
          'region',
          'countryCode',
          'userText',
          'scope',
        ], 'queries[$i]');
        final label = codec.string(q['userText'], 'queries[$i].userText');
        final scope = q['scope'] ?? 'single';
        if (scope != 'single' && scope != 'allParts') {
          codec.fail('scope', 'Use single or allParts.');
        }
        final request = {
          ...q,
          'protocol': CatalogTextSession.protocol,
          'catalog': CatalogTextSession.revision,
          'action': 'search',
          'limit': 50,
        }..remove('scope');
        final matches = <CatalogFeature>[];
        int? offset = 0;
        do {
          final page = session.search({...request, 'offset': offset});
          for (final item in page['items'] as List) {
            matches.add(catalog.byId[item['catalogId']]!);
          }
          offset = page['nextOffset'] as int?;
        } while (offset != null);
        return CatalogProposalItem(
          label,
          q['text'] as String? ?? label,
          matches,
          scope == 'allParts',
        );
      })(),
  ];
}
