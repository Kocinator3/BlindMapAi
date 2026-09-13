# Roadmap

## Implemented and exercised
- Flutter native shell, offline map, point/line/area/circle/multipoint game engine.
- Canonical v1 format, legacy fixture migration, bounded validation and scoring scenarios.
- Local levels/progress, backup recovery, results, XP/streak and mistake queue.
- Visual question/level authoring, preview, JSON exchange and import UI.
- AI prompt copying and compatible provider requests, validation and review.
- Czech/English shell, light/dark themes, mobile compact map tools.
- Linux native integration tests and Android/Linux release compilation.
- Native-runner CI and setup/packaging documentation.

## Before declaring the entire requested product complete
1. Validate Android file chooser/export, touch gestures, backgrounding and AI loopback on a device/emulator; execute Windows CI on an authorized remote.
2. Complete keyboard-only geometry authoring, accessibility semantics and large-text/small-landscape testing.
3. Add supported per-question map overrides, full viewport settings and configurable offline coastline/internal/rivers/lakes layers without answer leakage.
4. Extend visual multipart editing and consider Polygon holes/MultiPolygon with explicit scoring semantics and migration.
5. Expand geography provenance: source-backed mountain teaching regions and city citation review.
6. Centralize all Czech/English strings with localized validation messages; localize question-type labels and remaining help text.
7. Add optional OS secure credential persistence, retaining session-only mode; validate provider cancellation/timeout on Android/Windows.
8. Refine practice/learning distinction, combo rewards, success percentage and completed-session highscores.
9. Package AppImage if practical; configure production Android signing outside the repository; perform a native Windows build.
10. Deepen geometric property tests, large-level benchmarks, map hit-testing and save-failure concurrency tests.

## Continuous improvement protocol
Audit a different dimension, record a concrete high-impact issue, fix it, run targeted and required checks, review regressions, update state and decisions, commit stable work. Do not rewrite working systems merely to create activity.
