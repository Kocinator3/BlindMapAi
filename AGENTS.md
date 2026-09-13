# SlepáMapa / blind-map-ai

Persistent instructions for Codex sessions working on this repository.

## Project rules

- This is a Flutter/Dart geography learning game targeting Android, Linux, and Windows.
- Keep the product offline-first. Core gameplay, bundled levels, level authoring, imports/exports, progress, and scoring must work without AI, API keys, login, a server, or internet access.
- Use one canonical, versioned Level JSON model for bundled content, the visual editor, imports, exports, and AI-generated drafts. Validate and migrate JSON before constructing domain models.
- Derive gameplay interaction from the question `answerType` and geometry type. Never branch on question index, title, level name, or ID.
  - `POINT`: short click places the answer; desktop drag pans.
  - `POLYLINE`: line/river interaction adds or draws a line appropriately.
  - `POLYGON`, `FREEHAND_AREA`, and `ROUGH_REGION`: draw or mark an area; desktop Space + drag may temporarily pan.
- Reset transient pointer, pan, draft, selection, undo/redo, and gesture state when questions or interaction types change. Never let stale state leak between questions.
- Preserve both desktop and mobile behavior, including mouse-wheel zoom, keyboard shortcuts, touch gestures, and accessible controls.
- Keep GIS coordinate conversion, validation, geometry, and scoring isolated from Flutter UI. Serialized GeoJSON coordinates are `[longitude, latitude]`.
- Keep AI optional and authoring-only. Compatible API support must remain provider-agnostic, must not persist or log secrets, and must mark generated geography unverified until reviewed.
- Keep JSON validation errors readable and actionable. Reject malformed, oversized, out-of-range, or semantically incompatible input without crashing.
- Prefer focused, low-risk changes over unnecessary architectural rewrites. Add regression tests for bugs and preserve valid existing work in a dirty checkout.
- After changes, run `dart format .`, `flutter analyze`, and relevant `flutter test` commands. Run integration tests or native builds when the change affects them.
- Never use `sudo`, `chmod 777`, `chown`, unsafe permission workarounds, or destructive Git commands to bypass the sandbox. Never commit API keys, credentials, signing material, or other secrets.
- If `.git` is read-only, leave source changes safely in the worktree, update `docs/PROJECT_STATE.md` with the exact state and manual `git add`/`git commit` commands, and do not retry pointlessly.
- Maintain `docs/PROJECT_STATE.md` as current project memory. Before major work inspect it, the current `git status`, and the current diff; after stable milestones update the project documentation.
- Continue autonomously on authorized work rather than repeatedly asking whether to proceed. When a stronger model returns after Luna work, review recent Luna changes, tests, and uncommitted state before major architecture work.

## Resume Protocol

Future Codex sessions should:

1. Read `AGENTS.md`.
2. Read `docs/PROJECT_STATE.md`.
3. Inspect `git status`, `git diff`, and recent history.
4. Run relevant tests before changing behavior.
5. Preserve valid uncommitted work and avoid unrelated rewrites.
6. Continue the highest-priority unfinished task recorded in project memory.

## Continuous Improvement

After the core product works, repeatedly:

`audit → prioritize → implement → test → fix → document → repeat`

Each cycle must address a defensible issue such as correctness, crashes, scoring fairness, interaction, accessibility, performance, persistence, security, localization, test coverage, CI, or packaging. Do not refactor merely to create activity, and do not implement an infinite shell loop.
