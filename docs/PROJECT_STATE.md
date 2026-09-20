# Project state — 2026-09-20 lake/catalog authoring milestone

## Resume here
The latest user-requested catalog/lake work is recorded at the end of this file.
The user explicitly requested building the project and then stopping the improvement loop; do not start another cycle automatically.
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

## Lake and source-catalog authoring — 2026-09-20

Started from clean `22cbb5b` after reading AGENTS.md, this memory, history,
roadmap/issues and status/diff. The previous release/river changes were already
committed (older handoff commands above are historical). Baseline targeted
map/editor/API tests: all 11 passed before behavior changes.

Implemented:
- Entire Natural Earth lake layer: 1,355 features / 1,366 polygon parts, including
  island holes, independent of questions; persisted `map.showLakes` defaults true.
- All 7,342 source populated-place markers; a versioned offline catalog has
  11,149 entries: 2,442 river parts, 1,366 lake exterior parts, 7,341 city/place
  points. South Pole station is outside Level v1 latitude limits and not selectable.
- Editor and AI share searchable/type-filtered checkboxes, country/coordinate/ID
  disambiguation and map previews. Some Czech aliases work without diacritics.
  Selection is capped by the 100-question limit. Small previews replace the list
  until closed when vertical space is limited. Multiple source parts remain separate.
- Editor adds selected source questions, centering an initially empty level on
  the first object; the AI page can also create the selection entirely offline.
- Prompt includes only checked names/types/IDs/centers, avoiding an enormous full
  catalog prompt. AI returns `catalogId` references; API generation and external
  JSON import resolve their geometry locally, validate normally and mark unverified.
  Unknown/duplicate IDs fail; API generation requires all selected IDs exactly once.
  Saved/exported levels embed full geometry and remain portable without a catalog.
  Mountains retain polygon authoring. No remote AI request was sent during work.
- Source-derived geometries retain source points, with topology-preserving
  simplification only above the canonical 500-vertex limit. Lake questions use
  exterior rings, not island subtraction; invalid source exteriors are repaired.
  The full map layer retains source detail. These limits are visible in the picker
  and documented in DATA_SOURCES.md, README and architecture/known issues.

Verification:
- Every one of the 11,149 catalog geometries passes canonical Level validation.
- Both generated assets reproduce byte-for-byte using the documented source hashes
  and Shapely 2.1.2. Namespaced IDs require the same source revision/part ordering.
- All 86 unit/widget tests passed; `dart format .`, `flutter analyze --no-pub`
  and `git diff --check` passed. Covers source resolution/override, unknown/duplicate/
  missing IDs, standalone export roundtrip, selected prompt manifest, lake toggles,
  island/continental coverage, search/checkbox/preview, and existing gameplay/editor.
- All 4 native Linux integration tests passed on `DISPLAY=:0` (Xvfb is absent),
  including selecting city/river/lake, checking preview geometries, canonical editor
  output and importing an external AI lake reference. Native test input explicitly
  focuses the search field after closing map previews.
- Flutter test runner required escalation for its local socket after the session
  environment changed; no permission workaround was used.
- Android release build passed: `build/app/outputs/flutter-apk/app-release.apk`.
  Linux release build passed: `build/linux/x64/release/bundle/slepa_mapa`;
  packaged as `dist/slepamapa-linux-x64.tar.gz`. Both artifacts were checked to
  contain byte-identical current catalog/context assets; Linux executable mode,
  LICENSE, README and DATA_SOURCES were verified in the archive.
- The first Android `--no-pub` build after integration tests encountered a stale
  generated integration_test registrant even after clean/offline pub get. Standard
  `flutter build apk --release` regenerated release plugin registration and passed;
  no generated source or SDK code was patched. Linux used the standard release build.
- Android signing remains the project's development configuration; Android runtime
  and Windows builds remain unverified in this Linux environment. No test application
  or development server is being left running; native test processes have exited.
- Final state: requested implementation, verification and Android/Linux compilation
  complete. The improvement loop is stopped as requested.

Git handoff for this milestone:
The session explicitly mounts `.git` read-only. All changes are preserved in the
worktree; no commit or push was attempted. Run these exact commands when writable:

```sh
git add README.md assets/maps/context.json assets/maps/catalog.json docs/DATA_SOURCES.md docs/KNOWN_ISSUES.md docs/ROADMAP.md docs/ARCHITECTURE.md docs/PROJECT_STATE.md docs/level.schema.json integration_test/app_test.dart lib/data/ai_service.dart lib/data/feature_catalog.dart lib/domain/level.dart lib/features/ai_page.dart lib/features/catalog_picker.dart lib/features/editor.dart lib/map/map_canvas.dart scripts/build_context_map.py test/catalog_test.dart test/map_context_test.dart
git commit -m "feat: add offline lake layer and source-backed authoring catalog"
```

