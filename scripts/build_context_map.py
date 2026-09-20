"""Build offline map and named authoring catalog from Natural Earth GeoJSON.
Usage: python scripts/build_context_map.py rivers.geojson cities.geojson lakes.geojson
Requires Shapely. Provenance and representation limits: docs/DATA_SOURCES.md.
"""
import json
import re
import sys
from pathlib import Path
from shapely.geometry import Polygon, LineString, MultiLineString
from shapely import make_valid


def points(part, precision=5):
    result = []
    for p in part:
        p = [round(p[0], precision), round(p[1], precision)]
        if not result or p != result[-1]:
            result.append(p)
    return result


def teaching(part, polygon=False):
    # Preserve source vertices; topology-preserving simplification only when
    # required by the canonical 500-vertex question limit.
    shape = Polygon(part) if polygon else LineString(part)
    tolerance = 0.00001
    while True:
        ring = points(shape.exterior.coords if polygon else shape.coords, 6 if polygon else 5)
        if len(ring) <= 500:
            return ring
        shape = shape.simplify(tolerance, preserve_topology=True)
        tolerance *= 2


if len(sys.argv) != 4:
    raise SystemExit(__doc__)

catalog = []
rivers, cities, lakes = [], [], []
river_sources = []
for kind, source in zip(['river', 'city', 'lake'], sys.argv[1:]):
    for index, feature in enumerate(json.loads(Path(source).read_text())['features']):
        g, props = feature['geometry'], feature['properties']
        if not g:
            continue
        name = props.get('name_en') or props.get('name') or f'Unnamed {kind} {index + 1}'
        aliases = list(dict.fromkeys(str(props[k]) for k in
                       ['name', 'name_en', 'name_alt', 'namealt', 'nameascii', 'name_de', 'name_cs']
                       if props.get(k)))
        czech_names = {'Elbe': 'Labe', 'Danube': 'Dunaj', 'Moldau': 'Vltava',
                       'Rhine': 'Rýn', 'Oder': 'Odra', 'Vistula': 'Visla',
                       'Thames': 'Temže', 'Seine': 'Seina', 'Nile': 'Nil',
                       'Prague': 'Praha', 'Vienna': 'Vídeň', 'London': 'Londýn',
                       'Paris': 'Paříž', 'Rome': 'Řím', 'Berlin': 'Berlín',
                       'Warsaw': 'Varšava', 'Munich': 'Mnichov',
                       'Lake Geneva': 'Ženevské jezero', 'Lake Constance': 'Bodamské jezero',
                       'Caspian Sea': 'Kaspické moře', 'Lake Baikal': 'Bajkal',
                       'Lake Victoria': 'Viktoriino jezero', 'Lake Superior': 'Hořejší jezero'}
        if name in czech_names:
            aliases.append(czech_names[name])
        identity = props.get('ne_id') or index
        if kind == 'city':
            if g['type'] != 'Point':
                continue
            p = points([g['coordinates']])[0]
            cities.append({'point': p, 'capital': props.get('adm0cap') == 1,
                           'population': max(0, int(props.get('pop_max') or 0))})
            parts = [[p]]
        elif kind == 'river':
            parts = [g['coordinates']] if g['type'] == 'LineString' else g['coordinates']
            rivers.extend(points(part) for part in parts)
            river_sources.append((name, identity, parts))
        else:
            polygons = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
            lakes.extend([[points(ring) for ring in polygon] for polygon in polygons])
            parts = []
            for polygon in polygons:
                repaired = make_valid(Polygon(polygon[0]))
                pieces = [repaired] if repaired.geom_type == 'Polygon' else list(repaired.geoms)
                parts.extend(list(piece.exterior.coords) for piece in pieces if piece.geom_type == 'Polygon')
        for part_index, part in enumerate(parts):
            if any(abs(p[1]) > 85 for p in part):
                continue
            ring = points(part) if kind == 'city' else teaching(part, kind == 'lake')
            # Generalized exterior rings remain explicitly unverified.
            if kind == 'lake' and (not Polygon(ring).is_valid or Polygon(ring).area == 0):
                raise ValueError(f'Invalid lake {name} {part_index}')
            suffix = f' · {part_index + 1}/{len(parts)}' if len(parts) > 1 else ''
            catalog.append({
                'id': f'ne-v1-{kind}-{identity}-{part_index}',
                'name': name + suffix, 'aliases': aliases, 'kind': kind,
                'region': props.get('adm0name') or props.get('admin') or '',
                'countryCode': props.get('iso_a2') if re.fullmatch(r'[A-Z]{2}', props.get('iso_a2') or '') else '',
                'identifiers': {
                    **({'naturalEarth': str(props['ne_id'])} if props.get('ne_id') else {}),
                    **({'wikidata': props['wikidataid']} if re.fullmatch(r'Q[1-9][0-9]*', props.get('wikidataid') or '') else {}),
                },
                'detail': ('Exterior outline; islands excluded from scoring' if kind == 'lake'
                           else 'Source segment' if len(parts) > 1 else 'Natural Earth'),
                'geometry': {'type': {'city': 'Point', 'river': 'LineString', 'lake': 'Polygon'}[kind],
                             'coordinates': ring[0] if kind == 'city' else [ring] if kind == 'lake' else ring},
            })

