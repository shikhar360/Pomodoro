#!/bin/zsh
# Builds a normal .icns from the SVG layers. sips and iconutil ship with
# macOS and work with Command Line Tools; actool would require Xcode.
set -euo pipefail
here=${0:A:h}
repo=${here:h}
icon="$repo/Icon/AppIcon.icon"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$repo/Resources" "$work/AppIcon.iconset"

sips -s format png -z 1024 1024 "$icon/Assets/back.svg" --out "$work/back.png" >/dev/null
sips -s format png -z 1024 1024 "$icon/Assets/front.svg" --out "$work/front.png" >/dev/null
swift "$here/icon_sheet.swift" "$work/combined.png" "$work/back.png" "$work/front.png"

for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" "$work/combined.png" --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
done
cp "$work/AppIcon.iconset/icon_512x512.png" "$work/AppIcon.iconset/icon_256x256@2x.png"
cp "$work/combined.png" "$work/AppIcon.iconset/icon_512x512@2x.png"
iconutil -c icns "$work/AppIcon.iconset" -o "$repo/Resources/AppIcon.icns"
echo "wrote Resources/AppIcon.icns"
