#!/usr/bin/env bash
# BeastPhone handoff: wait GSI → Phase 2 emu64x → export tarball
set -u
trap '' HUP
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

LOG="$BUILD_LOG_DIR/handoff.log"
MARK="$BEASTPHONE_KIT/.export-done"
LOCK="$BEASTPHONE_KIT/.handoff.lock"

exec >>"$LOG" 2>&1
echo "=== $(date -u) handoff orchestrator started ==="

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "=== $(date -u) another handoff orchestrator already running - exit ==="
  exit 0
fi

while pgrep -f "combined-aosp_x86_64.ninja" >/dev/null 2>&1; do
  echo "=== $(date -u) GSI still running - waiting 120s ==="
  sleep 120
done

if [ ! -f "$GSI_OUT/system.img" ]; then
  echo "FATAL: GSI system.img missing after wait"
  exit 1
fi
echo "=== $(date -u) GSI DONE - system.img $(stat -c%s "$GSI_OUT/system.img") bytes ==="
touch "$BEASTPHONE_KIT/.gsi-done"

if [ ! -f "$EMU_OUT/vendor.img" ] || [ ! -f "$EMU_OUT/product.img" ]; then
  echo "=== $(date -u) Phase 2 START - $LUNCH_PHASE2 ==="
  bash "$BEASTPHONE_KIT/06-phase2-emu64x-build.sh"
else
  echo "=== $(date -u) Phase 2 images already present - skipping build ==="
fi

if [ ! -f "$EMU_OUT/vendor.img" ] || [ ! -f "$EMU_OUT/product.img" ]; then
  echo "FATAL: Phase 2 failed - vendor/product missing"
  exit 1
fi
echo "=== $(date -u) Phase 2 DONE ==="

if [ -f "$MARK" ]; then
  echo "=== $(date -u) export already done ==="
  exit 0
fi
bash "$BEASTPHONE_KIT/05-export-beastphone.sh"
echo "=== $(date -u) HANDOFF COMPLETE ==="
