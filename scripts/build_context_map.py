"""Build offline map and named authoring catalog from Natural Earth GeoJSON.
Usage: python scripts/build_context_map.py rivers.geojson cities.geojson lakes.geojson
Requires Shapely. Provenance and representation limits: docs/DATA_SOURCES.md.
"""
import json
import sys
from pathlib import Path
from shapely.geometry import Polygon, LineString
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
            cities.append({'point': p, 'capital': props.get('adm0cap') == 1})
            parts = [[p]]
        elif kind == 'river':
            parts = [g['coordinates']] if g['type'] == 'LineString' else g['coordinates']
            rivers.extend(points(part) for part in parts)
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
                'detail': ('Exterior outline; islands excluded from scoring' if kind == 'lake'
                           else 'Source segment' if len(parts) > 1 else 'Natural Earth'),
                'geometry': {'type': {'city': 'Point', 'river': 'LineString', 'lake': 'Polygon'}[kind],
                             'coordinates': ring[0] if kind == 'city' else [ring] if kind == 'lake' else ring},
            })
Path('assets/maps/context.json').write_text(json.dumps(
    {'rivers': rivers, 'cities': cities, 'lakes': lakes}, separators=(',', ':')) + '\n')
Path('assets/maps/catalog.json').write_text(json.dumps(
    {'version': 1, 'features': catalog}, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'{len(rivers)} river parts, {len(cities)} cities, {len(lakes)} lake polygons, {len(catalog)} catalog entries')
