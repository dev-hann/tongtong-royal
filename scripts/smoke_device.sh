#!/usr/bin/env bash
# Device smoke test for TongTong Royal (docs/03 § 9).
#
# Usage: scripts/smoke_device.sh <adb-serial> [apk-path]
# Requires: adb-connected device (USB or network), apk built.
#
# Flow: install -> launch -> HOME renders -> PLAY SOLO -> intro
# countdown -> play (JUMP) -> system back -> quit dialog -> KEEP
# RUNNING -> back -> QUIT -> home again -> crash scan.
# Exit 0 = smoke passed; 1 = failure (report printed).

set -euo pipefail

SERIAL="${1:?usage: smoke_device.sh <adb-serial> [apk-path]}"
APK="${2:-app/build/app/outputs/flutter-apk/app-release.apk}"
PKG="com.tongtongroyal.app"
ACTIVITY_WAIT=5
PHASE_WAIT=6

adb -s "$SERIAL" wait-for-device

fail() { echo "SMOKE FAIL: $1" >&2; exit 1; }

dump_texts() {
  adb -s "$SERIAL" shell uiautomator dump /sdcard/ttr_smoke.xml >/dev/null 2>&1
  adb -s "$SERIAL" shell cat /sdcard/ttr_smoke.xml 2>/dev/null \
    | grep -o 'text="[^"]*"' | sed 's/text="//;s/"$//'
}

wait_for_text() { # $1=text $2=max-seconds
  local deadline=$((SECONDS + ${2:-10}))
  while [ $SECONDS -lt $deadline ]; do
    if dump_texts | grep -qF "$1"; then return 0; fi
    sleep 1
  done
  return 1
}

tap_text() { # $1=text
  adb -s "$SERIAL" shell uiautomator dump /sdcard/ttr_smoke.xml >/dev/null 2>&1
  local bounds
  bounds=$(adb -s "$SERIAL" shell cat /sdcard/ttr_smoke.xml 2>/dev/null \
    | tr '>' '\n' | grep -F "text=\"$1\"" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | head -1 | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]')
  [ -n "$bounds" ] || fail "tap_text: '$1' not found"
  local x1 y1 x2 y2
  x1=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | head -1 | tr -d '[]' | cut -d, -f1)
  y1=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | head -1 | tr -d '[]' | cut -d, -f2)
  x2=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | tail -1 | tr -d '[]' | cut -d, -f1)
  y2=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | tail -1 | tr -d '[]' | cut -d, -f2)
  adb -s "$SERIAL" shell input tap $(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))
}

crash_scan() {
  adb -s "$SERIAL" logcat -d 2>/dev/null \
    | grep -E "FATAL EXCEPTION|AndroidRuntime.*$PKG" | tail -5 || true
}

echo "== smoke: install =="
adb -s "$SERIAL" install -r "$APK" >/dev/null || fail "install failed"

echo "== smoke: launch =="
adb -s "$SERIAL" logcat -c 2>/dev/null || true
adb -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep "$ACTIVITY_WAIT"

echo "== smoke: first-launch branch =="
if dump_texts | grep -qF "START"; then
  echo "  onboarding detected -> SKIP"
  tap_text "SKIP"
  sleep 3
fi

echo "== smoke: home renders =="
wait_for_text "PLAY SOLO" 10 || { crash_scan; fail "home did not render"; }

echo "== smoke: start solo =="
tap_text "PLAY SOLO"
wait_for_text "First to the finish line" 15 \
  || { crash_scan; fail "intro did not appear"; }

echo "== smoke: intro -> play (countdown auto-advance) =="
wait_for_text "JUMP" "$((3 + PHASE_WAIT))" \
  || { crash_scan; fail "play did not start (JUMP missing)"; }

echo "== smoke: jump a few times =="
for _ in 1 2 3; do tap_text "JUMP"; sleep 1; done

echo "== smoke: system back -> quit dialog =="
adb -s "$SERIAL" shell input keyevent KEYCODE_BACK
wait_for_text "Quit the race" 5 || { crash_scan; fail "quit dialog missing on back"; }

echo "== smoke: KEEP RUNNING resumes =="
tap_text "KEEP RUNNING"
sleep 2
wait_for_text "JUMP" 5 || { crash_scan; fail "did not resume after KEEP RUNNING"; }

echo "== smoke: quit to home =="
adb -s "$SERIAL" shell input keyevent KEYCODE_BACK
wait_for_text "Quit the race" 5 || fail "quit dialog missing (2nd)"
tap_text "QUIT"
wait_for_text "PLAY SOLO" 8 || { crash_scan; fail "did not return home after QUIT"; }

echo "== smoke: process alive =="
adb -s "$SERIAL" shell pidof "$PKG" >/dev/null || fail "app process died"

echo "== smoke: crash scan =="
CRASHES=$(crash_scan)
[ -z "$CRASHES" ] || { echo "$CRASHES" >&2; fail "fatal exceptions in logcat"; }

echo "SMOKE PASSED (device $SERIAL)"
