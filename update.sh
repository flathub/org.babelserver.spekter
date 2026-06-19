#!/usr/bin/env bash
# Update this Flathub manifest + cargo-sources.json to a tagged Spekter release.
# Usage: ./update.sh <version>     e.g.  ./update.sh 1.2.4
#
# Uses `uv` (https://docs.astral.sh/uv/) to run flatpak-cargo-generator.py
# with its Python deps in an ephemeral environment, so the host's Python
# install is irrelevant. `uv` is auto-installed into ~/.local/bin on the
# first run if it's not already on PATH.
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

# 2. Make sure uv is available. One-time install (~10 MB binary, no sudo).
if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found -- installing into ~/.local/bin (one-time)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    command -v uv >/dev/null 2>&1 || {
        echo "uv install failed. See https://docs.astral.sh/uv/getting-started/installation/" >&2
        exit 1
    }
fi

# 3. Regenerate cargo-sources.json. uv pulls in a managed Python plus
#    aiohttp/PyYAML/tomlkit into a throwaway env for this one command;
#    nothing leaks into the system Python or sticks around between runs.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://gitlab.com/hallyhaa/spekter/-/raw/$TAG/Cargo.lock" -o "$tmp/Cargo.lock"
curl -fsSL "https://raw.githubusercontent.com/flatpak/flatpak-builder-tools/master/cargo/flatpak-cargo-generator.py" -o "$tmp/gen.py"
uv run --quiet --with aiohttp --with PyYAML --with tomlkit -- \
    python "$tmp/gen.py" "$tmp/Cargo.lock" -o "$HERE/cargo-sources.json"

# 4. Point the manifest's git source at the new tag/commit.
sed -i -E "s|^( *tag: ).*|\1$TAG|; s|^( *commit: ).*|\1$COMMIT|" "$MANIFEST"

echo "Updated manifest + cargo-sources.json for $TAG. Review, build-test, commit, push, PR."
