#!/usr/bin/env bash
# Upload guest tarball + EXPORT_REPORT to Google Drive (requires rclone-auth.txt)
set -u
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

LOG="$BUILD_LOG_DIR/drive-upload.log"
DEST="${GDRIVE_DEST:-gdrive:beastphone-aosp-transfer/beastphone-android-guest}"

echo "=== $(date -u) guest tarball upload start ===" | tee -a "$LOG"

for f in beastphone-android-guest.tar.gz beastphone-android-guest-v2-initrd.tar.gz; do
  if [ -f "$WIN_PACK/$f" ]; then
    rclone copy "$WIN_PACK/$f" "$DEST/" \
      --transfers 4 --drive-chunk-size 64M --fast-list \
      -P --stats 30s --stats-one-line \
      --log-file="$LOG" --log-level INFO
  fi
done

rclone copy "$WIN_PACK/EXPORT_REPORT.txt" "$DEST/" \
  --transfers 2 --log-file="$LOG" --log-level INFO

echo "=== $(date -u) upload finished exit=$? ===" | tee -a "$LOG"
rclone ls "$DEST/" --log-file="$LOG" --log-level INFO | tee -a "$LOG"
