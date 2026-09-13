# Project state — 2026-09-13 senior review

## Resume here
Read AGENTS.md, this file, ROADMAP.md, KNOWN_ISSUES.md, Git status/diff and recent history. Flutter/Dart are at `/tmp/slepamapa-flutter/bin/` (not on PATH). The current responsive gameplay milestone is the highest-priority work; this remains a pre-release. The source milestone is complete, but this session's `.git` index is read-only; use the manual commit command below when Git is writable.

## Review scope and starting state
The checkout was clean at `6cdd082`. Git is writable; loopback tests and Linux native integration work without permission workarounds. The prior memory's dirty-tree/sandbox claims were stale.

Git contains no explicit Astra/Luna attribution. Conservatively reviewed all changes after implementation baseline `aee5dfd`: `14ee40a`, `042a04c` and `6cdd082`, plus current map, gameplay, geometry, validation, scoring, persistence, authoring, AI, changed data/schema, platform export, CI, scripts and tests. See REVIEW_2026-09-13.md.

## Interaction milestone
- Retained 6 px desktop click/drag threshold; removed shared cross-device click suppression.
- Polygon/freehand/circle left-drag draws areas; Space/middle pan creates no geometry. Polygon vertex-click authoring remains available.
- Two-finger input discards the draft and latches navigation until all fingers lift. River traces stay open; only area strokes close.
- Type/viewport updates reset tool, draft, selection, mouse/touch gesture fields and history. Gameplay uses a fresh keyed map per question. Read-only transitions cancel input without resetting the viewport.
- Cancellation, Clear and undo abandon active strokes. Closed-ring editing exposes unique vertex handles.
- Mobile area/line hints explain one-finger drawing and two-finger navigation.
- Regression tests check visible drafts, actual pan/zoom, pinch suppression, cancellation, tool/history reset, requested transitions and both bundled mountain questions through confirmation.

## Validation
Baseline: 34 tests passed, but new checks reproduced four failures. Interaction milestone: format clean, analyze clean, 45 tests and 3 Linux native integration flows pass. Native capture inspection additionally exposed the lost first stroke corner, now covered by geometry assertions. See REVIEW_2026-09-13.md.

## Next priority
Audit large-text/small-landscape accessibility, Android document export/lifecycle, and Windows CI execution. Responsive gameplay is the current uncommitted milestone; desktop polygon is `48108ce`, authoring is `38f0fdc`, concurrency is `f26e239`, area fairness is `efcfc6d`.

## Responsive gameplay milestone
Gameplay now uses a compact contextual toolbar distinct from the level editor: POINT exposes Clear and Recenter; area/polyline questions expose Undo, Clear and Recenter. A compact landscape side panel contains progress, prompt, instructions and Confirm while the map occupies the remaining majority of the screen. Portrait uses compact summaries and an Expanded map. Responsive tests cover 360×800 portrait, 800×360 landscape, 600×1000 portrait and 1200×800 desktop, including control visibility, map dimensions and overflow checks. Format/analyze clean; 69 tests and 3 Linux integration flows pass. Android APK and Linux artifacts were rebuilt after this change.

## Settings persistence milestone
Theme, language and provider settings now use a serialized update API with allowlisting and rollback on save failure. AI generation uses the same path and checks cancellation before sending. One regression covers failure rollback and successful secret filtering. This milestone is committed as `2c330c7`.

## Area fairness milestone
Reproduced exact thin concave regions scoring zero and replaced fixed-grid sampling with projected polygon cross-section intersection. Seven tests cover thin/nested/reversed rings, slanted crossings, 200 analytical rectangles, near-capacity concave symmetry and antimeridian/high-latitude cases. The projection and sqrt(IoU) curve are unchanged; historical results are not rescored. Format/analyze clean; 64 tests and 3 Linux native flows pass. Linux release rebuilt successfully at `build/linux/x64/release/bundle/slepa_mapa`.

## Persistence concurrency milestone
Serialize authored put/delete/record mutations through persistence and rollback, not just filesystem writes. Four failing regressions reproduced rollback erasing a later put, resurrecting a deleted level, lost duplicate retries and cross-level record collisions. Five tests now cover those cases and durable reload after a failed write. Record identity includes level/session/question. Settings use the same transactional update path.

## Authoring preservation milestone
Complete draft snapshots protect level descriptions/settings, question details/geometry and JSON text. Unchanged imported seeds still require saving or explicit discard. Visual save and JSON Apply preserve level ID, tags and difficulty. Six regression tests cover loss reproduction, reversion, import guarding and canonical JSON-to-visual save. Format/analyze clean; 51 tests and 3 Linux native flows pass. Interaction milestone is committed as `0d45a8f`.

## Platform/release status
No Android emulator/device is available in this environment. The current release artifacts are `build/app/outputs/flutter-apk/app-release.apk` (55,150,508 bytes, development-signed), `build/linux/x64/release/bundle/slepa_mapa` (24,048 bytes), and `dist/slepamapa-linux-x64.tar.gz` (11,036,947 bytes). The tar package includes LICENSE, README.md and DATA_SOURCES.md. The Linux integration suite passes; direct GUI smoke launch was attempted but this shell has no usable display. Production Android signing, Windows builds, accessibility/localization and source-backed teaching geography remain open. The SDK in /tmp may be cleaned by the OS.

## Manual commit handoff
This session could not create `.git/index.lock` because `.git` is read-only. When the repository is writable, run: `git add docs/ARCHITECTURE.md docs/KNOWN_ISSUES.md docs/PROJECT_STATE.md lib/features/gameplay.dart lib/map/map_canvas.dart test/map_regression_test.dart test/gameplay_responsive_test.dart && git commit -m "fix: make gameplay layout responsive and contextual"`. Do not push automatically.

## Git workflow
Commit focused verified milestones locally; do not push. If a future sandbox makes Git read-only, preserve all work and document exact manual git add/commit commands. No current Git permission blocker exists.
