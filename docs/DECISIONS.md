# Decisions
- 2026-09-13: Start with Flutter/Dart as requested; confirm available toolchain before selecting dependencies.
- Core gameplay must be offline. Prefer bundled open vector geography over online tiles.
- Serialize geographic coordinates exclusively as GeoJSON [longitude, latitude].
- Flutter 3.47.4 stable obtained from official flutter/flutter Git repository. Linux GTK/clang/cmake/ninja and Android SDK available.
- path_provider locates app support storage; file_selector provides native desktop file exchange and Android import. Supported-platform documentation checked on pub.dev. Progress uses flushed JSON with backup rather than shared_preferences, whose durability guarantee is unsuitable for authored levels.
- Natural Earth 50m public-domain country data bundled without name properties. Source and license documented separately.
- Point score: exp(-(distance/tolerance)^1.35). Lines use 160 arc-length samples in each direction and harmonic precision/coverage. Areas use local equirectangular projection and 100x100 target-bbox sampling, analytic attempt area, sqrt(IoU). This is regional educational approximation, not survey precision.
- Compatible provider uses dart:io HttpClient, HTTPS except loopback, no redirects, 2 MiB cap and bounded timeout. API keys are never persisted; optional vault storage is future work.
- CI builds artifacts on native runners and tags, but does not publish releases or modify remotes.
