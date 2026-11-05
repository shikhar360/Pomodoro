#!/bin/zsh
# Snapshots of the floating timer and tray in light and dark.
# Usage: tools/snap.sh
set -u
app=/Applications/Pomodoro.app/Contents/MacOS/Pomodoro
store=/tmp/Pomodoro-test.store
shots=/tmp/Pomodoro-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/com.shikhar.pomodoro.savedState
rm -f $store $store-shm $store-wal
rm -rf $shots
APP_STORE=$store APP_SNAPSHOT=$shots $app
