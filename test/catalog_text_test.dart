import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/data/catalog_text.dart';
import 'package:slepa_mapa/data/feature_catalog.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/features/catalog_repair.dart';

CatalogFeature fixture(
  String id,
  String name, {
  String region = 'Czechia',
  String kind = 'city',
}) => CatalogFeature({
  'id': id,
  'name': name,
  'aliases': ['Praha'],
  'kind': kind,
  'region': region,
  'detail': 'Source',
  'countryCode': 'CZ',
  'identifiers': {'wikidata': 'Q1085'},
  'geometry': {
    'type': 'Point',
    'coordinates': [14.4, 50.1],
  },
});
Map<String, dynamic> search({String text = 'Praha'}) => {
  'protocol': CatalogTextSession.protocol,
  'catalog': CatalogTextSession.revision,
  'action': 'search',
  'text': text,
  'kind': 'city',
  'userText': 'Hledám město Praha.',
};
Map<String, dynamic> select(List<String> ids) => {
  'protocol': CatalogTextSession.protocol,
  'catalog': CatalogTextSession.revision,
  'action': 'select',
  'userText': 'Vybral jsem požadovaná místa.',
  'items': [
    for (final id in ids) {'catalogId': id, 'userText': 'Město Praha v Česku.'},
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeatureCatalog realCatalog;
  setUpAll(() async => realCatalog = await FeatureCatalog.load());

  test(
    'lookup ordering, aliases, filters and pagination are deterministic',
    () {
      final catalog = FeatureCatalog([
        fixture('b', 'Prague'),
        fixture('a', 'Prague'),
        fixture('c', 'Prague', region: 'Elsewhere'),
      ]);
      final session = CatalogTextSession(catalog);
      final query = {
        ...search(text: ' PRÁHA '),
        'region': 'czechia',
        'limit': 1,
      };
      final first = session.search(query);
      expect(first['total'], 2);
      expect(first['nextOffset'], 1);
      expect((first['items'] as List).single['catalogId'], 'a');
      final second = session.search({...query, 'offset': 1});
      expect(second['nextOffset'], isNull);
      expect((second['items'] as List).single['catalogId'], 'b');
      expect(session.search(query), first);
      expect(
        CatalogTextSession(FeatureCatalog(catalog.features.reversed.toList()))
            .search(query),
        first,
      );
      expect(
        session.search({...search(), 'region': 'unknown'})['status'],
        'not_found',
      );
      expect(session.search(search(text: 'Prag'))['total'], 0);
      expect(
        session.search({...search(text: 'Prag'), 'match': 'contains'})['total'],
        3,
      );
    },
  );

  test('one proposal JSON resolves the complete catalog in one pass', () {
    final catalog = FeatureCatalog([
      fixture('city-1', 'Prague'),
      fixture('city-2', 'Brno', region: 'Czechia'),
    ]);
    final proposal = {
      'protocol': CatalogTextSession.protocol,
      'catalog': CatalogTextSession.revision,
      'action': 'propose',
      'userText': 'Kompletní seznam měst pro úroveň.',
      'queries': [
        {'text': 'Prague', 'kind': 'city', 'userText': 'Praha v Česku'},
        {'text': 'Brno', 'kind': 'city', 'userText': 'Brno v Česku'},
      ],
    };
    final items = resolveCatalogProposal(catalog, jsonEncode(proposal));
    expect(items, hasLength(2));
    expect(items.every((item) => item.resolved), isTrue);
    expect(items.expand((item) => item.matches).map((f) => f.id), [
      'city-1',
      'city-2',
    ]);
  });

  test('proposal rejects invented keys and unsupported scope', () {
    final catalog = FeatureCatalog([fixture('city-1', 'Prague')]);
    final base = {
      'protocol': CatalogTextSession.protocol,
      'catalog': CatalogTextSession.revision,
      'action': 'propose',
      'userText': 'Návrh',
      'queries': [
        {'text': 'Prague', 'kind': 'city', 'userText': 'Praha'},
      ],
    };
    expect(
      () =>
          resolveCatalogProposal(catalog, jsonEncode({...base, 'extra': true})),
      throwsA(isA<LevelValidationException>()),
    );
    expect(
      () => resolveCatalogProposal(
        catalog,
        jsonEncode({
          ...base,
          'queries': [
            {
              'text': 'Prague',
              'kind': 'city',
              'userText': 'Praha',
              'scope': 'fuzzy',
            },
          ],
        }),
      ),
      throwsA(isA<LevelValidationException>()),
    );
  });

  test(
    'batch follows all pages and never auto-resolves different source groups',
    () {
      final features = [
        for (var i = 0; i < 61; i++)
          fixture('river-7-$i', 'Long river', kind: 'river'),
      ];
      Map<String, dynamic> batch(String scope) => {
        'protocol': CatalogTextSession.protocol,
        'catalog': CatalogTextSession.revision,
        'action': 'propose',
        'userText': 'Řeka',
        'queries': [
          {
            'text': 'Long river',
            'kind': 'river',
            'scope': scope,
            'userText': 'Všechny části řeky',
          },
        ],
      };
      final all = resolveCatalogProposal(
        FeatureCatalog(features),
        jsonEncode(batch('allParts')),
      ).single;
      expect(all.matches, hasLength(61));
      expect(all.resolved, isTrue);
      expect(
        resolveCatalogProposal(
          FeatureCatalog(features),
          jsonEncode(batch('single')),
        ).single.resolved,
        isFalse,
      );
      expect(
        resolveCatalogProposal(
          FeatureCatalog([
            ...features,
            fixture('river-8-0', 'Long river', kind: 'river'),
          ]),
          jsonEncode(batch('allParts')),
        ).single.resolved,
        isFalse,
      );
    },
  );

  test('international identifier lookup is exact, may return multiple parts and never substitutes IDs', () {
    final session = CatalogTextSession(
      FeatureCatalog([fixture('a', 'Prague'), fixture('b', 'Prague')]),
    );
    final query = {
      ...search(),
      'identifier': {'system': 'wikidata', 'value': 'Q1085'},
    }..remove('text');
    final result = session.search(query);
    expect(result['total'], 2);
    expect(
      session.search({
        ...query,
        'identifier': {'system': 'wikidata', 'value': 'Q0'},
      })['total'],
      0,
    );
    expect(
      () => session.search({...query, 'match': 'contains'}),
      throwsA(isA<LevelValidationException>()),
    );
    expect(
      () => session.select(select(['Q1085'])),
      throwsA(isA<LevelValidationException>()),
    );
    expect(session.select(select(['a'])).single.id, 'a');
  });

  test(
    'reject unoffered, duplicate, unknown IDs and malformed or unlabeled text',
    () {
      final session = CatalogTextSession(
        FeatureCatalog([fixture('a', 'Prague')]),
      );
      expect(
        () => session.select(select(['a'])),
        throwsA(isA<LevelValidationException>()),
      );
      session.search(search());
      expect(session.select(select(['a'])).single.id, 'a');
      for (final request in [
        select(['missing']),
        select(['a', 'a']),
        select(List.filled(101, 'a')),
        {
          ...select(['a']),
          'catalog': 'ne-v2',
        },
        {
          ...select(['a']),
          'extra': true,
        },
        {
          ...select(['a']),
          'items': [
            {'catalogId': 'a'},
          ],
        },
        {...search(), 'userText': ''},
        {...search(), 'limit': 1000},
        {...search(), 'offset': -1},
        {...search(), 'limit': 1.5},
      ]) {
        expect(
          () => request['action'] == 'search'
              ? session.search(request)
              : session.select(request),
          throwsA(isA<LevelValidationException>()),
        );
      }
      expect(
        () => session.parse('x' * 65537),
        throwsA(isA<LevelValidationException>()),
      );
      expect(
        () => session.parse('{' * 33),
        throwsA(isA<LevelValidationException>()),
      );
      expect(
        CatalogTextSession(session.catalog).invalidReason('a', {}),
        isNotNull,
      );
    },
  );

  test('source-backed alternative label is required for new AI drafts and disappears from canonical export', () {
    final source = realCatalog.selectableFeatures.first;
    final codec = LevelCodec(
      catalog: realCatalog.questions(),
      requireCatalogText: true,
    );
    final draft = {
      'schemaVersion': 1,
      'id': 'draft',
      'title': 'Draft',
      'questions': [
        {'catalogId': source.id, 'catalogText': source.name},
      ],
    };
    final level = codec.fromJson(draft);
    expect(level.encode(), isNot(contains('catalogText')));
    expect(level.questions.single.geometry.toJson(), source.geometry.toJson());
    expect(
      () => codec.fromJson({
        ...draft,
        'questions': [
          {'catalogId': source.id},
        ],
      }),
      throwsA(isA<LevelValidationException>()),
    );
  });

  test('source international IDs are carried without inventing missing identifiers', () {
    final lake = realCatalog.features.firstWhere(
      (f) => f.kind == 'lake' && f.identifiers.containsKey('wikidata'),
    );
    final session = CatalogTextSession(realCatalog);
    final result = session.search(
      {
        ...search(),
        'kind': 'lake',
        'identifier': {
          'system': 'wikidata',
          'value': lake.identifiers['wikidata'],
        },
      }..remove('text'),
    );
    expect(
      (result['items'] as List).any((f) => f['catalogId'] == lake.id),
      isTrue,
    );
    expect(
      realCatalog.features.firstWhere((f) => f.kind == 'river').identifiers,
      isEmpty,
    );
  });

  testWidgets(
    'repair dialog offers closest candidates, manual ID, deletion and cancel without auto-choice',
    (tester) async {
      final catalog = FeatureCatalog([
        fixture('known', 'Prague'),
        fixture('other', 'Brno'),
      ]);
      CatalogRepair? result;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  completed = false;
                  result = await repairCatalogItem(
                    context,
                    catalog: catalog,
                    invalid: 'Prage',
                    reason: 'Unknown ID',
                    czech: false,
                  );
                  completed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(find.text('Prague'), findsOneWidget);
      expect(find.text('Choose manually from catalog'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'known');
      await tester.pump();
      await tester.tap(find.text('Use entered ID'));
      await tester.pumpAndSettle();
      expect(result!.replacement!.id, 'known');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete item'));
      await tester.pumpAndSettle();
      expect(result!.replacement, isNull);
    },
  );

  testWidgets(
    'import repair cancels transaction or replaces source geometry and stale text',
    (tester) async {
      final source = realCatalog.selectableFeatures.first;
      final original = jsonEncode({
        'schemaVersion': 1,
        'id': 'level',
        'title': 'Level',
        'language': 'en',
        'questions': [
          {
            'catalogId': 'bad',
            'catalogText': source.name,
            'prompt': 'Wrong place',
            'hints': ['Wrong hint'],
          },
        ],
      });
      Level? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await decodeAuthoringWithRepair(
                  context,
                  original,
                  czech: false,
                ),
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), source.id);
      await tester.pump();
      await tester.tap(find.text('Use entered ID'));
      await tester.pumpAndSettle();
      expect(
        result!.questions.single.geometry.toJson(),
        source.geometry.toJson(),
      );
      expect(
        result!.questions.single.prompt,
        source.question(czech: false).prompt,
      );
      expect(result!.questions.single.hints, isEmpty);
      expect(result!.unverified, isTrue);
    },
  );

  testWidgets('deleting invalid import entry preserves valid questions', (
    tester,
  ) async {
    final feature = realCatalog.selectableFeatures.first;
    Level? result;
    final source = jsonEncode({
      'schemaVersion': 1,
      'id': 'delete',
      'title': 'Delete',
      'questions': [
        {'catalogId': 'bad', 'catalogText': 'Unknown lake'},
        {'catalogId': feature.id},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await decodeAuthoringWithRepair(
                context,
                source,
                czech: false,
              ),
              child: const Text('Import'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete item'));
    await tester.pumpAndSettle();
    expect(result!.questions.length, 1);
    expect(
      result!.questions.single.geometry.toJson(),
      feature.geometry.toJson(),
    );
  });
}
