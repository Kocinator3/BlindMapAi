# Architecture
Flutter shared UI for Android, Windows and Linux. Domain models, geometry scoring and validation remain independent of widgets. Offline local geographic assets feed a custom map painter. Repository abstractions own persistence. All manual, imported and AI levels pass the same canonical validator. AI is opt-in authoring only.

## Modules and boundaries
- `domain/geo.dart`: coordinate type, Haversine, local projection, simplification and ring checks. No Flutter dependency.
- `domain/level.dart`: immutable Level/Question/Geometry, JSON codec, semantic validation and migration. All authored/imported/AI content enters this codec.
- `domain/scoring.dart`: pure 0–1000 scoring with diagnostic metadata. It runs on submit, never during drawing.
- `map/map_canvas.dart`: offline custom painting, cached geographic paths, viewport conversion and gesture/history state. Navigate mode owns pan/pinch; Draw mode owns answers. Player and reference overlays are distinct shapes/colors.
- `data/store.dart`: local repository, serialized flushed saves, backup recovery, result history and derived progression. Settings are allowlisted to exclude provider secrets.
- `data/ai_service.dart`: dedicated standalone prompt, bounded response extraction, provider interface and compatible HTTP client. Remote requests require HTTPS; loopback supports HTTP. Redirects are rejected. Keys are session-only.
- `features/`: responsive shell, gameplay, visual authoring, JSON exchange, draft guards and AI configuration/review.

## Desktop pointer contract
`MapCanvas` uses one `desktopDragThreshold` (6 logical pixels). Point/Polyline/MultiPoint clicks place geometry; movement past the threshold pans and suppresses placement. Polygon/freehand/circle Draw tools own area drags; vertex-move owns editing drags. Space+left or middle drag temporarily pans without emitting geometry. Device-kind dispatch separates mouse clicks from touch taps. Two touch pointers cancel the draft and latch navigation until every finger lifts. Scale end closes areas only, leaving river strokes open. Central cancellation resets gesture fields; type/config changes reset tool/history, and gameplay keys provide fresh state per question. Mouse wheel zoom remains independent. Native and widget regression evidence is recorded in REVIEW_2026-09-13.md.

## Save recovery
Authored put/delete/record operations serialize mutation, persistence and rollback as one boundary. This prevents an earlier failed save from undoing a later edit; raw save calls additionally serialize filesystem work. Settings currently mutate public fields directly and are not transactional.

Writes go to a flushed temporary file. A validated previous primary is copied to backup before replacement. Semantically invalid primary files are copied to timestamped recovery files and cannot replace a good backup. POSIX replacement is atomic; Windows requires deleting the primary before renaming, so the validated backup closes the recovery gap. Save errors propagate to the UI; authored-level mutations roll back in memory. Multiple save operations serialize their filesystem work.

## Geographic scope
Coordinates are serialized [longitude, latitude]. Supported rendering latitude is ±85°, explicitly validated. Points use a sphere with radius 6371.0088 km. Regional lines/areas use a target-centered equirectangular projection with wrapped longitude; target polygons have a 3500 km extent bound. This approximation is documented rather than represented as geodetic area accuracy. Country boundaries are generalized Natural Earth teaching maps.

Line precision and coverage use 160 arc-length samples each direction and a harmonic mean. Polygon overlap samples a fixed 100×100 grid in the target bounds, estimates intersection relative to target hits, uses analytical attempt area to penalize oversized guesses, and maps sqrt(IoU) to points. Exact/reference cases and near/missing/oversized/disjoint scenarios have regression tests. Tiny/thin polygons and very large/high-latitude regions still need deeper scoring simulation.

## Build discipline
Run Flutter commands sequentially in a shared checkout. Integration tests can regenerate plugin registrants and must not overlap release builds. Native CI uses separate OS jobs. Runtime core never downloads maps or levels. Builds and dependency setup require network only during development.
