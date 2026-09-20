import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/geo.dart';
import '../domain/level.dart';

class CatalogFeature {
  final String id, name, kind, region, detail, countryCode;
  final Map<String, String> identifiers;
  final List<String> aliases;
  final Geometry geometry;
  CatalogFeature(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      kind = json['kind'] as String,
      region = json['region'] as String,
      countryCode = json['countryCode'] as String? ?? '',
      identifiers = Map<String, String>.from(
        json['identifiers'] as Map? ?? const {},
      ),
      detail = json['detail'] as String,
      aliases = List<String>.from(json['aliases'] as List),
      geometry = _geometry(json['geometry'] as Map<String, dynamic>);

  static Geometry _geometry(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final coordinates = json['coordinates'] as List;
    final parts = type == 'Point'
        ? [
            [coordinates],
          ]
        : type == 'LineString'
        ? [coordinates]
        : coordinates;
    return Geometry(type, [
      for (final part in parts)
        [
          for (final p in part)
            GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
    ]);
  }

  String get sourceGroupId =>
      id.contains('-') ? id.substring(0, id.lastIndexOf('-')) : id;
  int get partNumber => (int.tryParse(id.split('-').last) ?? 0) + 1;

  Question question({bool czech = true}) => Question(
    id: id,
    prompt: '${czech ? 'Vyznač' : 'Mark'}: $name',
    answerType: switch (kind) {
      'city' => AnswerType.point,
      'river' => AnswerType.polyline,
      _ => AnswerType.polygon,
    },
    geometry: geometry,
    category: kind,
    explanation:
        'Natural Earth · $name. $detail. ${czech ? 'Generalizovaná výuková geometrie; vyžaduje kontrolu.' : 'Generalized teaching geometry; requires review.'}',
    tags: ['catalog:$id'],
  );

  MapConfig get map {
    final points = geometry.points;
    final lons = points.map((p) => p.lon).toList()..sort();
    final lats = points.map((p) => p.lat).toList()..sort();
    final extent = (lons.last - lons.first) > (lats.last - lats.first) * 2
        ? lons.last - lons.first
        : (lats.last - lats.first) * 2;
    return MapConfig(
      center: GeoPoint(
        (lons.first + lons.last) / 2,
        (lats.first + lats.last) / 2,
      ),
      span: (extent * 1.4).clamp(1, 160),
    );
  }

  late final String searchText = normalize(
    '$name ${aliases.join(' ')} $region $id',
  );
  static String normalize(String text) {
    const accented = 'áäàâãåčćďéěëèêíïìîľĺňñóöòôõřŕšśťúůüùûýÿžź';
    const plain = 'aaaaaaccdeeeeeiiiillnnooooorrsstuuuuuyyzz';
    var result = text.toLowerCase();
    for (var i = 0; i < accented.length; i++) {
      result = result.replaceAll(accented[i], plain[i]);
    }
    return result;
  }
}

class FeatureCatalog {
  final List<CatalogFeature> features;
  FeatureCatalog(this.features);
  late final Map<String, CatalogFeature> byId = {
    for (final f in features) f.id: f,
  };
  static Future<FeatureCatalog>? _cached;
  static FeatureCatalog? _value;
  static Future<FeatureCatalog> load() async {
    if (_value != null) return _value!;
    return _cached ??= _load();
  }

  static Future<FeatureCatalog> _load() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/maps/catalog.json'),
    ) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const LevelValidationException('Unsupported catalog version.');
    }
    return _value = FeatureCatalog([
      for (final f in json['features'])
        CatalogFeature(f as Map<String, dynamic>),
    ]);
  }

  late final Map<String, int> partCounts = (() {
    final counts = <String, int>{};
    for (final f in features) {
      counts.update(f.sourceGroupId, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  })();

  Map<String, Question> questions({bool czech = true}) => {
    for (final f in features) f.id: f.question(czech: czech),
  };

  String manifest(List<CatalogFeature> selected) => jsonEncode([
    for (final f in selected)
      {
        'catalogId': f.id,
        'name': f.name,
        'aliases': f.aliases,
        'kind': f.kind,
        'region': f.region,
        'countryCode': f.countryCode,
        'identifiers': f.identifiers,
        'center': f.map.center.toJson(),
        'sourceGroupId': f.sourceGroupId,
        'partNumber': f.partNumber,
        'partCount': partCounts[f.sourceGroupId],
      },
  ]);

  Future<Level> decode(String source, {Set<String>? requiredIds}) async =>
      LevelCodec(
        catalog: questions(),
        requiredCatalogIds: requiredIds,
      ).decode(source);
}

Future<Level> decodeAuthoringLevel(String source) async {
  final codec = LevelCodec();
  final json = codec.parse(source);
  final questions = json['questions'];
  if (questions is! List ||
      !questions.any((q) => q is Map && q.containsKey('catalogId'))) {
    return codec.fromJson(json);
  }
  final catalog = await FeatureCatalog.load();
  return LevelCodec(catalog: catalog.questions()).fromJson(json);
}
