#!/usr/bin/env bash
set -euo pipefail

# Publish the full-course rivers and map/scoring milestone. Run manually.
# Explicit paths prevent accidentally committing unrelated work or credentials.
cd "$(dirname "$0")/.."
tag=v0.1.5
if [[ "${1:-}" == --help ]]; then
  printf '%s\n' 'Usage: bash scripts/publish_release.sh' \
    'Commits map/scoring changes, pushes main and v0.1.5, then publishes APK and Linux.'
  exit 0
fi
[[ $# == 0 ]] || { printf '%s\n' 'Run without arguments, or use --help.' >&2; exit 1; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  if command -v flutter >/dev/null; then
    FLUTTER_BIN=flutter
  elif [[ -x /tmp/slepamapa-flutter/bin/flutter ]]; then
    FLUTTER_BIN=/tmp/slepamapa-flutter/bin/flutter
  else
    fail 'Set FLUTTER_BIN to the Flutter executable.'
  fi
fi
export FLUTTER_BIN
for tool in git gh "$FLUTTER_BIN"; do
  command -v "$tool" >/dev/null || fail "Missing command: $tool"
done
[[ "$(git branch --show-current)" == main ]] || fail 'Switch to main before publishing.'
[[ "$(awk '/^version:/ {print $2}' pubspec.yaml)" == 0.1.5+6 ]] || fail 'Expected app version 0.1.5+6.'

paths=(
  README.md assets/maps/catalog.json assets/maps/context.json
  docs/CATALOG_TEXT_INSTRUCTIONS.md docs/ARCHITECTURE.md docs/DATA_SOURCES.md
  docs/KNOWN_ISSUES.md docs/PROJECT_STATE.md docs/level.schema.json
  integration_test/app_test.dart lib/data/ai_service.dart lib/data/catalog_text.dart
  lib/data/feature_catalog.dart lib/domain/geo.dart lib/domain/level.dart
  lib/domain/map_detail.dart lib/domain/scoring.dart lib/features/catalog_picker.dart
  lib/features/editor.dart lib/features/catalog_text_page.dart lib/map/map_canvas.dart pubspec.yaml
  scripts/build_context_map.py scripts/publish_release.sh
  test/ai_wizard_test.dart test/area_fairness_test.dart test/catalog_test.dart
  test/catalog_text_test.dart test/domain_test.dart test/map_context_test.dart
)
while IFS= read -r entry; do
  path="${entry:3}"
  allowed=false
  for expected in "${paths[@]}"; do
    if [[ "$path" == "$expected" ]]; then allowed=true; break; fi
  done
  [[ "$allowed" == true ]] || fail "Unrelated change: $path. Commit or set it aside separately first."
done < <(git status --porcelain --untracked-files=all)

# Retry is safe after a successful commit/tag/push; never move an existing tag.
if git show-ref --verify --quiet "refs/tags/$tag"; then
  [[ "$(git rev-parse "$tag^{commit}")" == "$(git rev-parse HEAD)" ]] || fail "$tag points to another commit. It will not be moved."
  [[ -z "$(git status --porcelain)" ]] || fail "$tag already exists, but sources changed. Use a new release version."
fi
gh auth status || gh auth login
for path in "${paths[@]}"; do
  if [[ -e "$path" ]] || git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    git add -A -- "$path"
  fi
done
if ! git diff --cached --quiet; then
  git commit -m "fix: use whole river courses and forgiving map scoring"
else
  printf '%s\n' 'Changes are already committed; continuing to tag and release.'
fi
[[ -z "$(git status --porcelain)" ]] || fail 'Worktree changed during commit. Inspect it before retrying.'
if ! git show-ref --verify --quiet "refs/tags/$tag"; then
  git tag -a "$tag" -m "SlepáMapa $tag"
fi
git push --atomic origin main "refs/tags/$tag"
repo="$(git remote get-url origin)"
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  printf '%s\n' 'Release already exists; it will not be overwritten.'
  gh release view "$tag" --repo "$repo"
  exit 0
fi
bash scripts/release.sh "$tag"
