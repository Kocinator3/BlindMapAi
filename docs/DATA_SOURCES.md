# Geographic data
Offline boundaries: Natural Earth 1:50m Admin 0 Countries, downloaded 2026-09-13 from https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_50m_admin_0_countries.geojson . Geometry retained; feature properties removed. Natural Earth data are public domain: https://www.naturalearthdata.com/about/terms-of-use/ . Boundaries are generalized educational representations, not statements about sovereignty.

Demo city coordinates are rounded teaching reference points. River and mountain outlines are explicitly approximate instructional geometries and require geographic review before a production release. They are not survey data.

River update: Vltava and Czech Elbe reference lines now derive from Natural Earth 1:10m rivers/lake centerlines, https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_rivers_lake_centerlines.geojson (downloaded 2026-09-13). Vltava's two source segments are concatenated across a short reservoir gap. Elbe upstream/main segments are concatenated and clipped near the Czech–German frontier (first west-of-14.2°E coordinate north of 50.86°N). These generalized lines omit the exact springs and remain marked for teaching review. `scripts/create_demo.py` creates initial fixtures only and would overwrite these curated river updates; do not rerun it without restoring the source-derived pack.

## Offline context added 2026-09-19
`assets/maps/context.json` is derived from Natural Earth 1:10m [rivers/lake centerlines](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_rivers_lake_centerlines.geojson) and [populated places simple](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_populated_places_simple.geojson), downloaded 2026-09-19. Reproduce with `python scripts/build_context_map.py /path/to/rivers.geojson /path/to/cities.geojson`.

2,442 complete river segments cover the worldwide source dataset, including all inhabited continents. River selection is no longer restricted to Europe. No synthetic joins are added. 3,645 city markers include the source's European places plus worldwide places with `pop_max >= 100000` and all `adm0cap == 1` national capitals. Population is the source's generalized historical selection attribute, not a current population estimate. Coordinates are rounded to five decimals; names are omitted. Ordinary cities use circles, national capitals use pentagons. Antarctica has no qualifying cities. Coverage is limited by Natural Earth's selection and is not an exhaustive gazetteer. Layers are independent of question answers, have no labels/highlights, and are bundled for fully offline play.

Worldwide river expansion reuses the same downloaded sources. SHA-256 of input GeoJSON files:

- Rivers: `bb854a900ecbd3b408df46d5e16e3e0f974ba55993f9d8b5c26e855273c0905a`
- Cities: `fd3fa867a320cbd5c5b6bb5bc550afeec2939fb2cef688e508007282a55ac42f`
