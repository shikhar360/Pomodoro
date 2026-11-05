#!/bin/zsh
# Builds Pomodoro and installs it to /Applications/Pomodoro.app.
# Build products live in ~/Library/Developer/Pomodoro, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh            release build, install/ski9
#        ./build.sh --debug    debug build, install
#        ./build.sh --open     install, then quit the running copy and open the new one
set -euo pipefail
here=${0:A:h}
name="Pomodoro"
scratch="$HOME/Library/Developer/$name/build"
config=release
[[ " $* " == *" --debug "* ]] && config=debug

# Sign with your Apple Development certificate when you have one (Xcode >
# Settings > Accounts). Otherwise sign ad hoc, which is fine for your own Mac.
identity="${SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n "$identity" ]] || identity=-

swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error|warning|Build complete" | grep -v "^\[" || true
bin="$scratch/$config/$name"
[[ -x "$bin" ]] || { echo "build failed"; exit 1; }
# swift build can report success while an edited file failed to compile. Catch that.
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
if [[ -n "$stale" ]]; then
  echo "build failed: binary is older than $stale"
  swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error" | head -20
  exit 1
fi

app="/Applications/$name.app"
mkdir -p "/Applications"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
# The icon: SVG layers -> Resources/AppIcon.icns, rebuilt when it changed.
if [[ -d "$here/Icon/AppIcon.icon" ]]; then
  icns="$here/Resources/AppIcon.icns"
  if [[ ! -f "$icns" || -n "$(find "$here/Icon/AppIcon.icon" -newer "$icns" | head -1)" ]]; then
    "$here/tools/make_icon.sh"
  fi
  cp -X "$icns" "$app/Contents/Resources/"
fi
xattr -cr "$app"
# An ad-hoc default requirement is a cdhash of this exact build, so macOS
# treats every rebuild as a new app and forgets the Screen Recording grant.
# Pin an identifier requirement for ad-hoc builds; a real certificate already
# has a stable designated requirement, so leave it alone.
if [[ "$identity" == "-" ]]; then
  codesign --force --sign - \
    --identifier com.shikhar.pomodoro \
    --requirements '=designated => identifier "com.shikhar.pomodoro"' \
    "$app" 2>&1 | grep -v "replacing existing signature" || true
  echo "installed $app (ad hoc, stable requirement: com.shikhar.pomodoro)"
else
  codesign --force --sign "$identity" "$app" 2>&1 | grep -v "replacing existing signature" || true
  echo "installed $app (signed: ${identity})"
fi

if [[ " $* " == *" --open "* ]]; then
  osascript -e "quit app \"$name\"" 2>/dev/null || true
  sleep 0.5
  open "$app"
fi
