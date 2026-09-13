# Known issues

The repository is a working pre-release, not completion of every requested feature.

- Android APK compiles, but Android runtime/file export has not been device-tested. Windows is configured in CI but has not been built in this environment. CI has not been executed remotely.
- Mountain outlines are approximate authored teaching regions requiring source-backed review. Rivers now use generalized Natural Earth lines with documented concatenation/clipping; exact springs are omitted. City references need a complete citation pass.
- Schema v1 intentionally rejects Polygon holes/MultiPolygon and unknown fields. Only country outlines are available as map layers; per-question map overrides and full viewport/property controls remain unfinished.
- Visual multipart line editing preserves other parts but edits only the first part; use JSON for additional parts.
- Area scoring uses a regional approximation (target extent at most 3500 km). Thin/tiny, high-latitude, antimeridian and large-area scenarios need deeper fairness testing.
- Pointer tools and keyboard undo/redo/cancel/clear work; fully keyboard-only geometry placement, richer semantics and large-text/landscape accessibility remain unfinished.
- Desktop ordinary mouse clicks now place/select and drags pan after a centralized 6 px threshold. Freehand and vertex-move retain intentional drag editing; Space+left or middle drag pans during those tools. This interaction is widget-tested, but native Windows pointer behavior still needs a Windows runner check.
- Czech/English principal UI is implemented; some enum labels, validation errors and explanatory text are still English/bilingual rather than fully localized through a centralized catalog.
- API keys are session-only, never persisted. Optional secure OS vault storage is not implemented. Real hosted/local model compatibility needs user-configured endpoint testing; a loopback mock HTTP server is tested.
- Practice and learning share feedback behavior. Challenge has timer/combo but no combo reward. Highscores currently aggregate each session's recorded answers, including partial sessions. More complete progress dashboards remain unfinished.
- Windows save replacement has a primary-file gap guarded by a backup; no native Windows crash-recovery test yet. Deep concurrent mutation/failure stress tests remain open.
- Linux distribution is a GTK-dependent tar bundle, not an AppImage. Android APK uses development signing, unsuitable for a production store release.
- Flutter and writable Android SDK live in /tmp and may be removed by system cleanup. Install them permanently for ongoing development.

## Resolved audits
- Authoring preservation: visual saves retain level metadata, JSON Apply retains all canonical level fields, and full draft snapshots protect description/question-detail/JSON-only edits. Unchanged imported levels are still guarded.
- Senior review: river traces remain open, polygon drags draw areas, two-finger gestures discard drafts until all fingers lift, and cancellation/type changes reset transient state. Tests cover actual pan/zoom and full question/mountain transitions.
- Old project-memory Git/test-sandbox blockers were stale; the review started from a clean writable checkout and Linux native integration runs.
- Semantically corrupt primary no longer replaces a valid backup; corrupt data preserved separately.
- API settings serialize an explicit allowlist, excluding credentials even if accidentally added to the map.
- Multipart edits preserve untouched parts and question tags/difficulty.
- Text-only drafts require discard confirmation; JSON Apply returns to editing instead of dropping changes.
- Freehand/line/area/circle gesture submit flows have widget coverage.
- Country paths are cached, avoiding repeated projection/allocation of the entire dataset while drawing.
- CI Linux tar preserves executable permissions; artifact names use commit hashes, avoiding PR ref slashes.
