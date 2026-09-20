# Architecture
Flutter shared UI for Android, Windows and Linux. Domain models, geometry scoring and validation remain independent of widgets. Offline local geographic assets feed a custom map painter. Repository abstractions own persistence. All manual, imported and AI levels pass the same canonical validator. AI is opt-in authoring only.

## Modules and boundaries
- `domain/geo.dart`: coordinate type, Haversine, local projection, simplification and ring checks. No Flutter dependency.
- `domain/level.dart`: immutable Level/Question/Geometry, JSON codec, semantic validation and migration. All authored/imported/AI content enters this codec.
- `domain/scoring.dart`: pure 0–1000 scoring with diagnostic metadata. It runs on submit, never during drawing.
- `domain/area_overlap.dart`: projected simple-polygon intersection via horizontal cross-sections, split at vertices and edge crossings. Independent of Flutter and raster resolution.
- `map/map_canvas.dart`: offline custom painting, cached geographic paths, viewport conversion and gesture/history state. The gameplay shell passes compact mode and owns question context; the full editor retains the editing toolbar. Navigate mode owns pan/pinch; Draw mode owns answers. Player and reference overlays are distinct shapes/colors.
- `data/store.dart`: local repository, serialized flushed saves, backup recovery, result history and derived progression. Settings are allowlisted to exclude provider secrets.
- `data/ai_service.dart`: dedicated standalone prompt, bounded response extraction, provider interface and compatible HTTP client. Remote requests require HTTPS; loopback supports HTTP. Redirects are rejected. Keys are session-only.
- `features/`: responsive shell, gameplay, visual authoring, JSON exchange, draft guards and AI configuration/review.

## Desktop pointer contract
`MapCanvas` uses one `desktopDragThreshold` (6 logical pixels). Point/Polyline/MultiPoint clicks place geometry; movement past the threshold pans and suppresses placement. Polygon/freehand/circle Draw tools own area drags; vertex-move owns editing drags. Space+left or middle drag temporarily pans without emitting geometry. Device-kind dispatch separates mouse clicks from touch taps. Two touch pointers cancel the draft and latch navigation until every finger lifts. Scale end closes areas only, leaving river strokes open. Central cancellation resets gesture fields; type/config changes reset tool/history, and gameplay keys provide fresh state per question. Mouse wheel zoom remains independent. Native and widget regression evidence is recorded in REVIEW_2026-09-13.md.

## Save recovery
Authored put/delete/record operations and settings updates serialize mutation, persistence and rollback as one boundary. This prevents an earlier failed save from undoing a later edit; raw save calls additionally serialize filesystem work.

Writes go to a flushed temporary file. A validated previous primary is copied to backup before replacement. Semantically invalid primary files are copied to timestamped recovery files and cannot replace a good backup. POSIX replacement is atomic; Windows requires deleting the primary before renaming, so the validated backup closes the recovery gap. Save errors propagate to the UI; authored-level mutations roll back in memory. Multiple save operations serialize their filesystem work.

## Geographic scope
Coordinates are serialized [longitude, latitude]. Supported rendering latitude is ±85°, explicitly validated. Points use a sphere with radius 6371.0088 km. Regional lines/areas use a target-centered equirectangular projection with wrapped longitude; target polygons have a 3500 km extent bound. This approximation is documented rather than represented as geodetic area accuracy. Country boundaries are generalized Natural Earth teaching maps.

Line precision and coverage use 160 arc-length samples each direction and a harmonic mean. Polygon overlap integrates cross-sections split at vertices and pairwise edge crossings. Between breaks, boundary ordering is fixed and overlap width is linear, so midpoint integration is exact within the projected model, subject to floating-point rounding. Analytic area penalizes oversized guesses; sqrt(IoU) still determines points. The old 100×100 grid could score an exact thin concave answer zero. Regressions now include thin/nested regions, slanted crossings, randomized rectangles, near-capacity concave rings and antimeridian/high-latitude examples. Regional projection distortion and worst-case performance still merit broader simulation; the 500-vertex input cap remains.

## Build discipline
Run Flutter commands sequentially in a shared checkout. Integration tests can regenerate plugin registrants and must not overlap release builds. Native CI uses separate OS jobs. Runtime core never downloads maps or levels. Builds and dependency setup require network only during development.

## Level options and randomized sessions (2026-09-19)
Schema v1 adds optional `hardcoreMode` (boolean, default false), `toleranceMultiplier` (0.25..4, default 1), and `map.showRivers` / `map.showCities` (booleans, default true). Older levels migrate by defaults; export emits explicit values. New fields are validated before domain construction and preserved by JSON/visual editing. Distance scoring multiplies question tolerance for point, multipoint and polyline; area overlap is unchanged.

Each GameplayPage shuffles a copy of its questions once. Original JSON/editor order remains intact; each session asks each question at most once. An injected Random supports deterministic transition tests. Hardcore permits feedback but cannot advance to another question after a score below 700. Results offer a fresh randomized timed challenge (90 seconds per question) and up to five lowest-scoring answered questions from this session as untimed practice with hardcore disabled. Other settings are preserved. Historical results are unchanged; current best-score storage still aggregates records per session and does not partition by tolerance or mode.

MapCanvas.loadLand attaches independent bundled context to the returned land dataset. Context contains European rivers and worldwide city markers (see DATA_SOURCES.md); city shapes distinguish national capitals without labels. Touch point dragging navigates without creating an answer draft. Pinch uses the geographic focal anchor and rebases when pointer count changes; drawing/navigation remains latched until all fingers lift.

## Source-backed authoring

`assets/maps/catalog.json` is a versioned, bundled Natural Earth feature catalog.
`FeatureCatalog` loads its names/aliases and geometry; `CatalogPicker` provides
search, type filters, checkboxes and a read-only map preview for both the level
editor and AI author. Runtime networking is never needed for lookup.

AI prompts contain only the checked manifest (up to 100 objects), not the entire
11,149-entry catalog. Authoring input may use a question `catalogId` shorthand.
`LevelCodec.parse` bounds and parses input; an injected catalog expands references
before the usual canonical validation. Geometry, answer type, source category and
provenance tags come from the catalog, while question text/hints remain editable.
The API path additionally checks the exact selected ID set. JSON import resolves
the same references. Unknown and duplicate references fail explicitly. Ordinary
JSON import does not need to load the catalog.

Saved/exported levels remain self-contained schema-v1 JSON with full geometry;
`catalogId` is never persisted as a runtime dependency. `map.showLakes` is an
optional boolean defaulting to true, like the other map-layer toggles. Polygon
scoring semantics remain unchanged: lake questions use only exterior rings and
are marked unverified, while background lake rendering preserves island holes.
