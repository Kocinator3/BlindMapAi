# Project state — 2026-09-13 senior review

## Resume here
Read AGENTS.md, this file, ROADMAP.md, KNOWN_ISSUES.md, Git status/diff and recent history. Flutter/Dart are at `/tmp/slepamapa-flutter/bin/` (not on PATH). This is a pre-release.

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
Audit small-screen/large-text gameplay and direct settings-save failure handling. Desktop polygon follow-up is `48108ce`, authoring is `38f0fdc`, concurrency is `f26e239`. Preserve existing recovery validation, provider allowlist, multipart preservation and strict schema.

## Area fairness milestone
Reproduced exact thin concave regions scoring zero and replaced fixed-grid sampling with projected polygon cross-section intersection. Seven tests cover thin/nested/reversed rings, slanted crossings, 200 analytical rectangles, near-capacity concave symmetry and antimeridian/high-latitude cases. The projection and sqrt(IoU) curve are unchanged; historical results are not rescored. Format/analyze clean; 64 tests and 3 Linux native flows pass. Linux release rebuilt successfully at `build/linux/x64/release/bundle/slepa_mapa`.

## Persistence concurrency milestone
Serialize authored put/delete/record mutations through persistence and rollback, not just filesystem writes. Four failing regressions reproduced rollback erasing a later put, resurrecting a deleted level, lost duplicate retries and cross-level record collisions. Five tests now cover those cases and durable reload after a failed write. Record identity includes level/session/question. Format/analyze clean; 57 tests and 3 Linux native flows pass. Direct public settings mutations are not transactional and remain a follow-up boundary.

## Authoring preservation milestone
Complete draft snapshots protect level descriptions/settings, question details/geometry and JSON text. Unchanged imported seeds still require saving or explicit discard. Visual save and JSON Apply preserve level ID, tags and difficulty. Six regression tests cover loss reproduction, reversion, import guarding and canonical JSON-to-visual save. Format/analyze clean; 51 tests and 3 Linux native flows pass. Interaction milestone is committed as `0d45a8f`.

## Platform/release limits
Only Linux is connected. Android/Windows runtime behavior remains unverified. Linux release bundle includes the reviewed changes; the old dist archive and APK predate them. Production Android signing, Windows builds, accessibility/localization and source-backed teaching geography remain open. The SDK in /tmp may be cleaned by the OS.

## Git workflow
Commit focused verified milestones locally; do not push. If a future sandbox makes Git read-only, preserve all work and document exact manual git add/commit commands. No current Git permission blocker exists.
