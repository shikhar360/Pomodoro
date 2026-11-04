#!/bin/zsh
# Renders the local icon into a contact sheet using macOS tools. This Mac has
# Command Line Tools rather than Xcode's Icon Composer, so there is one
# default rendition plus small-size previews.
# Usage: tools/icon_review.sh [out.png]     (default /tmp/Pomodoro-icon.png)
set -euo pipefail
here=${0:A:h}
repo=${here:h}
out=${1:-/tmp/Pomodoro-icon.png}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[[ -f "$repo/Resources/AppIcon.icns" ]] || "$repo/tools/make_icon.sh"
sips -s format png "$repo/Resources/AppIcon.icns" --out "$work/icon.png" >/dev/null
for size in 256 32 16; do
  sips -z "$size" "$size" "$work/icon.png" --out "$work/$size.png" >/dev/null
done
swift "$here/icon_sheet.swift" "$out" "$work"/{256,32,16}.png
echo "wrote $out"
