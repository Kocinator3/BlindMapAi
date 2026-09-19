"""Build unlabeled European rivers and worldwide city context from downloaded Natural Earth files.
Usage: python scripts/build_context_map.py rivers.geojson cities.geojson
No question/answer geometries are used. Source attribution: docs/DATA_SOURCES.md.
"""
import json
import sys
from pathlib import Path


def inside(p):
    return -25 <= p[0] <= 45 and 32 <= p[1] <= 72


rivers = []
for feature in json.loads(Path(sys.argv[1]).read_text())['features']:
    geometry = feature['geometry']
    if not geometry:
        continue
    parts = ([geometry['coordinates']] if geometry['type'] == 'LineString'
             else geometry['coordinates'] if geometry['type'] == 'MultiLineString' else [])
    for part in parts:
        # Keep entire intersecting source lines, avoiding artificial joins.
        if any(inside(p) for p in part):
            rivers.append([[round(p[0], 5), round(p[1], 5)] for p in part])
cities = []
for feature in json.loads(Path(sys.argv[2]).read_text())['features']:
    geometry = feature['geometry']
    props = feature['properties']
    selected = inside(geometry['coordinates']) if geometry and geometry['type'] == 'Point' else False
    selected = selected or (props.get('pop_max') or 0) >= 100000 or props.get('adm0cap') == 1
    if geometry and geometry['type'] == 'Point' and selected:
        p = geometry['coordinates']
        cities.append({'point': [round(p[0], 5), round(p[1], 5)], 'capital': props.get('adm0cap') == 1})
Path('assets/maps/context.json').write_text(json.dumps(
    {'rivers': rivers, 'cities': cities}, separators=(',', ':')) + '\n')
print(f'{len(rivers)} river parts, {len(cities)} cities')
