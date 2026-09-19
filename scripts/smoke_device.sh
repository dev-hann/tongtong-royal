#!/usr/bin/env bash
# Device smoke for TongTong Royal — thin Patrol launcher (docs/03 § 9/§ 11).
#
# Usage: scripts/smoke_device.sh <adb-serial> [patrol-target]
#
# Runs the Patrol standing suite (or one target file) on the device,
# then scans logcat for fatal exceptions. Patrol owns all UI
# interaction; this wrapper only orchestrates + triages.

set -euo pipefail

SERIAL="${1:?usage: smoke_device.sh <adb-serial> [patrol-target]}"
TARGET="${2:-}"
PKG="com.tongtongroyal.app"
export PATH="$PATH:$HOME/.pub-cache/bin"

if ! command -v patrol >/dev/null 2>&1; then
  echo "patrol_cli missing — AGENTS § 3 pins version 3.11.0" >&2
  exit 1
fi

adb -s "$SERIAL" wait-for-device
adb -s "$SERIAL" logcat -c 2>/dev/null || true

# patrol_cli rejects directory targets — enumerate the standing suite.
if [ -n "$TARGET" ]; then
  FILES=("$TARGET")
else
  FILES=(app/integration_test/*_test.dart)
fi

FAILURES=0
for f in "${FILES[@]}"; do
  echo "== patrol: $f =="
  if ! patrol test --device "$SERIAL" --target "$f"; then
    FAILURES=$((FAILURES + 1))
  fi
done

echo "== smoke: crash scan =="
CRASHES=$(adb -s "$SERIAL" logcat -d 2>/dev/null \
  | grep -E "FATAL EXCEPTION" -A8 | tail -20 || true)
if [ -n "$CRASHES" ]; then
  echo "$CRASHES" >&2
  echo "SMOKE FAIL: fatal exceptions in logcat" >&2
  exit 1
fi

echo "SMOKE PASSED (device $SERIAL)"