# A river question must cover the source's whole named course, not one tile-like
# source segment. Keep old IDs for importing drafts, but direct them to the new
# full-course entry and hide their partial geometries from default selection.
by_name = {}
nile_course = {'Nile', 'White Nile', 'Mountain Nile', 'Albert Nile',
               'Victoria Nile', 'Rosetta Branch', 'Damietta Branch'}
for name, identity, parts in river_sources:
    by_name.setdefault(name, []).append((identity, parts))

def whole_course(parts):
    original = [LineString(p) for p in parts if len(points(p)) >= 2 and LineString(p).length > 0]
    tolerance = 0.00001
    while True:
        result = [points(s.simplify(tolerance, preserve_topology=True).coords) for s in original]
        result = [p for p in result if len(p) >= 2 and len(set(map(tuple, p))) >= 2]
        if sum(map(len, result)) <= 500:
            return result
        tolerance *= 2
        if tolerance > 10:
            raise ValueError('River components cannot fit the 500-vertex budget')

for name, sources in by_name.items():
    # River names can occur on different continents. Group nearby source
    # features only; never connect unrelated rivers merely by their name.
    clusters = []
    for source in sources:
        shape = MultiLineString(source[1])
        touching = [c for c in clusters if any(shape.distance(MultiLineString(s[1])) < .5 for s in c)]
        group = [source]
        for cluster in touching:
            group.extend(cluster)
            clusters.remove(cluster)
        clusters.append(group)
    if name == 'Nile':
        # Natural Earth labels the main Nile course in several languages/sections.
        # Preserve those sections and delta branches; Blue Nile remains separate.
        clusters = [[s for n in sorted(nile_course) for s in by_name.get(n, [])]]
    for group in clusters:
        identity = min(s[0] for s in group)
        whole_id = f'ne-v2-river-{identity}-whole' if name != 'Nile' else 'ne-v2-river-nile-whole'
        full = whole_course([p for _, parts in group for p in parts])
        if not full:
            continue
        originals = [f for f in catalog if f['kind'] == 'river' and
                     any(f['id'].startswith(f'ne-v1-river-{i}-') for i, _ in group)]
        for f in originals:
            # Preserve specific tributary names as selectable full courses too.
            if name != 'Nile' or f['name'].split(' · ')[0] == 'Nile':
                f['replacementId'] = whole_id
        aliases = list(dict.fromkeys(a for f in originals for a in f['aliases']))
        # Nile aliases must not make a White Nile-only lookup match the entire Nile.
        if name == 'Nile':
            aliases = ['Nile', 'Nil']
        catalog.append({
            'id': whole_id, 'name': name, 'aliases': aliases, 'kind': 'river',
            'region': '', 'countryCode': '', 'identifiers': {},
            'detail': 'Whole named source course; all components simplified together, endpoints retained; source gaps are not invented',
            'geometry': {'type': 'MultiLineString', 'coordinates': full},
        })
Path('assets/maps/context.json').write_text(json.dumps(
    {'rivers': rivers, 'cities': cities, 'lakes': lakes}, separators=(',', ':')) + '\n')
Path('assets/maps/catalog.json').write_text(json.dumps(
    {'version': 1, 'features': catalog}, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'{len(rivers)} river parts, {len(cities)} cities, {len(lakes)} lake polygons, {len(catalog)} catalog entries')
