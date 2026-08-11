#!/usr/bin/env bash
# FixMyVibe one-line bootstrap (macOS / Linux).
#
# Install into every detected agent:
#   curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | bash
#
# Force all three agents (create dirs even if not detected):
#   curl -fsSL https://raw.githubusercontent.com/AnasNafees1802/FixMyVibe/main/bootstrap.sh | ALL=1 bash
#
# Downloads the repo to a temp folder, runs skills/fixmyvibe/install.sh, then cleans up.
set -euo pipefail

REPO="https://github.com/AnasNafees1802/FixMyVibe.git"
BRANCH="${FIXMYVIBE_BRANCH:-main}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== FixMyVibe bootstrap =="
if command -v git >/dev/null 2>&1; then
  echo "Cloning $REPO ($BRANCH) ..."
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$TMP" >/dev/null 2>&1
  ROOT="$TMP"
else
  echo "git not found - downloading tarball ..."
  curl -fsSL "https://codeload.github.com/AnasNafees1802/FixMyVibe/tar.gz/refs/heads/$BRANCH" | tar -xz -C "$TMP"
  ROOT="$TMP/FixMyVibe-$BRANCH"
fi

INSTALLER="$ROOT/skills/fixmyvibe/install.sh"
[ -f "$INSTALLER" ] || { echo "installer not found at $INSTALLER" >&2; exit 1; }

chmod +x "$INSTALLER" 2>/dev/null || true
( cd "$ROOT/skills/fixmyvibe" && ALL="${ALL:-0}" AGENTS="${AGENTS:-}" bash ./install.sh )
