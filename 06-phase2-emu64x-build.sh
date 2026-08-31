#!/usr/bin/env bash
# Phase 2: sdk_phone64_x86_64 — vendor.img + product.img
set -euo pipefail
trap '' HUP
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"
cd "$AOSP_DIR"
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_MAXSIZE=100G
export CCACHE_COMPRESS=1
export CCACHE_COMPRESSLEVEL=6

LOG="$BUILD_LOG_DIR/phase2.log"
exec >>"$LOG" 2>&1
echo "=== $(date -u) Phase 2 emu64x build start (jobs=$BUILD_JOBS) ==="

set +u
source build/envsetup.sh
lunch "$LUNCH_PHASE2"
export ANDROID_BUILD_BANNER="${ANDROID_BUILD_BANNER:-}"
set +u

OUT="$EMU_OUT"
echo "OUT=$OUT TARGET_PRODUCT=${TARGET_PRODUCT:-}"

m -j"$BUILD_JOBS" droid
echo "=== $(date -u) Phase 2 m done ==="

ls -lh "$OUT/vendor.img" "$OUT/product.img" "$OUT/system.img" "$OUT/kernel" "$OUT/boot.img" 2>/dev/null || true

test -f "$OUT/vendor.img" || { echo "FATAL: vendor.img missing after Phase 2"; exit 1; }
test -f "$OUT/product.img" || { echo "FATAL: product.img missing after Phase 2"; exit 1; }

echo "=== $(date -u) Phase 2 SUCCESS ==="
