#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
configuration="${1:-release}"
case "$configuration" in
  release) optimization=-O ;;
  debug) optimization=-Onone ;;
  *) printf 'Usage: %s [release|debug]\n' "$0" >&2; exit 2 ;;
esac

developer_dir="$(xcode-select -p)"
sdk="${FRAME_NOTE_SDK:-}"
if [[ -z "$sdk" ]]; then
  tools_sdk="$developer_dir/SDKs/MacOSX.sdk"
  if [[ -d "$tools_sdk" ]]; then
    sdk="$tools_sdk"
  else
    sdk="$(xcrun --sdk macosx --show-sdk-path)"
  fi
fi
sdk="$(cd "$sdk" && pwd -P)"

mkdir -p dist
staging="$(mktemp -d "$PWD/dist/.build-app.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
app="$staging/ShotCue.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
binary="$app/Contents/MacOS/FrameNote"
set --
# Some Command Line Tools installations leave both versions of the SwiftBridging map.
# Hide the duplicate for this compiler invocation without changing the installed toolchain.
swift_headers="$developer_dir/usr/include/swift"
if [[ -f "$swift_headers/module.modulemap" && -f "$swift_headers/bridging.modulemap" ]] &&
   /usr/bin/grep -q '^module SwiftBridging' "$swift_headers/module.modulemap" &&
   /usr/bin/grep -q '^module SwiftBridging' "$swift_headers/bridging.modulemap"; then
  mkdir -p .build/sdk-overlay
  overlay_dir="$PWD/.build/sdk-overlay"
  : > "$overlay_dir/empty.modulemap"
  /usr/bin/plutil -create binary1 "$overlay_dir/overlay.json"
  /usr/bin/plutil -insert version -integer 0 "$overlay_dir/overlay.json"
  /usr/bin/plutil -insert roots -array "$overlay_dir/overlay.json"
  /usr/bin/plutil -insert roots.0 -dictionary "$overlay_dir/overlay.json"
  /usr/bin/plutil -insert roots.0.type -string file "$overlay_dir/overlay.json"
  /usr/bin/plutil -insert roots.0.name -string "$swift_headers/bridging.modulemap" "$overlay_dir/overlay.json"
  /usr/bin/plutil -insert roots.0.external-contents -string "$overlay_dir/empty.modulemap" "$overlay_dir/overlay.json"
  /usr/bin/plutil -convert json "$overlay_dir/overlay.json"
  set -- -vfsoverlay "$overlay_dir/overlay.json"
fi
xcrun swiftc -sdk "$sdk" -target "$(uname -m)-apple-macosx14.0" -module-name FrameNote \
  "$@" "$optimization" Sources/FrameNote/*.swift -o "$binary"
cp scripts/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
"$binary" --make-icon "$staging/AppIcon.iconset"
iconutil -c icns -o "$app/Contents/Resources/AppIcon.icns" "$staging/AppIcon.iconset"
codesign --force --sign - "$app"
codesign --verify --strict "$app"

if [[ -d dist/ShotCue.app ]]; then
  mv dist/ShotCue.app "$staging/previous.app"
fi
mv "$app" dist/ShotCue.app
printf 'Built %s/dist/ShotCue.app\n' "$PWD"
