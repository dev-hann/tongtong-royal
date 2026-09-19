#!/usr/bin/env bash
# Device smoke test for TongTong Royal (docs/03 § 9).
#
# Usage: scripts/smoke_device.sh <adb-serial> [apk-path]
#
# Two engines, auto-selected per device:
#  - text engine: uiautomator dump text anchors (most phones)
#  - pixel engine: when uiautomator sees no Flutter text (observed on
#    LineageOS Pi 4) — asserts/finds UI by TOKEN COLORS (orange
#    primary FF8C42, teal secondary 2EC4B6, light bg F7F9FC, arena
#    dark 101820) via screencap + ffmpeg sampling.
#
# Flow: install -> launch -> (onboarding START/SKIP) -> home ->
# PLAY SOLO -> play (JUMP x3) -> back -> quit dialog -> KEEP RUNNING
# -> back -> QUIT -> home -> process alive -> zero FATAL EXCEPTIONs.

set -euo pipefail

SERIAL="${1:?usage: smoke_device.sh <adb-serial> [apk-path]}"
APK="${2:-app/build/app/outputs/flutter-apk/app-release.apk}"
PKG="com.tongtongroyal.app"
TMP="${TMPDIR:-/tmp}/ttr_smoke"
mkdir -p "$TMP"

adb -s "$SERIAL" wait-for-device

fail() { echo "SMOKE FAIL: $1" >&2; exit 1; }

# ---------- text engine ----------
dump_texts() {
  adb -s "$SERIAL" shell uiautomator dump /sdcard/ttr_smoke.xml >/dev/null 2>&1
  adb -s "$SERIAL" shell cat /sdcard/ttr_smoke.xml 2>/dev/null \
    | grep -o 'text="[^"]*"' | sed 's/text="//;s/"$//'
}
wait_for_text() {
  local deadline=$((SECONDS + ${2:-10}))
  while [ $SECONDS -lt $deadline ]; do
    if dump_texts | grep -qF "$1"; then return 0; fi
    sleep 1
  done
  return 1
}
tap_text() {
  adb -s "$SERIAL" shell uiautomator dump /sdcard/ttr_smoke.xml >/dev/null 2>&1
  local bounds x1 y1 x2 y2
  bounds=$(adb -s "$SERIAL" shell cat /sdcard/ttr_smoke.xml 2>/dev/null \
    | tr '>' '\n' | grep -F "text=\"$1\"" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' \
    | head -1 | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]')
  [ -n "$bounds" ] || fail "tap_text: '$1' not found"
  x1=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | head -1 | tr -d '[]' | cut -d, -f1)
  y1=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | head -1 | tr -d '[]' | cut -d, -f2)
  x2=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | tail -1 | tr -d '[]' | cut -d, -f1)
  y2=$(echo "$bounds" | grep -o '\[[0-9]*,[0-9]*\]' | tail -1 | tr -d '[]' | cut -d, -f2)
  adb -s "$SERIAL" shell input tap $(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))
}

