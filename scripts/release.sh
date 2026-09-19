#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/release.sh v0.1.0 [--draft] [--prerelease]

Build Android APK and Linux x64 bundle, then upload a GitHub Release via gh.
Run on Linux x64 with Flutter, Android SDK, Linux build tools and gh installed.
First commit your changes, create the tag at HEAD and push it to origin.
The tag must already exist on origin and point to HEAD. Nothing is git-pushed.
Use FLUTTER_BIN=/path/to/flutter if Flutter is not on PATH.
Without --draft the release is published immediately.
EOF
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  exit 0
fi
[[ $# -ge 1 ]] || { usage >&2; exit 1; }
tag="$1"
shift
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]] || fail 'Expected a version tag, e.g. v0.1.0 or v0.1.0-beta.1.'
release_flags=()
for option in "$@"; do
  case "$option" in
    --draft|--prerelease) release_flags+=("$option") ;;
    *) fail "Unknown option: $option" ;;
  esac
done

cd "$(dirname "$0")/.."
export FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
for tool in git gh "$FLUTTER_BIN" tar sha256sum; do
  command -v "$tool" >/dev/null || fail "Missing command: $tool"
done
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail 'Build on Linux x64.'
[[ -z "$(git status --porcelain)" ]] || fail 'Commit or stash local changes before releasing.'
commit="$(git rev-parse HEAD)"
repo="$(git remote get-url origin)"
gh auth status
remote_tags="$(git ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}")"
remote_commit="$(printf '%s\n' "$remote_tags" | awk -v ref="refs/tags/$tag" '$2 == ref { direct = $1 } $2 == ref "^{}" { peeled = $1 } END { print peeled ? peeled : direct }')"
[[ "$remote_commit" == "$commit" ]] || fail "Push tag $tag pointing to HEAD to origin first."
if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  fail "Release $tag already exists; it will not be overwritten."
fi

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" analyze --no-pub
"$FLUTTER_BIN" test --no-pub
"$FLUTTER_BIN" build apk --release
bash scripts/package_linux.sh
[[ "$(git rev-parse HEAD)" == "$commit" && -z "$(git status --porcelain)" ]] || fail 'Sources changed during the build; commit changes and retry with the matching tag.'

output_dir="dist/$tag"
mkdir -p "$output_dir"
apk="slepamapa-$tag-android.apk"
linux="slepamapa-$tag-linux-x64.tar.gz"
cp build/app/outputs/flutter-apk/app-release.apk "$output_dir/$apk"
cp dist/slepamapa-linux-x64.tar.gz "$output_dir/$linux"
(
  cd "$output_dir"
  sha256sum "$apk" "$linux" > SHA256SUMS
)

gh release create "$tag" \
  "$output_dir/$apk" "$output_dir/$linux" "$output_dir/SHA256SUMS" \
  --repo "$repo" --verify-tag --title "SlepáMapa $tag" --generate-notes \
  "${release_flags[@]}"
