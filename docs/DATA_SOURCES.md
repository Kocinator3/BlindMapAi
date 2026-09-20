# Geographic data
Offline boundaries: Natural Earth 1:50m Admin 0 Countries, downloaded 2026-09-13 from https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_50m_admin_0_countries.geojson . Geometry retained; feature properties removed. Natural Earth data are public domain: https://www.naturalearthdata.com/about/terms-of-use/ . Boundaries are generalized educational representations, not statements about sovereignty.

Demo city coordinates are rounded teaching reference points. River and mountain outlines are explicitly approximate instructional geometries and require geographic review before a production release. They are not survey data.

River update: Vltava and Czech Elbe reference lines now derive from Natural Earth 1:10m rivers/lake centerlines, https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_rivers_lake_centerlines.geojson (downloaded 2026-09-13). Vltava's two source segments are concatenated across a short reservoir gap. Elbe upstream/main segments are concatenated and clipped near the Czech–German frontier (first west-of-14.2°E coordinate north of 50.86°N). These generalized lines omit the exact springs and remain marked for teaching review. `scripts/create_demo.py` creates initial fixtures only and would overwrite these curated river updates; do not rerun it without restoring the source-derived pack.

## Offline context added 2026-09-19
`assets/maps/context.json` is derived from Natural Earth 1:10m [rivers/lake centerlines](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_rivers_lake_centerlines.geojson) and [populated places simple](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_populated_places_simple.geojson), downloaded 2026-09-19. The current rebuild command also requires lakes; see the catalog section below.

2,442 complete river segments cover the worldwide source dataset, including all inhabited continents. River selection is no longer restricted to Europe. No synthetic joins are added. 3,645 city markers include the source's European places plus worldwide places with `pop_max >= 100000` and all `adm0cap == 1` national capitals. Population is the source's generalized historical selection attribute, not a current population estimate. Coordinates are rounded to five decimals; names are omitted. Ordinary cities use circles, national capitals use pentagons. Antarctica has no qualifying cities. Coverage is limited by Natural Earth's selection and is not an exhaustive gazetteer. Layers are independent of question answers, have no labels/highlights, and are bundled for fully offline play.

Worldwide river expansion reuses the same downloaded sources. SHA-256 of input GeoJSON files:

- Rivers: `bb854a900ecbd3b408df46d5e16e3e0f974ba55993f9d8b5c26e855273c0905a`
- Cities: `fd3fa867a320cbd5c5b6bb5bc550afeec2939fb2cef688e508007282a55ac42f`

## Offline authoring catalog and lakes — 2026-09-20

`assets/maps/catalog.json` version 1 adds 11,149 selectable source objects:
2,442 river segments, 1,366 lake exterior parts and 7,341 populated places.
The map now includes all 7,342 source place markers; the South Pole station
(latitude -90) is omitted from authoring because Level v1 supports -85..85.
All 1,355 Natural Earth lake features (1,366 polygons) are rendered, including
80 polygons with island holes. Coverage is the entire **source dataset**, not
every real-world lake, stream or settlement. Unnamed objects get explicit
unnamed labels; multipart objects get numbered part suffixes rather than false
joins. Country names for cities and geographic centers help disambiguation.
Some common Czech search aliases are included; most names remain source names.

Lake source: Natural Earth 1:10m
[lakes](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_lakes.geojson),
downloaded 2026-09-19; SHA-256:
`2d036f53dedec578001c5c30c2959ee7d4eebc1306900fa4367c49929ec8f2d9`.
River/city input hashes above are unchanged. Rebuild both bundled assets with:

```sh
python scripts/build_context_map.py /path/to/rivers.geojson /path/to/cities.geojson /path/to/lakes.geojson
```

Requires Python and Shapely (built with 2.1.2). Stable IDs use the `ne-v1-`
namespace, source `ne_id` where supplied, otherwise the fixed source feature
index, plus part index. Keep these exact source hashes for reproducibility;
a different source revision/part ordering requires a new catalog namespace.

Map geometry retains all river parts and complete lake rings/holes (five-decimal
rounding, consecutive duplicate removal). Question geometry copies source points;
when over 500 vertices, Shapely topology-preserving simplification reduces it to
Level v1's limit. Lake question coordinates use six decimals; invalid source
exteriors are repaired using `make_valid` and resulting polygon parts are kept.
Question lake geometry is the exterior only: **islands are not subtracted from
area scoring**. Source detail remains visible on the map. No AI coordinates are
used for catalog references; nevertheless source generalization, simplification
and teaching suitability require review. Catalog-created levels start unverified.

## Identifier metadata

The same source revision supplies optional Natural Earth `ne_id` identifiers
(8,707 catalog entries), valid Wikidata Q identifiers (621 entries) and two-letter
country codes (7,329 entries). Missing values are omitted, never inferred.
An international identifier can describe multiple geometry parts; `catalogId`
remains the unique selectable reference. The bundled text protocol `ne-v1`
uses exact identifier lookup, stable ID sorting and paginated results.
