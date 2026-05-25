#!/bin/sh
# Builds displayswitcher in release mode, bumps the build number, and installs
# it to ~/.local/bin. Run this to (re)deploy locally.
set -e

cd "$(dirname "$0")/.."
INFO="Sources/displayswitcher/BuildInfo.swift"
INSTALL_DIR="$HOME/.local/bin"

# Read the current version and build number, then increment the build.
version=$(grep 'let version' "$INFO" | sed -E 's/.*"(.*)".*/\1/')
build=$(grep 'let build' "$INFO" | sed -E 's/[^0-9]//g')
build=$((build + 1))

cat > "$INFO" <<EOF
/// Release version and build number.
///
/// \`version\` is the semantic version — bump it by hand for a release.
/// \`build\` is incremented automatically by \`scripts/deploy.sh\` on each deploy.
enum BuildInfo {
    static let version = "$version"
    static let build = $build
}
EOF

swift build -c release
mkdir -p "$INSTALL_DIR"
cp -f .build/release/displayswitcher "$INSTALL_DIR/displayswitcher"

echo "Deployed displayswitcher $version (build $build) -> $INSTALL_DIR/displayswitcher"
