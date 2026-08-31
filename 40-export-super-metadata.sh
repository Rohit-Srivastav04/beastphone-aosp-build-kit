#!/usr/bin/env bash
# BeastPhone v3 export — super.img + metadata.img (+ v2 initrd/vbmeta/kernel)
set -euo pipefail
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

AOSP="$AOSP_DIR"
OUT="$EMU_OUT"
EXPORT="$EXPORT_DIR"
LOG="$BUILD_LOG_DIR/v3-export.log"
METADATA_STAGE=/tmp/beastphone-metadata-stage
LPDUMP="$AOSP/out/host/linux-x86/bin/lpdump"

# v2 reference SHA256 (must match if reusing files)
V2_SHA_KERNEL="b7c3dc7cce8acf1dbec1cb5da1afa1075cfe7f21af9b27beb350f59f935fc542"
V2_SHA_INITRD="822c9bd3aaf3361d3066e405803c368dd7f5c9a5e16935ee78f2201744cf9f4e"
V2_SHA_VBMETA="1a3a0e278af430c2b5467b0a895a8dae862ca285797250b09bccdb4d20db6e96"

exec >>"$LOG" 2>&1
echo "=== $(date -u) 40-export-super-metadata.sh start ==="

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

verify_or_copy_v2() {
  local rel="$1" expected="$2" src="$3"
  local dest="$EXPORT/$rel"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    actual=$(sha256_file "$dest")
    if [ "$actual" = "$expected" ]; then
      echo "OK unchanged: $rel"
      return 0
    fi
    echo "WARN: $rel SHA mismatch (have $actual, expected $expected) — refreshing from $src"
  fi
  if [ -f "$src" ]; then
    cp -v "$src" "$dest"
    actual=$(sha256_file "$dest")
    [ "$actual" = "$expected" ] || { echo "FATAL: $rel SHA after copy: $actual"; exit 1; }
  else
    echo "FATAL: missing source for $rel: $src"
    exit 1
  fi
}

# Step 1 — verify emu64x outputs
echo "=== Step 1: emu64x outputs ==="
test -f "$OUT/super.img" || { echo "FATAL: missing $OUT/super.img — run: m superimage"; exit 1; }
super_sz=$(stat -c%s "$OUT/super.img")
if [ "$super_sz" -lt 104857600 ]; then
  echo "FATAL: super.img too small ($super_sz bytes)"
  exit 1
fi
ls -lh "$OUT/super.img" "$OUT/vbmeta.img" "$OUT/vendor_boot.img" "$OUT/ramdisk.img" 2>/dev/null || true

if [ -x "$LPDUMP" ]; then
  echo "=== lpdump super.img ==="
  "$LPDUMP" "$OUT/super.img" | head -40
fi

# Step 2 — metadata.img (not prebuilt in emu64x out — build empty ext4 16MB)
echo "=== Step 2: metadata.img ==="
mkdir -p "$EXPORT/super" "$EXPORT/metadata" "$EXPORT/kernel" "$EXPORT/initrd" "$EXPORT/vbmeta" "$EXPORT/manifests"
rm -rf "$METADATA_STAGE"
mkdir -p "$METADATA_STAGE"

if [ -f "$OUT/metadata.img" ]; then
  echo "Using prebuilt $OUT/metadata.img"
  cp -v "$OUT/metadata.img" "$EXPORT/metadata/metadata.img"
else
  MKUSERIMG="$AOSP/out/host/linux-x86/bin/mkuserimg_mke2fs"
  METADATA_SIZE=16777216
  test -x "$MKUSERIMG" || { echo "FATAL: mkuserimg_mke2fs missing"; exit 1; }
  "$MKUSERIMG" "$METADATA_STAGE" "$EXPORT/metadata/metadata.img" ext4 metadata "$METADATA_SIZE"
  echo "Built metadata.img via mkuserimg_mke2fs (16MB ext4, mount_point=metadata)"
fi

meta_sz=$(stat -c%s "$EXPORT/metadata/metadata.img")
if [ "$meta_sz" -lt 1048576 ]; then
  echo "FATAL: metadata.img too small ($meta_sz bytes)"
  exit 1
fi

# super.img
cp -v "$OUT/super.img" "$EXPORT/super/super.img"

