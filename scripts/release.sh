#!/bin/bash
# Local release for this fork (macOS)
# Builds an ad-hoc signed app, publishes it as a GitHub release and updates
# Casks/claudemeter.rb. Mirrors .github/workflows/release.yml, which needs
# a Developer ID certificate and notarization secrets this fork doesn't have.
#
# Install:  brew tap smb0209/claudemeter https://github.com/smb0209/ClaudeMeter
#           brew install --cask smb0209/claudemeter/claudemeter
# Upgrade:  brew update && brew upgrade --cask smb0209/claudemeter/claudemeter

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="smb0209/ClaudeMeter"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Build/Products/Release/ClaudeMeter.app"
CASK="$PROJECT_DIR/Casks/claudemeter.rb"

cd "$PROJECT_DIR"

# Version comes from the top CHANGELOG.md section, as in the release workflow
VERSION=$(sed -n 's/^## \[\([^]]*\)\].*/\1/p' CHANGELOG.md | head -1)
BUILD_NUMBER=$(echo "$VERSION" | sed 's/[^0-9]*\([0-9]*\).*/\1/')
ZIP="$BUILD_DIR/ClaudeMeter-$VERSION.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Top CHANGELOG.md section must be a version, found: $VERSION"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Commit or stash your changes first"
    exit 1
fi

echo "=== Building ClaudeMeter $VERSION (build $BUILD_NUMBER) ==="
# keychain-access-groups needs a provisioning profile, so ad-hoc builds leave the entitlements out
xcodebuild clean build \
    -quiet \
    -project ClaudeMeter.xcodeproj \
    -scheme ClaudeMeter \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_ENTITLEMENTS="" \
    PROVISIONING_PROFILE_SPECIFIER=""

codesign --verify --deep --strict "$APP_PATH"

echo "=== Creating $(basename "$ZIP") ==="
rm -f "$ZIP"
(
    cd "$(dirname "$APP_PATH")"
    xattr -cr ClaudeMeter.app
    find ClaudeMeter.app -name '._*' -delete
    zip -qr "$ZIP" ClaudeMeter.app
)
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

echo "=== Publishing v$VERSION to $REPO ==="
NOTES=$(awk '
    /^## \[/ {
        if (found) exit
        found=1
        next
    }
    found { print }
' CHANGELOG.md)

git push origin HEAD
gh release create "v$VERSION" "$ZIP" \
    --repo "$REPO" \
    --target "$(git rev-parse HEAD)" \
    --title "ClaudeMeter v$VERSION" \
    --notes "$NOTES"

echo "=== Updating Homebrew cask ==="
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK"
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA\"/" "$CASK"
git add "$CASK"
git commit -m "chore(claudemeter): update to $VERSION"
git push origin HEAD

echo ""
echo "Released v$VERSION ($SHA)"
