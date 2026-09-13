## RESUME HERE
Continue the implementation toward the full requested release candidate. Flutter SDK is at /tmp/slepamapa-flutter (3.47.4); use that absolute path until installed permanently. Desktop map input now uses a 6 logical-pixel click-vs-drag threshold: clicks place/select, ordinary drags pan, freehand and vertex-move retain intentional drawing/editing drags, and Space+left/middle drag pans. Area gameplay is now derived from `freehandArea` and `circle` answer types, with closed polygon answers and type-specific hints. Next audits should remain low-risk until GPT-6 Astra resumes larger GIS/product work.

## Implemented features
- Flutter Android/Linux/Windows scaffolds; responsive home, levels, statistics, settings and light/dark Czech/English UI.
- Bundled public-domain Natural Earth country polygons, no labels or online tiles.
- Six answer types, geodesic point scoring, sampled bidirectional line scoring, regional area overlap and multipoint assignment.
- Map navigation/drawing, vertex add/move/delete, circle/freehand, undo/redo and keyboard shortcuts.
- Practice/learning/challenge flows, feedback, explanations, per-question results, local XP/highscores/streak and mistake review.
- Validated immutable level models, v0→v1 migration, bounded JSON imports, four demo packs.
- Visual level/question editor and preview; JSON formatting/validation/clipboard and desktop file exchange.
- Optional copy-AI-prompt and compatible HTTP API authoring with cancellation, bounds, timeout and mandatory unverified review. Keys are session-only.
- Local serialized save queue, flushed writes, backup and corrupt-file preservation.
- Native CI jobs, setup/run/package scripts, MIT license and data provenance.
- Desktop mouse click-vs-drag interaction with centralized threshold, cursor feedback, automatic panning and focused widget tests; mobile touch interaction remains on the existing scale gesture path.
- Gameplay interaction now derives from answer type: point/polyline placement uses click-vs-drag panning, while freehand-area and circle questions use left-drag area drawing, Space+left or middle drag panning, closed polygon conversion, and dynamic instructions. Question transitions reset transient map gesture/drawing state through keyed map instances and widget updates.

## Build status
Linux release rebuilt successfully after the area interaction fix: `build/linux/x64/release/bundle/slepa_mapa`.
Android release APK built successfully: build/app/outputs/flutter-apk/app-release.apk (55.1 MB, development signing). Windows requires a Windows runner; CI has not run remotely.
Latest Linux test artifact: `dist/slepamapa-linux-x64.tar.gz` (11 MB), containing the rebuilt GTK bundle and executable. The packaging script supports `FLUTTER_BIN=/path/to/flutter`; this session refreshed the archive directly because dependency refresh could not reach pub.dev.

## Last successful tests
2026-09-13: dart format clean; flutter analyze: no issues; focused `flutter test test/drawing_test.dart test/domain_test.dart --no-pub` passed 30 tests, covering point/polyline/area gestures, Space-pan suppression, transitions, and bundled mountain geometry invariants. A subsequent full-suite attempt was blocked by the restricted sandbox (Flutter test server could not bind a loopback socket); dependency refresh also could not reach pub.dev. Earlier full suite had 28 passing tests and integration_test had 2 passing native flows.

## Blockers
 No product release blocker established yet. SDK is temporary. Sandbox needs elevated Flutter access for global caches. The requested focused commit is still not possible in this session: `.git` and `.git/index` are not writable, and a harmless `.git/.codex_write_probe` returns `Read-only file system`. No ownership, mode, sudo, or destructive workaround was attempted. All source changes remain recoverable in the worktree.

## Current priority
Keep low-risk quality work focused on desktop/mobile interaction polish, accessibility, localization, CI and documentation. Do not claim the complete release candidate; see KNOWN_ISSUES.md.

## Latest desktop interaction milestone
Implemented and tested automatic desktop click-vs-drag behavior in `MapCanvas`: 6 px threshold, click placement/selection, continuous pan after threshold, release suppression, wheel zoom preservation, cursor feedback, freehand left-drag retention, Move-vertex drag retention, and Space+left/middle temporary pan. Fixed the area interaction branch so both `freehandArea` and `circle` questions draw closed areas, while temporary pan never creates answer geometry. Added transition tests for Point→Area, Area→Area, and Area→Point plus bundled Czech mountain data invariants. Commit remains pending because Git storage is read-only in this session.

## Exact uncommitted state
`git status --short` reports modified release/application files plus new `android/app/src/main/res/xml/`, `integration_test/`, `lib/features/unsaved_guard.dart`, `test/ai_http_test.dart`, `test/drawing_test.dart`, and `test/fixtures/`. `git diff --check` is clean. The focused desktop change is in `lib/map/map_canvas.dart`, with tests in `test/drawing_test.dart`; this tree also contains the earlier uncommitted release milestone and should be reviewed as one batch before committing.

When Git is writable, inspect and commit manually with:

```bash
git status --short
git diff --check
git add lib/map/map_canvas.dart test/drawing_test.dart docs/PROJECT_STATE.md docs/ARCHITECTURE.md docs/KNOWN_ISSUES.md
git commit -m "fix: pan desktop map only after drag threshold"
```

For the newer area interaction fix, include `lib/features/gameplay.dart` and `test/domain_test.dart` in the add command as well (the repository contains earlier uncommitted work in the same files).

The focused regression check currently passes: `flutter test test/drawing_test.dart test/domain_test.dart --no-pub` → 30 tests passed. A fresh full-suite run requires a less restricted Flutter test environment because this session cannot bind the test server socket.

## Unfinished tasks
See KNOWN_ISSUES.md and ROADMAP.md. First complete version criteria are NOT yet fully met. Do not call this a completed release.
