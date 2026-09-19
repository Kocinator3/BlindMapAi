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
- Offline context contains 2,442 worldwide river segments and 3,645 worldwide city markers. European places plus worldwide places with source population >=100,000 and all national capitals. Ordinary cities: circles; national capitals: pentagons, with legend. No names or question-derived highlights. `map.showRivers` and `map.showCities` are editable and persisted. Source scope/provenance/reproduction are in DATA_SOURCES.md and scripts/build_context_map.py.
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
New settings are additive; old history is not rescored. Best scores still aggregate sessions without distinguishing tolerance/mode or requiring completion; address that fairness issue in a future approved cycle. Lakes, full map viewport editing, source-backed mountain outlines, large-text accessibility and complete localization remain open. See KNOWN_ISSUES.md.

Prior stable reviews retained: `0d45a8f` interaction reset; `48108ce` desktop polygon authoring; `38f0fdc` authoring preservation; `f26e239` serialized persistence; `efcfc6d` thin/concave area-overlap fairness; `2c330c7` transactional settings; `330ec83` responsive gameplay. See REVIEW_2026-09-13.md for original audit details.

## GitHub release script — 2026-09-19

The previous gameplay milestone is committed as `4e3e969`; this task started with
an empty Git status. Added `scripts/release.sh` and usage instructions in README.
The script builds Android APK and Linux x64 archive, computes SHA-256 checksums,
and creates a release via `gh` in the explicit origin repository. Requires a clean
checkout and an already-pushed tag resolving to HEAD (lightweight or annotated).
Supports `--draft` and `--prerelease`; otherwise publishes immediately. It does not
push Git refs or overwrite existing releases. FLUTTER_BIN is configurable.
Android still uses development signing. Windows must be built separately.

Verification: Bash syntax/help, seven isolated mocked CLI scenarios (successful
release, annotated tag, dirty tree, missing/mismatched tag, existing release,
build failure), and checksum verification passed. `dart format .` changed no files,
`flutter analyze --no-pub` passed, and all 79 Flutter tests passed. Android release
build passed. The Linux packaging command hit restricted DNS during pub get;
`flutter build linux --release --no-pub` passed using cached dependencies, and
the archive was refreshed with the same copy/tar steps as package_linux.sh.
No GitHub release was created and nothing was pushed.

## Git handoff

The `.git` directory remains read-only in this session's filesystem permissions;
source changes are preserved in the worktree. Commit locally when Git is writable:

```sh
git add scripts/release.sh README.md docs/PROJECT_STATE.md
git commit -m "feat: add GitHub CLI release script for Android and Linux"
```

## Worldwide river context — 2026-09-19

Read AGENTS.md, project memory, roadmap/issues and Git history/status/diffs.
Started at `4e3e969` with the previous release work already staged in README.md,
docs/PROJECT_STATE.md and scripts/release.sh; preserved that work.

Removed the European river filter from scripts/build_context_map.py and rebuilt
assets/maps/context.json from the existing Natural Earth source downloads.
Includes all 2,442 source line parts worldwide (previously 357), retaining separate
parts without synthetic joins. All original river parts and all 3,645 city markers
are unchanged. The context asset is now 5,415,390 bytes. This expands the unlabeled
offline map layer, not the playable question packs. Coverage remains generalized
Natural Earth coverage, not every stream. Updated AI authoring guidance, data
provenance (including source hashes), roadmap and known issues.

Verification: both baseline map-context tests passed before changes. Added a
regression for river coverage near the Danube, Nile, Yangtze, Mississippi, Amazon
and Murray and for valid coordinates/line lengths. `dart format .` completed,
`flutter analyze --no-pub` passed, all 80 Flutter tests passed, and all 3 native
Linux integration tests passed with the rebuilt debug bundle and expanded data.
`git diff --check` passed. Existing release APK/tar artifacts were not rebuilt for
this data change; the native debug build includes it. Android/Windows runtime
checks remain outstanding.

Git remains read-only under the session filesystem policy; no commit or push was
performed. Finish the previously staged release milestone first, then stage and
commit this river milestone (project memory includes both handoffs):

```sh
git commit -m "feat: add GitHub CLI release script for Android and Linux"
git add assets/maps/context.json scripts/build_context_map.py test/map_context_test.dart lib/data/ai_service.dart docs/DATA_SOURCES.md docs/KNOWN_ISSUES.md docs/ROADMAP.md docs/PROJECT_STATE.md
git commit -m "feat: bundle worldwide offline river context"
```
