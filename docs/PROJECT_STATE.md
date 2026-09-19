# Project state — 2026-09-19 gameplay and blind-map milestone

## Resume here
Read AGENTS.md, this file, ROADMAP.md, KNOWN_ISSUES.md, Git status/diff and recent history. Flutter/Dart are at `/tmp/slepamapa-flutter/bin/` (not on PATH). The SDK was missing at session start and restored at 3.47.4. Android SDK is `/opt/android-sdk`. This remains a pre-release.

## Starting state and preserved work
Started at `330ec83` (responsive gameplay commit), with only untracked `test/gameplay_responsive_test.dart`. Read the previous review/memory and inspected status/diff/history; all 69 baseline tests passed. Preserved that responsive test file. Previous memory's conflicting Git state and artifact information were stale.

## User-approved scope and behavior
- Every new gameplay session shuffles a copy of its question list once, without duplicates. JSON/editor order is unchanged. Type/geometry continue to determine interaction, independent of shuffled index or names.
- Per-level `hardcoreMode` ends a run after the first answer below 700/1000 (feedback first, then Results; no next question). This matches the existing successful-combo threshold.
- `toleranceMultiplier` (0.25..4, default 1) multiplies distance tolerance for point, multipoint and polyline questions. Area overlap scoring is unchanged and the editor explains this.
- Both settings survive visual edits, JSON Apply/save/export/import, and copied AI instructions. Optional schema-v1 fields preserve old levels via defaults; malformed new fields are rejected.
- Results offer a fresh timed challenge (90 seconds per question; fixed the previous extra second) and randomized practice of up to five lowest-scoring answered questions from that run. Practice disables hardcore and preserves tolerance/map settings. Existing home mistake practice also preserves tolerance.
- Offline context contains 357 European river segments and 3,645 worldwide city markers. European places plus worldwide places with source population >=100,000 and all national capitals. Ordinary cities: circles; national capitals: pentagons, with legend. No names or question-derived highlights. `map.showRivers` and `map.showCities` are editable and persisted. Source scope/provenance/reproduction are in DATA_SOURCES.md and scripts/build_context_map.py.
- Touch point/multipoint dragging now pans without creating a draft. Pinch zoom anchors at the focal geography, rebases when pointer count changes, and preserves the two-finger navigation latch until all fingers lift. Desktop and drawing regressions remain covered.

## Verification
- Baseline 69 tests passed before behavior changes.
- Final complete suite: all 79 tests passed, including the end-to-end randomized run and weakest-ranking check.
- `dart format .` clean; `flutter analyze --no-pub` clean.
- All 3 Linux native integration flows passed, including real context loading/rendering and authoring/import. Inspected `/tmp/slepamapa-area-review.png`: rivers and circle/pentagon markers render correctly.
- Regression coverage includes randomized permutation/unchanged source order, malformed/new/legacy JSON settings, distance multiplier scoring, editor controls/preservation, hardcore termination, replay and exact timeout, touch pan/pinch/cancel/reset, continental coverage/capital classification, and context toggles.
- Android and final Linux release builds passed after `flutter clean` resolved a stale GeneratedPluginRegistrant reference to integration_test left by native testing. APK: `build/app/outputs/flutter-apk/app-release.apk` (55,660,884 bytes, development-signed). Linux: `build/linux/x64/release/bundle/slepa_mapa`. Packaged distribution: `dist/slepamapa-linux-x64.tar.gz` (11,322,449 bytes), with executable, map context, LICENSE, README and DATA_SOURCES verified.
- No Android device/emulator is connected. Android runtime gestures, lifecycle and file chooser remain unverified on a physical device. Windows build was attempted and Flutter reported `"build windows" only supported on Windows hosts`; use the existing Windows CI/job on a Windows host.

## Review and next priorities
New settings are additive; old history is not rescored. Best scores still aggregate sessions without distinguishing tolerance/mode or requiring completion; address that fairness issue in a future approved cycle. Rivers outside Europe, lakes, full map viewport editing, source-backed mountain outlines, large-text accessibility and complete localization remain open. See KNOWN_ISSUES.md.

Prior stable reviews retained: `0d45a8f` interaction reset; `48108ce` desktop polygon authoring; `38f0fdc` authoring preservation; `f26e239` serialized persistence; `efcfc6d` thin/concave area-overlap fairness; `2c330c7` transactional settings; `330ec83` responsive gameplay. See REVIEW_2026-09-13.md for original audit details.

## Git handoff
The milestone could not be staged: `.git/index.lock` creation failed with `Read-only file system`. No retries or permission workarounds were attempted; source changes remain in the worktree. The existing untracked responsive regression test is intentionally included in the handoff. Do not push.

Run when Git is writable:
```sh
git add docs/ARCHITECTURE.md docs/DATA_SOURCES.md docs/KNOWN_ISSUES.md docs/PROJECT_STATE.md docs/ROADMAP.md docs/level.schema.json assets/maps/context.json scripts/build_context_map.py lib/data/ai_service.dart lib/domain/level.dart lib/domain/scoring.dart lib/features/editor.dart lib/features/gameplay.dart lib/features/home.dart lib/map/map_canvas.dart test/drawing_test.dart test/editor_regression_test.dart test/map_regression_test.dart test/widget_test.dart test/fixed_order_random.dart test/gameplay_responsive_test.dart test/level_options_test.dart test/map_context_test.dart integration_test/app_test.dart
git commit -m "feat: randomize gameplay and add level challenges and offline map context"
```
