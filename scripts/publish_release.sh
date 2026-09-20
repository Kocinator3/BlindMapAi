#!/usr/bin/env bash
set -euo pipefail

# Publish the reviewed AI wizard milestone. Run manually; Codex does not push it.
# Explicit paths prevent accidentally committing unrelated work or credentials.
cd "$(dirname "$0")/.."
tag=v0.1.4
if [[ "${1:-}" == --help ]]; then
  printf '%s\n' 'Usage: bash scripts/publish_release.sh' \
    'Commits the AI wizard changes, pushes main and v0.1.4, then publishes APK and Linux.'
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
[[ "$(awk '/^version:/ {print $2}' pubspec.yaml)" == 0.1.4+5 ]] || fail 'Expected app version 0.1.4+5.'

paths=(
  README.md docs/AI_CONNECTION_GUIDE.md docs/CATALOG_TEXT_INSTRUCTIONS.md
  docs/PROJECT_STATE.md integration_test/app_test.dart lib/data/catalog_text.dart
  lib/features/ai_connection_guide.dart lib/features/ai_page.dart
  lib/features/catalog_text_page.dart pubspec.yaml scripts/publish_release.sh
  test/ai_connection_guide_test.dart test/ai_wizard_test.dart test/catalog_text_test.dart
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
  git commit -m "feat: guide AI level creation through batch catalog review"
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
