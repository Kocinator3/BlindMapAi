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

## Play and author
Choose a pack and mode. Switch to Navigate to pan or zoom, then Draw to answer. Tap for points/polygon vertices; drag for rivers, freehand areas and circles. Confirm reveals the reference (orange squares) beside your attempt (blue circles). Ctrl+Z undoes, Ctrl+Y or Ctrl+Shift+Z redoes, Escape switches to navigation, Delete clears.

My Levels → Create level → Add question opens the visual map editor. Preview plays without changing progress. Save validates geometry. JSON provides import, clipboard exchange, desktop file export and Android document export. Content language is separate from the UI language.

AI is optional. Copy prompt works without a connection. API generation sends concepts and the schema only when requested. Use an HTTPS compatible `/v1` base URL, or an HTTP loopback endpoint for a local model. Keys live only in memory for the open settings page. Responses are bounded, parsed, validated and marked unverified before review.

## Checks and CI

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d linux
```

Native integration tests require a display (or `xvfb-run -a`). GitHub Actions runs quality checks and native Linux, Windows and APK jobs; tags beginning `v` also generate downloadable workflow artifacts. It does not publish a GitHub Release. No remote action has been performed by the local implementation task.

Software: MIT. Offline map: Natural Earth, public domain. See [data sources](docs/DATA_SOURCES.md). Flutter's in-app Licenses screen includes dependency licenses.
