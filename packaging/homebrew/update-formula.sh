#!/usr/bin/env bash
# Updates the Homebrew formula with SHA256s from a GitHub release.
# Usage: ./update-formula.sh v0.1.0
set -euo pipefail

VERSION="${1:?Usage: $0 <version-tag>}"
REPO="lightsaway/eyes"
VER="${VERSION#v}"
FORMULA="packaging/homebrew/eyes.rb"

echo "Updating formula for $VERSION..."

update_sha() {
  local asset="$1" placeholder="$2"
  local url="https://github.com/$REPO/releases/download/$VERSION/$asset"
  echo "  Fetching $asset..."
  local sha
  sha=$(curl -sL "$url" | shasum -a 256 | cut -d' ' -f1)
  sed -i '' "s/$placeholder/$sha/" "$FORMULA"
  echo "  $placeholder -> $sha"
}

# Update version
sed -i '' "s/version \".*\"/version \"$VER\"/" "$FORMULA"

update_sha "eyes-macos-arm64.tar.gz"    "PLACEHOLDER_ARM64_SHA256"
update_sha "eyes-linux-x86_64.tar.gz"   "PLACEHOLDER_LINUX_X86_64_SHA256"
update_sha "eyes-linux-aarch64.tar.gz"  "PLACEHOLDER_LINUX_AARCH64_SHA256"

echo "Done. Copy $FORMULA to your homebrew-eyes tap repo."
