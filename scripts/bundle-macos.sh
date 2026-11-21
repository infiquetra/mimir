#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/bundle-macos.sh [OPTIONS]

Build and package Mimir as a native macOS Mimir.app bundle.

Options:
  --profile <release|debug>  Cargo build profile to bundle (default: release)
  --skip-build               Reuse the existing target/<profile>/mimir binary
  --install                  Install Mimir.app into /Applications (or ~/Applications if not writable)
  --install-dir <DIR>        Install Mimir.app into a specific directory (implies --install)
  --open                     Launch Mimir.app after bundling/installing
  --demo                     With --open, launch Mimir.app with --args --demo
  --zip                      Create target/<profile>/bundle/Mimir-macos-<arch>.zip
  --sign <identity>          Codesign identity (default: $MIMIR_CODESIGN_IDENTITY or '-')
  -h, --help                 Show this help message
EOF
}

PROFILE="release"
SKIP_BUILD=0
DO_INSTALL=0
INSTALL_DIR=""
DO_OPEN=0
DO_DEMO=0
DO_ZIP=0
SIGN_IDENTITY="${MIMIR_CODESIGN_IDENTITY:--}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            [[ $# -ge 2 ]] || { echo "error: --profile requires a value" >&2; exit 2; }
            PROFILE="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --install)
            DO_INSTALL=1
            shift
            ;;
        --install-dir)
            [[ $# -ge 2 ]] || { echo "error: --install-dir requires a directory" >&2; exit 2; }
            DO_INSTALL=1
            INSTALL_DIR="$2"
            shift 2
            ;;
        --open)
            DO_OPEN=1
            shift
            ;;
        --demo)
            DO_DEMO=1
            shift
            ;;
        --zip)
            DO_ZIP=1
            shift
            ;;
        --sign)
            [[ $# -ge 2 ]] || { echo "error: --sign requires an identity" >&2; exit 2; }
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option '$1'" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$PROFILE" in
    release|debug) ;;
    *)
        echo "error: invalid --profile '$PROFILE' (expected 'release' or 'debug')" >&2
        exit 2
        ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: scripts/bundle-macos.sh must be run on macOS (Darwin)." >&2
    exit 1
fi

for tool in sips iconutil plutil codesign ditto; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required macOS tool '$tool' not found in PATH" >&2
        exit 1
    fi
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PLIST_TEMPLATE="macos/Info.plist.template"
ICON_SOURCE="assets/macos/AppIcon.png"
for req in Cargo.toml "$PLIST_TEMPLATE" "$ICON_SOURCE"; do
    if [[ ! -f "$req" ]]; then
        echo "error: required file missing: $req" >&2
        exit 1
    fi
done

VERSION="$(awk -F'"' '
    /^\[package\]/ { in_pkg = 1; next }
    /^\[/ { in_pkg = 0 }
    in_pkg && $1 ~ /^version[[:space:]]*=/ { print $2; exit }
' Cargo.toml)"
if [[ -z "$VERSION" ]]; then
    echo "error: failed to read package version from Cargo.toml" >&2
    exit 1
fi

BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
BUILD_NUMBER="$(echo "$BUILD_NUMBER" | tr -d '[:space:]')"
if [[ -z "$BUILD_NUMBER" ]]; then
    BUILD_NUMBER="1"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "==> Building mimir ($PROFILE)..."
    if [[ "$PROFILE" == "release" ]]; then
        cargo build --release
    else
        cargo build
    fi
fi

BIN_PATH="target/$PROFILE/mimir"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "error: binary not found or not executable at $BIN_PATH" >&2
    exit 1
fi

BUNDLE_ROOT="target/$PROFILE/bundle"
APP_BUNDLE="$BUNDLE_ROOT/Mimir.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/mimir"
chmod +x "$APP_BUNDLE/Contents/MacOS/mimir"

esc_version="$(printf '%s' "$VERSION" | sed 's/[&/|\\]/\\&/g')"
esc_build="$(printf '%s' "$BUILD_NUMBER" | sed 's/[&/|\\]/\\&/g')"
sed -e "s|__VERSION__|$esc_version|g" -e "s|__BUILD_NUMBER__|$esc_build|g" \
    "$PLIST_TEMPLATE" > "$APP_BUNDLE/Contents/Info.plist"
plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null

WORK_DIR="$(mktemp -d)"
STAGED_APP=""
cleanup() {
    rm -rf "$WORK_DIR"
    if [[ -n "$STAGED_APP" && -e "$STAGED_APP" ]]; then
        rm -rf "$STAGED_APP"
    fi
}
trap cleanup EXIT

ICONSET_DIR="$WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
render_icon() {
    local px="$1"
    local name="$2"
    sips -s format png -z "$px" "$px" "$ICON_SOURCE" --out "$ICONSET_DIR/$name" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Signing $APP_BUNDLE (identity: $SIGN_IDENTITY)..."
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
echo "==> Packaged $APP_BUNDLE (v$VERSION build $BUILD_NUMBER)"

if [[ "$DO_ZIP" -eq 1 ]]; then
    ARCH="$(uname -m)"
    ZIP_PATH="$BUNDLE_ROOT/Mimir-macos-${ARCH}.zip"
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
    echo "==> Created archive $ZIP_PATH"
fi

OPEN_TARGET="$APP_BUNDLE"
if [[ "$DO_INSTALL" -eq 1 ]]; then
    if [[ -z "$INSTALL_DIR" ]]; then
        if [[ -d "/Applications" && -w "/Applications" ]]; then
            INSTALL_DIR="/Applications"
        else
            INSTALL_DIR="$HOME/Applications"
        fi
    fi
    mkdir -p "$INSTALL_DIR"
    STAGED_APP="$INSTALL_DIR/.Mimir.app.new.$$"
    rm -rf "$STAGED_APP"
    ditto "$APP_BUNDLE" "$STAGED_APP"
    xattr -dr com.apple.quarantine "$STAGED_APP" 2>/dev/null || true
    DEST_APP="$INSTALL_DIR/Mimir.app"
    rm -rf "$DEST_APP"
    mv "$STAGED_APP" "$DEST_APP"
    STAGED_APP=""
    codesign --verify --deep --strict "$DEST_APP"
    OPEN_TARGET="$DEST_APP"
    echo "==> Installed $DEST_APP"
fi

if [[ "$DO_OPEN" -eq 1 ]]; then
    echo "==> Launching $OPEN_TARGET..."
    if [[ "$DO_DEMO" -eq 1 ]]; then
        open -n "$OPEN_TARGET" --args --demo
    else
        open "$OPEN_TARGET"
    fi
fi
