#!/usr/bin/env bash
# Update this Flathub manifest + cargo-sources.json to a tagged Spekter release.
# Usage: ./update.sh <version>     e.g.  ./update.sh 1.2.3
set -euo pipefail
VER="${1:?usage: ./update.sh <version>}"
TAG="v$VER"
REPO_URL="https://gitlab.com/hallyhaa/spekter.git"
MANIFEST="org.babelserver.spekter.yaml"
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"

# 1. Resolve the commit the (annotated) tag points to.
COMMIT="$(git ls-remote "$REPO_URL" "refs/tags/$TAG^{}" | awk '{print $1}')"
[ -n "$COMMIT" ] || { echo "tag $TAG not found on $REPO_URL" >&2; exit 1; }
echo "$TAG -> $COMMIT"

# 2. Regenerate cargo-sources.json from that tag's Cargo.lock.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://gitlab.com/hallyhaa/spekter/-/raw/$TAG/Cargo.lock" -o "$tmp/Cargo.lock"
curl -fsSL "https://raw.githubusercontent.com/flatpak/flatpak-builder-tools/master/cargo/flatpak-cargo-generator.py" -o "$tmp/gen.py"
python3 -m venv "$tmp/venv"
"$tmp/venv/bin/pip" -q install aiohttp PyYAML tomlkit
"$tmp/venv/bin/python" "$tmp/gen.py" "$tmp/Cargo.lock" -o "$HERE/cargo-sources.json"

# 3. Point the manifest's git source at the new tag/commit.
sed -i -E "s|^( *tag: ).*|\1$TAG|; s|^( *commit: ).*|\1$COMMIT|" "$MANIFEST"

echo "Updated manifest + cargo-sources.json for $TAG. Review, build-test, commit, push, PR."
