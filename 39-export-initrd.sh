#!/usr/bin/env bash
# BeastPhone initrd supplement — extract ramdisk, update export, pack v2 tarball
set -euo pipefail
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

AOSP="$AOSP_DIR"
OUT="$EMU_OUT"
EXPORT="$EXPORT_DIR"
UNPACK="$AOSP/out/host/linux-x86/bin/unpack_bootimg"
WORKDIR=/tmp/beastphone-boot-unpack
LOG="$BUILD_LOG_DIR/initrd-export.log"

exec >>"$LOG" 2>&1
echo "=== $(date -u) 39-export-initrd.sh start ==="

# lz4: prefer AOSP prebuilt, else system
LZ4=""
for p in \
  "$AOSP/prebuilts/build-tools/linux-x86/bin/lz4" \
  "$AOSP/out/host/linux-x86/bin/lz4" \
  /usr/bin/lz4; do
  if [ -x "$p" ]; then LZ4="$p"; break; fi
done
if [ -z "$LZ4" ]; then
  echo "Installing lz4 via apt..."
  sudo apt-get update -qq && sudo apt-get install -y -qq lz4
  LZ4=/usr/bin/lz4
fi
echo "Using lz4: $LZ4"

# Step 1 — verify existing export artifacts
for f in kernel/bzImage system/system.img vendor/vendor.img product/product.img; do
  test -f "$EXPORT/$f" || { echo "FATAL: missing $EXPORT/$f — run 05-export first"; exit 1; }
  ls -lh "$EXPORT/$f"
done

echo "=== emu64x boot outputs ==="
ls -lh "$OUT/vendor_boot.img" "$OUT/vbmeta.img" 2>/dev/null || true
ls -lh "$OUT/ramdisk.img" "$OUT/vendor_ramdisk.img" 2>/dev/null || true
test -f "$OUT/boot.img" && ls -lh "$OUT/boot.img" || echo "boot.img: not present (expected for emu64x)"
test -x "$UNPACK" || { echo "FATAL: unpack_bootimg missing"; exit 1; }

# Step 2 — unpack vendor_boot
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
"$UNPACK" --boot_img "$OUT/vendor_boot.img" --out "$WORKDIR/vendor_boot"
ls -la "$WORKDIR/vendor_boot/"

RAMDISK_SOURCE=""
INITRD_RAW=/tmp/beastphone-initrd.raw.cpio

# Priority 1: vendor_ramdisk00 from vendor_boot unpack (lz4 compressed cpio)
if [ -f "$WORKDIR/vendor_boot/vendor_ramdisk00" ]; then
  RAMDISK_SOURCE="vendor_boot/vendor_ramdisk00"
  "$LZ4" -d -f "$WORKDIR/vendor_boot/vendor_ramdisk00" "$INITRD_RAW"
elif [ -f "$WORKDIR/vendor_boot/vendor_ramdisk" ]; then
  RAMDISK_SOURCE="vendor_boot/vendor_ramdisk"
  cp "$WORKDIR/vendor_boot/vendor_ramdisk" "$INITRD_RAW"
fi

# For emu64x we also need generic ramdisk (init binary) — merge if separate
GENERIC_RAW=/tmp/beastphone-generic.raw.cpio
if [ -f "$OUT/ramdisk.img" ]; then
  "$LZ4" -d -f "$OUT/ramdisk.img" "$GENERIC_RAW"
  echo "Generic ramdisk decompressed: $(wc -c < "$GENERIC_RAW") bytes"
fi

mkdir -p "$EXPORT/initrd"

if [ -f "$INITRD_RAW" ] && [ -f "$GENERIC_RAW" ]; then
  MERGE_DIR=/tmp/beastphone-ramdisk-merge
  PACKED=/tmp/beastphone-initrd-packed.cpio
  rm -rf "$MERGE_DIR" "$PACKED"
  mkdir -p "$MERGE_DIR"
  (
    cd "$MERGE_DIR"
    cpio -idm --no-absolute-filenames < "$GENERIC_RAW" 2>/dev/null || true
    cpio -idm --no-absolute-filenames < "$INITRD_RAW" 2>/dev/null || true
    test -f ./init || { echo "FATAL: merged ramdisk missing init"; exit 1; }
    find . -mindepth 1 -print0 | cpio --null --quiet -o -H newc --owner root:root -O "$PACKED"
  )
  packed_sz=$(stat -c%s "$PACKED")
  if [ "$packed_sz" -lt 1000000 ]; then
    echo "WARN: merged cpio too small ($packed_sz bytes) — falling back to ramdisk-qemu.img"
    RAMDISK_SOURCE="ramdisk-qemu.img (fallback)"
    "$LZ4" -d -f "$OUT/ramdisk-qemu.img" "$EXPORT/initrd/initrd.img"
  else
    cp "$PACKED" "$EXPORT/initrd/initrd.img"
    RAMDISK_SOURCE="${RAMDISK_SOURCE}+ramdisk.img (merged generic+vendor cpio)"
  fi
