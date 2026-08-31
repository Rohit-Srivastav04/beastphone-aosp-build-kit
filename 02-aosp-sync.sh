#!/usr/bin/env bash
# AOSP sync for BeastPhone x86_64 guest (tag from VERSION.conf)
set -euo pipefail
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

mkdir -p "$AOSP_DIR"
cd "$AOSP_DIR"

echo "=== $(date) repo init (tag=$AOSP_TAG) ==="
if [ ! -f .repo/manifest.xml ]; then
  rm -rf .repo
  repo init -u https://android.googlesource.com/platform/manifest -b "$AOSP_TAG" --depth=1
fi

echo "=== disk before sync ==="
df -h "$HOME" / || true

echo "=== $(date) repo sync (this takes hours) ==="
# Low parallelism avoids googlesource HTTP 429. No --fail-fast — resume partial sync.
SYNC_JOBS=4
for i in $(seq 1 50); do
  echo "--- sync attempt $i @ $(date) (-j$SYNC_JOBS) ---"
  if repo sync -c -j"$SYNC_JOBS" --no-tags --no-clone-bundle; then
    echo "=== sync OK ==="
    break
  fi
  echo "sync attempt $i had errors — retry in 90s"
  sleep 90
  if [ "$i" -eq 50 ]; then
    echo "FATAL: repo sync failed 50 times"
    exit 1
  fi
done

echo "=== disk after sync ==="
df -h "$HOME" /
du -sh "$AOSP_DIR"
echo "=== $(date) sync done ==="
echo "Next: bash $BEASTPHONE_KIT/03-aosp-build.sh"