# v2 artifacts — preserve SHA256
verify_or_copy_v2 "kernel/bzImage" "$V2_SHA_KERNEL" "$EXPORT/kernel/bzImage"
verify_or_copy_v2 "initrd/initrd.img" "$V2_SHA_INITRD" "$EXPORT/initrd/initrd.img"
verify_or_copy_v2 "vbmeta/vbmeta.img" "$V2_SHA_VBMETA" "$EXPORT/vbmeta/vbmeta.img"

# Step 3 — file types
echo "=== Step 3: file(1) ==="
file "$EXPORT/super/super.img"
file "$EXPORT/metadata/metadata.img"
file "$EXPORT/initrd/initrd.img"
file "$EXPORT/vbmeta/vbmeta.img"
file "$EXPORT/kernel/bzImage"

# Step 4 — EXPORT_REPORT + manifest
REPORT="$EXPORT/EXPORT_REPORT.txt"
{
  echo "BeastPhone Android Guest Export (v3 super+metadata)"
  echo "date: $(date -u -Iseconds)"
  echo "aosp_tag: $AOSP_TAG"
  echo "emu64x_super: $OUT/super.img"
  echo "metadata_source: $([ -f "$OUT/metadata.img" ] && echo out/metadata.img || echo mkuserimg_mke2fs_16mb_ext4)"
  echo ""
  echo "=== sizes ==="
  du -h "$EXPORT/kernel/bzImage" "$EXPORT/super/super.img" "$EXPORT/metadata/metadata.img" \
    "$EXPORT/initrd/initrd.img" "$EXPORT/vbmeta/vbmeta.img"
  echo ""
  echo "=== sha256 ==="
  sha256sum \
    "$EXPORT/kernel/bzImage" \
    "$EXPORT/super/super.img" \
    "$EXPORT/metadata/metadata.img" \
    "$EXPORT/initrd/initrd.img" \
    "$EXPORT/vbmeta/vbmeta.img"
  echo ""
  echo "=== file(1) ==="
  file "$EXPORT/kernel/bzImage" "$EXPORT/super/super.img" "$EXPORT/metadata/metadata.img" \
    "$EXPORT/initrd/initrd.img" "$EXPORT/vbmeta/vbmeta.img"
} | tee "$REPORT"

export EXPORT_DIR AOSP_TAG LUNCH_GSI LUNCH_PHASE2
python3 - <<'PY'
import hashlib, json, os, time
from pathlib import Path

base = Path(os.environ["EXPORT_DIR"])
artifacts = {}
for rel in [
    "kernel/bzImage",
    "super/super.img",
    "metadata/metadata.img",
    "initrd/initrd.img",
    "vbmeta/vbmeta.img",
]:
    p = base / rel
    if not p.exists():
        continue
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    artifacts[rel] = {"sha256": h.hexdigest(), "bytes": p.stat().st_size}

doc = {
    "name": "beastphone-android-guest",
    "version": "v3-super-metadata",
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "aosp_tag": os.environ.get("AOSP_TAG", ""),
    "lunch_gsi": os.environ.get("LUNCH_GSI", ""),
    "lunch_phase2": os.environ.get("LUNCH_PHASE2", ""),
    "artifacts": artifacts,
    "notes": "v3: super+metadata for dynamic partitions GPT names; initrd+vbmeta+kernel from v2",
}
out = base / "manifests/runtime-manifest.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(doc, indent=2))
print("wrote", out)
PY

# Step 5 — layout
echo "=== export layout ==="
find "$EXPORT" -type f | sort

# Step 6 — tarball
TARBALL="$HOME/beastphone-android-guest-v3-super.tar.gz"
WIN_TARBALL="$WIN_PACK/beastphone-android-guest-v3-super.tar.gz"
rm -f "$TARBALL" "$WIN_TARBALL"
tar -czvf "$TARBALL" -C "$EXPORT" .
ls -lh "$TARBALL"
sha256sum "$TARBALL" | tee -a "$REPORT"
cp -v "$TARBALL" "$WIN_TARBALL"
cp -v "$REPORT" "$WIN_PACK/EXPORT_REPORT.txt"

echo "=== $(date -u) V3 EXPORT DONE ==="
echo "Tarball: $WIN_TARBALL"
touch "$BEASTPHONE_KIT/.v3-export-done"
