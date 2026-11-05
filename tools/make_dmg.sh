#!/bin/zsh
# Builds a drag-to-Applications DMG in the project root.
# Usage: tools/make_dmg.sh [output.dmg]
set -euo pipefail
here=${0:A:h}
repo=${here:h}
out=${1:-"$repo/Pomodoro.dmg"}
app="/Applications/Pomodoro.app"
[[ -d "$app" ]] || app="$HOME/Applications/Pomodoro.app"
volume="Pomodoro"

[[ -d "$app" ]] || { echo "Missing $app; run ./build.sh first."; exit 1; }

work=$(mktemp -d)
staging="$work/$volume"
trap 'rm -rf "$work"' EXIT
mkdir -p "$staging"
ditto "$app" "$staging/Pomodoro.app"
ln -s /Applications "$staging/Applications"

rm -f "$out"
hdiutil create -volname "$volume" -srcfolder "$staging" -ov -format UDZO "$out" >/dev/null
hdiutil verify "$out" | tail -1
echo "wrote $out"
