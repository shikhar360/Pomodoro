#!/bin/zsh
# Runs the in-app self-test without touching saved user settings.
# Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.shikhar.pomodoro.savedState
store=/tmp/Pomodoro-self.store
rm -f $store $store-shm $store-wal
APP_STORE=$store ~/Applications/Pomodoro.app/Contents/MacOS/Pomodoro --selftest
