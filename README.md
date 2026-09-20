# SlepáMapa

Offline geography learning in Flutter for Linux, Android and Windows. Play bundled maps, draw answers, review scores, create levels visually, exchange validated JSON, and optionally author with a compatible AI provider.

This repository is an early working implementation, not a completed release candidate. See [project state](docs/PROJECT_STATE.md) and [known issues](docs/KNOWN_ISSUES.md) for exact validation and remaining work.

## Linux development
Install Flutter stable 3.47.4 and add its `bin` directory to PATH. Install native development dependencies (Ubuntu/Debian: `clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev`; Arch: `clang cmake ninja pkgconf gtk3`). Setup never runs sudo automatically.

```bash
./scripts/setup_linux.sh
./scripts/run_linux.sh
# equivalent:
flutter pub get
flutter run -d linux
```

Build and package:

```bash
./scripts/package_linux.sh
# If Flutter is not on PATH:
FLUTTER_BIN=/path/to/flutter/bin/flutter ./scripts/package_linux.sh
```

Extract the entire `dist/slepamapa-linux-x64.tar.gz` archive and run `./slepa_mapa`. Keep its `lib` and `data` directories beside the executable. Requires a compatible Linux desktop with GTK 3. This is a tar bundle, not a self-contained AppImage.

## Android
Install Android Studio / Android SDK, run `flutter doctor`, and accept SDK licenses with `flutter doctor --android-licenses`.

```bash
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. Current builds use Flutter's development signing configuration; configure a private release keystore before public distribution. Never commit keystores or signing passwords.

## Windows
On Windows 10/11 install Flutter and Visual Studio with **Desktop development with C++**, then:

```powershell
flutter pub get
flutter build windows --release
```

Distribute all of `build/windows/x64/runner/Release/`, including `slepa_mapa.exe`, DLLs and data. Windows binaries cannot be built by the Linux host.

## GitHub Release (Linux host)

`scripts/release.sh` runs analysis/tests, builds a fresh Android APK and Linux x64
archive, adds SHA-256 checksums, and uploads them with GitHub CLI (`gh`).
Requires the Android and Linux build prerequisites above and `gh auth login`.
Commit all changes first, including the desired version in `pubspec.yaml`.
Then create and push a tag pointing to that commit:

```bash
git tag v0.1.0
git push origin tag v0.1.0
FLUTTER_BIN=/path/to/flutter/bin/flutter bash scripts/release.sh v0.1.0 --prerelease
```

This publishes immediately. Add `--draft` to upload a draft instead. The script
does not push Git refs and refuses a dirty checkout, a remote tag that does not
point to HEAD, or an existing release. It uses the `origin` repository explicitly.
Assets are also saved in `dist/<tag>/`. Windows binaries need a separate Windows
build. Android still uses development signing as described above.
If an upload fails after creating a release, inspect its draft/assets on GitHub;
the script intentionally does not overwrite or delete an existing release.
CLI options: [gh release create manual](https://cli.github.com/manual/gh_release_create).

## Play and author
Choose a pack and mode. On desktop, click to place points or river vertices; drag beyond 6 logical pixels to pan. For polygon/freehand/circle answers, drag to draw an area; hold Space or the middle mouse button to pan temporarily. The wheel zooms. On touch devices, trace lines/areas with one finger and pan/zoom with two fingers. Polygon vertex clicks remain available for authoring. Confirm reveals the reference (orange squares) beside your attempt (blue circles). Ctrl+Z undoes, Ctrl+Y or Ctrl+Shift+Z redoes, Escape cancels back to Draw, and Delete clears.

My Levels → Create level → Add question opens the visual map editor. Preview plays without changing progress. Save validates geometry. JSON provides import, clipboard exchange, desktop file export and Android document export. Content language is separate from the UI language.

In the level editor, **Choose rivers, lakes and cities** opens the offline catalog.
Search names (including some Czech aliases), country or ID; filter by type; check
objects and inspect the map preview. Apply adds one question per checked part:
cities as points, rivers as lines and lakes as exterior polygons. Mountains keep
the existing polygon editor. The lake layer has its own visibility toggle.
River segments and separate lake parts remain separate. Long geometries are
simplified to 500 vertices; lake islands are visible but not subtracted in scoring.

The AI page uses the same selector. Check the desired objects **before copying
the prompt or generating**; the prompt includes their names, IDs, types and
centers. AI returns `catalogId` references and localized question text. API
responses and JSON imports resolve references from bundled data before canonical
validation; any AI geometry for those references is replaced. Unknown/duplicate
IDs open a repair dialog with suggestions, manual selection and deletion. Nothing
is substituted automatically. API generation requires the checked selection unless
the author explicitly repairs it.
**Create from selection without AI** opens the same source-backed draft offline.
Saved/exported Level v1 JSON always embeds full geometry, with no lookup required.

AI is optional. Copy prompt works without a connection. API generation sends concepts, the checked catalog list and the schema only when requested. Use the provider’s HTTPS compatible base URL, or an HTTP loopback endpoint for a local model. Keys live only in memory for the open settings page. Responses are bounded, parsed, validated and marked unverified before review.

The **Connect AI via API** button provides offline Czech/English tutorials and
endpoint presets for OpenAI, Gemini, Claude, DeepSeek and local Ollama; see the
[connection guide](docs/AI_CONNECTION_GUIDE.md). Applying a preset clears the old
model and key without sending a request.

**Text selection with AI** provides a bounded search → results → selection
protocol, with stable ordering and explicit disambiguation. Copy the bundled
[instructions](docs/CATALOG_TEXT_INSTRUCTIONS.md) to a chat, process its JSON
queries locally and return the actual results. Only IDs offered in this session
can be selected without manual approval. AI must include human-readable `userText`
and `catalogText` alternatives. Source-provided Wikidata/Natural Earth identifiers
and country codes help lookup; unique `catalogId` still identifies the geometry.

## Checks and CI

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d linux
```

Native integration tests require a display (or `xvfb-run -a`). GitHub Actions runs quality checks and native Linux, Windows and APK jobs; tags beginning `v` also generate downloadable workflow artifacts. It does not publish a GitHub Release. No remote action has been performed by the local implementation task.

Software: MIT. Offline map: Natural Earth, public domain. See [data sources](docs/DATA_SOURCES.md). Flutter's in-app Licenses screen includes dependency licenses.