elif [ -f "$GENERIC_RAW" ]; then
  cp "$GENERIC_RAW" "$EXPORT/initrd/initrd.img"
  RAMDISK_SOURCE="ramdisk.img (generic only)"
elif [ -f "$INITRD_RAW" ]; then
  cp "$INITRD_RAW" "$EXPORT/initrd/initrd.img"
else
  echo "ERROR: No ramdisk found"
  find "$WORKDIR" -type f
  exit 1
fi

initrd_sz=$(stat -c%s "$EXPORT/initrd/initrd.img")
if [ "$initrd_sz" -lt 1000000 ]; then
  echo "FATAL: initrd.img too small ($initrd_sz bytes)"
  exit 1
fi

ls -lh "$EXPORT/initrd/initrd.img"
file "$EXPORT/initrd/initrd.img"
echo "RAMDISK_SOURCE=$RAMDISK_SOURCE"

# Step 3 — optional vbmeta
if [ -f "$OUT/vbmeta.img" ]; then
  mkdir -p "$EXPORT/vbmeta"
  cp -v "$OUT/vbmeta.img" "$EXPORT/vbmeta/vbmeta.img"
  ls -lh "$EXPORT/vbmeta/vbmeta.img"
fi

# Step 4 — update EXPORT_REPORT + manifest
REPORT="$EXPORT/EXPORT_REPORT.txt"
{
  echo "BeastPhone Android Guest Export (v2 initrd)"
  echo "date: $(date -u -Iseconds)"
  echo "gsi_system: $GSI_OUT/system.img"
  echo "emu64x_vendor: $OUT/vendor.img"
  echo "emu64x_product: $OUT/product.img"
  echo "ramdisk_source: $RAMDISK_SOURCE"
  echo ""
  echo "=== sizes ==="
  du -h "$EXPORT"/kernel/bzImage "$EXPORT"/system/system.img "$EXPORT"/vendor/vendor.img \
    "$EXPORT"/product/product.img "$EXPORT"/initrd/initrd.img
  [ -f "$EXPORT/vbmeta/vbmeta.img" ] && du -h "$EXPORT/vbmeta/vbmeta.img"
  echo ""
  echo "=== sha256 ==="
  sha256sum \
    "$EXPORT/kernel/bzImage" \
    "$EXPORT/system/system.img" \
    "$EXPORT/vendor/vendor.img" \
    "$EXPORT/product/product.img" \
    "$EXPORT/initrd/initrd.img"
  [ -f "$EXPORT/vbmeta/vbmeta.img" ] && sha256sum "$EXPORT/vbmeta/vbmeta.img"
  echo ""
  echo "=== file(1) ==="
  file "$EXPORT/kernel/bzImage" "$EXPORT/system/system.img" "$EXPORT/vendor/vendor.img" \
    "$EXPORT/product/product.img" "$EXPORT/initrd/initrd.img"
  [ -f "$EXPORT/vbmeta/vbmeta.img" ] && file "$EXPORT/vbmeta/vbmeta.img"
} | tee "$REPORT"

export EXPORT_DIR
python3 - <<'PY'
import hashlib, json, os, time
from pathlib import Path

base = Path(os.environ.get("EXPORT_DIR", os.path.expanduser("~/beastphone-export")))
manifest_path = base / "manifests/runtime-manifest.json"
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"name": "beastphone-android-guest", "artifacts": {}}

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()

for rel in [
    "kernel/bzImage",
    "system/system.img",
    "vendor/vendor.img",
    "product/product.img",
    "initrd/initrd.img",
    "vbmeta/vbmeta.img",
]:
    p = base / rel
    if p.exists():
        manifest.setdefault("artifacts", {})[rel] = {
            "sha256": sha(p),
            "bytes": p.stat().st_size,
        }

manifest["generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
manifest["notes"] = "Added initrd for crosvm/WHPX boot — emu64x vendor ramdisk merged with generic ramdisk"
manifest_path.parent.mkdir(parents=True, exist_ok=True)
manifest_path.write_text(json.dumps(manifest, indent=2))
print("Updated", manifest_path)
PY

# Step 5 — verify layout
echo "=== export layout ==="
find "$EXPORT" -type f | sort

# Step 6 — package v2 tarball
TARBALL="$HOME/beastphone-android-guest-v2-initrd.tar.gz"
WIN_TARBALL="$WIN_PACK/beastphone-android-guest-v2-initrd.tar.gz"
rm -f "$TARBALL" "$WIN_TARBALL"
tar -czvf "$TARBALL" -C "$EXPORT" .
ls -lh "$TARBALL"
sha256sum "$TARBALL" | tee -a "$REPORT"
cp -v "$TARBALL" "$WIN_TARBALL"
cp -v "$REPORT" "$WIN_PACK/EXPORT_REPORT.txt"

echo "=== $(date -u) INITRD EXPORT DONE ==="
echo "Tarball: $WIN_TARBALL"
echo "RAMDISK_SOURCE=$RAMDISK_SOURCE"
touch "$BEASTPHONE_KIT/.initrd-export-done"