User stop instruction: after successful builds and verification, end this task;
do not continue the audit/improvement loop. Remaining general product issues in
KNOWN_ISSUES.md are future work, not authorization to keep this session running.

## 2026-09-20 — Catalog text protocol, repairs and API tutorials (v0.1.3)

The previous catalog milestone is committed at `0ad2bca` and tagged `v0.1.2`.
This session preserves and completes the subsequent user-requested work:

- Added bundled `docs/CATALOG_TEXT_INSTRUCTIONS.md` and an offline text-selection
  page: bounded JSON search, deterministic ID ordering, pagination, exact/contains
  lookup and explicit selection. Only IDs actually offered in the current session
  can be selected without human approval. Never fabricate catalog results.
- Added mandatory human-readable `userText` for protocol requests and selected
  items, plus `catalogText` in new API-generated catalog questions. Old valid
  imports remain compatible. Canonical exports still embed geometry, not references.
- Added source-provided Wikidata/Natural Earth identifiers and country codes;
  source group/part metadata explains ambiguity. Counts and limits are documented
  in DATA_SOURCES.md; source geometry and catalog IDs are unchanged.
- Invalid/duplicate catalog references open a transactional repair dialog with
  similar suggestions, exact ID entry, manual catalog choice, deletion and cancel.
  No suggestion is accepted automatically. Replacing a reference resets stale
  question text/hints. Cancel preserves the original draft; deleting all questions
  produces an actionable validation error. Author corrections explicitly supersede
  the originally checked AI selection; untouched replies still require that set.
- Added offline Czech/English API tutorials directly in the AI author page for
  OpenAI, Gemini, Claude, DeepSeek and Ollama, with official documentation links,
  endpoint presets, model/key setup, connection testing and troubleshooting.
  Presets clear old model/key and never send a request. Model IDs are entered from
  the provider's available models instead of embedding soon-obsolete examples.
- Provider requests omit optional temperature to accommodate models that reject
  custom sampling parameters. No provider-specific request branches or secrets
  were added. Claude workspace-header keys remain unsupported; guide explains it.
  Local Ollama is loopback-only over HTTP; remote connections still require HTTPS.
- App version is `0.1.3+4`; next unused local release tag is `v0.1.3`.

Verification: `dart format .`; 98 unit/widget tests passed, including protocol
bounds, ID lookup, source metadata, transactional repair and deletion, text page,
provider preset secret clearing and narrow-screen English guide. All 4 native
Linux integration tests passed on `DISPLAY=:0`, including invalid-reference repair.
No real paid AI request was sent. Official provider documentation was checked;
actual account/model compatibility must be checked with Test connection.

Release handoff: pushing a tag alone does not publish a GitHub Release; the
workflow only uploads CI artifacts. `scripts/release.sh` builds and publishes APK,
Linux archive and hashes after checking a clean worktree and a pushed tag at HEAD.
The user's request is for commands; no remote push or publication was performed.
`.git` is explicitly read-only in this session, so no local commit was attempted.
All source changes remain in the worktree. Run from the project directory:

```sh
git add README.md assets/maps/catalog.json docs/AI_CONNECTION_GUIDE.md docs/CATALOG_TEXT_INSTRUCTIONS.md docs/DATA_SOURCES.md docs/PROJECT_STATE.md integration_test/app_test.dart lib/data/ai_service.dart lib/data/catalog_text.dart lib/data/feature_catalog.dart lib/domain/level.dart lib/features/ai_page.dart lib/features/ai_connection_guide.dart lib/features/catalog_picker.dart lib/features/catalog_repair.dart lib/features/catalog_text_page.dart lib/features/editor.dart pubspec.yaml scripts/build_context_map.py test/ai_http_test.dart test/ai_connection_guide_test.dart test/catalog_text_test.dart
git commit -m "feat: add guided AI catalog selection and API tutorials"
git tag -a v0.1.3 -m "SlepáMapa v0.1.3"
git push --atomic origin main refs/tags/v0.1.3
FLUTTER_BIN=/tmp/slepamapa-flutter/bin/flutter bash scripts/release.sh v0.1.3
```

Stop after verification/builds, as explicitly requested. Do not restart the audit
loop; existing general product issues remain future work.

