#!/usr/bin/env bash
# Phase 1: GSI system.img (lunch from VERSION.conf)
set -euo pipefail
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"
cd "$AOSP_DIR"
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_MAXSIZE=100G
export CCACHE_COMPRESS=1
export CCACHE_COMPRESSLEVEL=6
mkdir -p "$CCACHE_DIR"
ccache -M 100G 2>/dev/null || true

set +u
source build/envsetup.sh
lunch "$LUNCH_GSI"
# envsetup m() references ANDROID_BUILD_BANNER with set -u — must be set
export ANDROID_BUILD_BANNER="${ANDROID_BUILD_BANNER:-}"
set -u

echo "=== $(date) m start (jobs=$BUILD_JOBS) ==="
# Full build. WSL1: limit parallelism for stability.
BUILD_JOBS="${BUILD_JOBS:-16}"
m -j"$BUILD_JOBS"
echo "=== $(date) m done ==="

ls -lh "$GSI_OUT/system.img" "$GSI_OUT/vendor.img" "$GSI_OUT/product.img" "$GSI_OUT/kernel" "$GSI_OUT/boot.img" 2>/dev/null || true
echo "Next: bash $BEASTPHONE_KIT/06-phase2-emu64x-build.sh"