# ---------- pixel engine ----------
shot() {
  adb -s "$SERIAL" shell screencap -p /sdcard/ttr_smoke.png >/dev/null 2>&1
  adb -s "$SERIAL" pull /sdcard/ttr_smoke.png "$TMP/shot.png" >/dev/null 2>&1
}
pix() { # x y -> "rrggbb"
  ffmpeg -y -i "$TMP/shot.png" -vf "crop=1:1:$1:$2" \
    -f rawvideo -pix_fmt rgb24 - 2>/dev/null | xxd -p | head -c 6
}
close_rgb() { # hex1 hex2 tolerance(per-channel)
  local r1 g1 b1 r2 g2 b2
  r1=$((16#${1:0:2})); g1=$((16#${1:2:2})); b1=$((16#${1:4:2}))
  r2=$((16#${2:0:2})); g2=$((16#${2:2:2})); b2=$((16#${2:4:2}))
  [ $((r1 > r2 ? r1 - r2 : r2 - r1)) -le ${3:-25} ] && \
  [ $((g1 > g2 ? g1 - g2 : g2 - g1)) -le ${3:-25} ] && \
  [ $((b1 > b2 ? b1 - b2 : b2 - b1)) -le ${3:-25} ]
}
scan_col() { # x y1 y2 hex [tol] -> echoes first matching y
  local x=$1 y1=$2 y2=$3 hex=$4 tol=${5:-25} y c
  for ((y = y1; y <= y2; y++)); do
    c=$(pix "$x" "$y")
    if close_rgb "$c" "$hex" "$tol"; then echo "$y"; return 0; fi
  done
  return 1
}
tap() { adb -s "$SERIAL" shell input tap "$1" "$2"; }
key_back() { adb -s "$SERIAL" shell input keyevent KEYCODE_BACK; }

ORANGE=ff8c42; TEAL=2ec4b6; BG=f7f9fc; DARK=101820
XC=960  # app portrait strip is centered on this display

is_play() { shot; close_rgb "$(pix 960 500)" "$DARK" 30; }
is_home_or_onboarding() { shot; close_rgb "$(pix 200 600)" "$BG" 25; }

# ---------- shared ----------
crash_scan() {
  adb -s "$SERIAL" logcat -d 2>/dev/null \
    | grep -E "FATAL EXCEPTION" -A8 | tail -20 || true
}

echo "== smoke: engine detect =="
adb -s "$SERIAL" shell uiautomator dump /sdcard/ttr_smoke.xml >/dev/null 2>&1
TEXTS=$(adb -s "$SERIAL" shell cat /sdcard/ttr_smoke.xml 2>/dev/null \
  | grep -c 'text="[^"]+"')
if [ "$TEXTS" -gt 0 ] 2>/dev/null; then ENGINE=text; else ENGINE=pixel; fi
echo "  engine=$ENGINE (flutter text nodes visible: $TEXTS)"

echo "== smoke: install =="
adb -s "$SERIAL" install -r "$APK" >/dev/null || fail "install failed"

echo "== smoke: launch =="
adb -s "$SERIAL" logcat -c 2>/dev/null || true
# am start, not monkey: monkey's event stream hangs on some devices
# over network adb (observed: LineageOS Pi 4).
adb -s "$SERIAL" shell am start -n "$PKG/.MainActivity" >/dev/null
sleep 5

if [ "$ENGINE" = text ]; then
  if dump_texts | grep -qF "START"; then
    echo "  onboarding -> SKIP"; tap_text "SKIP"; sleep 3
  fi
  wait_for_text "PLAY SOLO" 10 || { crash_scan; fail "home did not render"; }
  tap_text "PLAY SOLO"
  wait_for_text "First to the finish line" 15 \
    || { crash_scan; fail "intro did not appear"; }
  wait_for_text "JUMP" 10 || { crash_scan; fail "play did not start"; }
  for _ in 1 2 3; do tap_text "JUMP"; sleep 1; done
  key_back
  wait_for_text "Quit the race" 5 || { crash_scan; fail "no quit dialog"; }
  tap_text "KEEP RUNNING"; sleep 2
  wait_for_text "JUMP" 5 || { crash_scan; fail "resume failed"; }
  key_back
  wait_for_text "Quit the race" 5 || fail "no quit dialog (2nd)"
  tap_text "QUIT"
  wait_for_text "PLAY SOLO" 8 || { crash_scan; fail "no home after QUIT"; }
else
  # pixel engine
  sleep 2
  # onboarding/home chain: tap the mid-lower primary (orange) button
  # until the world turns dark (play). Covers START then PLAY SOLO.
  chain_ok=0
  for _ in 1 2 3; do
    if is_play; then chain_ok=1; break; fi
    is_home_or_onboarding || { crash_scan; fail "neither home nor onboarding visible"; }
    y=$(scan_col "$XC" 500 950 "$ORANGE" 40) || { crash_scan; fail "no primary button found"; }
    tap "$XC" $((y + 40)); sleep 6
  done
  [ $chain_ok -eq 1 ] || { crash_scan; fail "did not reach play"; }
  echo "  reached play (dark world)"

  sleep 2
  y=$(scan_col "$XC" 900 1060 "$ORANGE" 40) || fail "JUMP button not found"
  for _ in 1 2 3; do tap "$XC" $((y + 40)); sleep 1; done

  key_back; sleep 2
  shot
  y=$(scan_col "$XC" 500 800 "$ORANGE" 40) || { crash_scan; fail "dialog KEEP RUNNING not found"; }
  tap "$XC" $((y + 20)); sleep 2
  is_play || { crash_scan; fail "did not resume after KEEP RUNNING"; }

  key_back; sleep 2
  shot
  # QUIT is the teal (secondary) dialog action.
  y=$(scan_col "$XC" 500 800 "$TEAL" 40) || { crash_scan; fail "dialog QUIT (teal) not found"; }
  tap "$XC" $((y + 20)); sleep 3
  is_home_or_onboarding || { crash_scan; fail "no home after QUIT"; }
fi

echo "== smoke: process alive =="
adb -s "$SERIAL" shell pidof "$PKG" >/dev/null || fail "app process died"

echo "== smoke: crash scan =="
CRASHES=$(crash_scan)
[ -z "$CRASHES" ] || { echo "$CRASHES" >&2; fail "fatal exceptions in logcat"; }

echo "SMOKE PASSED (device $SERIAL, engine $ENGINE)"
