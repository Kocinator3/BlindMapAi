import 'package:flutter/material.dart';

import '../data/feature_catalog.dart';
import '../domain/geo.dart';
import '../map/map_canvas.dart';

Future<List<CatalogFeature>?> showCatalogPicker(
  BuildContext context, {
  required List<List<GeoPoint>> land,
  required bool czech,
  List<CatalogFeature> selected = const [],
  int limit = 100,
}) => Navigator.push<List<CatalogFeature>>(
  context,
  MaterialPageRoute(
    builder: (_) => CatalogPicker(
      land: land,
      czech: czech,
      initial: selected,
      limit: limit,
    ),
  ),
);

class CatalogPicker extends StatefulWidget {
  final List<List<GeoPoint>> land;
  final bool czech;
  final List<CatalogFeature> initial;
  final int limit;
  const CatalogPicker({
    super.key,
    required this.land,
    required this.czech,
    this.initial = const [],
    this.limit = 100,
  });
  @override
  State<CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<CatalogPicker> {
  late final catalog = FeatureCatalog.load();
  late final selected = {for (final f in widget.initial) f.id: f};
  CatalogFeature? preview;
  String query = '', kind = 'all';
  bool onlySelected = false;
  String tr(String cs, String en) => widget.czech ? cs : en;
  String label(String kind) => switch (kind) {
    'river' => tr('Řeky', 'Rivers'),
    'lake' => tr('Jezera', 'Lakes'),
    'city' => tr('Města', 'Cities'),
    _ => tr('Vše', 'All'),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Katalog mapových objektů', 'Map feature catalog')),
    ),
    body: SafeArea(
      child: FutureBuilder<FeatureCatalog>(
        future: catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final words = CatalogFeature.normalize(query)
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty);
          final visible = snapshot.data!.features
              .where(
                (f) =>
                    (kind == 'all' || f.kind == kind) &&
                    (!onlySelected || selected.containsKey(f.id)) &&
                    words.every(f.searchText.contains),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: tr(
                      'Hledat název, zemi nebo ID',
                      'Search name, country or ID',
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in ['all', 'river', 'lake', 'city'])
                    ChoiceChip(
                      label: Text(label(k)),
                      selected: kind == k,
                      onSelected: (_) => setState(() => kind = k),
                    ),
                  FilterChip(
                    label: Text(tr('Jen vybrané', 'Selected only')),
                    selected: onlySelected,
                    onSelected: (v) => setState(() => onlySelected = v),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  tr(
                    '${visible.length} položek · Natural Earth. Úseky řek a části jezer jsou samostatné. Jezera: vnější obrys, bez odečtu ostrovů; max. 500 bodů.',
                    '${visible.length} entries · Natural Earth. River segments and lake parts are separate. Lakes: exterior outline, islands not subtracted; max. 500 vertices.',
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final list = ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final f = visible[i];
                        final checked = selected.containsKey(f.id);
                        return CheckboxListTile(
                          key: ValueKey(f.id),
                          value: checked,
                          title: Text(f.name),
                          subtitle: Text(
                            '${label(f.kind)} · ${f.region.isEmpty ? '${f.map.center.lon.toStringAsFixed(2)}, ${f.map.center.lat.toStringAsFixed(2)}' : f.region}\n${f.id}${f.identifiers.containsKey('wikidata') ? ' · Wikidata ${f.identifiers['wikidata']}' : ''}',
                          ),
                          secondary: IconButton(
                            tooltip: tr('Náhled na mapě', 'Preview on map'),
                            icon: const Icon(Icons.map_outlined),
                            onPressed: () => setState(() => preview = f),
                          ),
                          onChanged: !checked && selected.length >= widget.limit
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    selected[f.id] = f;
                                    preview = f;
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  } else {
                                    selected.remove(f.id);
                                  }
                                }),
                        );
                      },
                    );
                    if (preview == null) return list;
                    final f = preview!;
                    final map = Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(f.name)),
                            IconButton(
                              onPressed: () => setState(() => preview = null),
                              tooltip: tr('Zavřít náhled', 'Close preview'),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        Expanded(
                          child: MapCanvas(
                            key: ValueKey('preview-${f.id}'),
                            land: widget.land,
                            config: f.map,
                            type: f.question().answerType,
                            points: const [],
                            target: f.geometry,
                            onChanged: (_) {},
                            readOnly: true,
                            showTools: false,
                            czech: widget.czech,
                          ),
                        ),
                      ],
                    );
                    if (constraints.maxWidth < 850 &&
                        constraints.maxHeight < 420) {
                      return map;
                    }
                    return constraints.maxWidth >= 850
                        ? Row(
                            children: [
                              Expanded(child: list),
                              Expanded(child: map),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: list),
                              SizedBox(
                                height: constraints.maxHeight * .42,
                                child: map,
                              ),
                            ],
                          );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => selected.clear()),
                      child: Text(tr('Zrušit výběr', 'Clear selection')),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, selected.values.toList()),
                      child: Text(
                        tr(
                          'Použít (${selected.length}/${widget.limit})',
                          'Apply (${selected.length}/${widget.limit})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