Final verification: `flutter analyze --no-pub` and `git diff --check` passed.
Android release build passed (62.3 MB):
`build/app/outputs/flutter-apk/app-release.apk`. Linux release build and packaging
passed: `dist/slepamapa-linux-x64.tar.gz`. Both contain byte-identical current
catalog and text-protocol assets; Linux executable permissions and notices were
verified. Existing catalog geometry/fields remain unchanged by added metadata.
Android SDK XML version warning was nonfatal; Android signing retains the existing
development configuration. Android runtime and Windows builds were not tested.
Native test app exited; no app/server or improvement loop is left running.
Requested implementation and local builds are complete; release awaits the manual
commit/tag/publish commands above.

## 2026-09-20 — Batch catalog proposal and five-step AI wizard (v0.1.4)

Supersedes the single-query clipboard flow from the previous milestone (committed
at `eea47bf`, local tag `v0.1.3`). User explicitly requested one complete proposal
JSON, local validation/repair, a reviewed catalog returned to AI, and only then
final level generation. The user also requested a simple commit/tag/release script.

- Replaced the scrolling AI author page with five separate steps and a fixed
  footer showing progress dots: method (API/manual chat), request, full catalog
  proposal, catalog review, final level. Only current-step controls are shown;
  long content within that step remains scrollable on small screens.
- Added action `propose` to `slepamapa.catalog/1`, with up to 100 queries in one
  bounded 64 KiB JSON. All queries and their result pages resolve locally, sorted
  by stable IDs. Explicit `allParts` accepts parts of one source group only;
  missing or ambiguous entries require replacement/manual selection/deletion.
  Repeated resolved IDs are deduplicated; more than 100 results fails without
  truncation. Cancel keeps the original proposal and previous reviewed state.
- Manual chat now requires only two exchanges. First copy request + batch
  instructions, paste proposal; after local review copy approved catalog + final
  schema/prompt, then paste final Level JSON directly into the wizard.
- API follows the same two-stage workflow, with an explicit catalog approval
  between calls. Cancellable network requests reject late replies. No API keys
  are persisted. Returning between steps preserves proposal text unless the
  request/language changes. Preset secret clearing and offline tutorials remain.
- Final prompt includes the approved manifest and repair decisions, forbids
  restoring deleted items, and requires every approved ID. Final import enforces
  that set and expands source geometry through the canonical Level codec.
- Replaced bundled instructions and updated connection tutorials/README. Removed
  the superseded single-query CatalogTextPage; low-level query validation remains
  available internally. Core gameplay and visual authoring remain offline.
- Version is `0.1.4+5`. Added `scripts/publish_release.sh`: one command commits
  explicitly listed milestone files, makes annotated `v0.1.4`, atomically pushes
  main/tag, and runs the existing APK/Linux release publisher. No-change commits
  are skipped, retries reuse only a tag at HEAD, unrelated changes and conflicting
  tags fail, existing releases are never overwritten. Flutter path is detected.

Verification: 103 unit/widget tests passed, including a complete manual proposal
with cancelled/deleted repair, approved final prompt, exactly two simulated API
calls with a review gate and source-backed editor result, a narrow mobile layout,
back-navigation draft preservation and automatic result pagination. All 5 native
Linux integration tests passed, including the new complete wizard → editor flow.
Paid AI APIs were not called. Script syntax/help and clean, changed, existing-tag,
unrelated-file and conflicting-tag paths were checked using fake Git/gh commands
in a temporary directory; no repository refs or remote services were changed.

`.git` is mounted read-only for this session. Changes are preserved in the worktree;
no commit/push/publication was attempted. The exact manual commit is:

```sh
git add README.md docs/AI_CONNECTION_GUIDE.md docs/CATALOG_TEXT_INSTRUCTIONS.md docs/PROJECT_STATE.md integration_test/app_test.dart lib/data/catalog_text.dart lib/features/ai_connection_guide.dart lib/features/ai_page.dart lib/features/catalog_text_page.dart pubspec.yaml scripts/publish_release.sh test/ai_connection_guide_test.dart test/ai_wizard_test.dart test/catalog_text_test.dart
git commit -m "feat: guide AI level creation through batch catalog review"
```

Recommended user handoff (performs commit, tag, push and publication together):

```sh
bash scripts/publish_release.sh
```

Finish after final Android/Linux builds. Do not restart the improvement loop.

Final checks for this milestone: `dart format .`, `flutter analyze --no-pub`,
`git diff --check` and shell syntax checks passed. Android release APK (62.3 MB)
and Linux release archive were rebuilt from the final sources. Both contain the
current batch instructions and byte-identical catalog asset. Artifacts:
`build/app/outputs/flutter-apk/app-release.apk` and
`dist/slepamapa-linux-x64.tar.gz`. Linux executable permissions were checked;
native test app has exited. Android runtime and Windows remain untested here.
Work is complete; no remote release was published by the agent. User can now run
`bash scripts/publish_release.sh` to commit/tag/publish the verified milestone.
