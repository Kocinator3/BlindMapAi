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
Fix authored-content preservation: visual level save loses tags/difficulty; draft guards miss description-only/question-detail changes and JSON drafts. Then audit concurrent mutation/save failures and area-scoring edge cases. Preserve existing recovery validation, provider allowlist, multipart preservation and strict schema.

## Platform/release limits
Only Linux is connected. Android/Windows runtime behavior remains unverified. Previous release artifacts predate this review; rebuild before distribution. Production Android signing, Windows builds, accessibility/localization and source-backed teaching geography remain open. The SDK in /tmp may be cleaned by the OS.

## Git workflow
Commit focused verified milestones locally; do not push. If a future sandbox makes Git read-only, preserve all work and document exact manual git add/commit commands. No current Git permission blocker exists.
