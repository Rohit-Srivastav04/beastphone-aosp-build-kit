#!/usr/bin/env bash
# BeastPhone Android guest — export kernel + system + vendor + product
set -euo pipefail
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

EXPORT="$EXPORT_DIR"
LOG="$BUILD_LOG_DIR/export.log"

exec >>"$LOG" 2>&1
echo "=== $(date -u) 05-export-beastphone.sh start ==="

rm -rf "$EXPORT"
mkdir -p "$EXPORT"/{kernel,system,vendor,product}

# system — prefer GSI; fallback emu64x if GSI missing
if [ -f "$GSI_OUT/system.img" ]; then
  cp -v "$GSI_OUT/system.img" "$EXPORT/system/system.img"
elif [ -f "$EMU_OUT/system.img" ]; then
  cp -v "$EMU_OUT/system.img" "$EXPORT/system/system.img"
else
  echo "FATAL: no system.img in GSI or emu64x"
  exit 1
fi

# vendor + product — Phase 2 emu64x (REQUIRED)
test -f "$EMU_OUT/vendor.img" || { echo "FATAL: vendor.img missing at $EMU_OUT"; exit 1; }
test -f "$EMU_OUT/product.img" || { echo "FATAL: product.img missing at $EMU_OUT"; exit 1; }
cp -v "$EMU_OUT/vendor.img" "$EXPORT/vendor/vendor.img"
cp -v "$EMU_OUT/product.img" "$EXPORT/product/product.img"

# kernel — priority: emu64x kernel > boot.img unpack > prebuilt
kernel_ok=false
if [ -f "$EMU_OUT/kernel" ] && file "$EMU_OUT/kernel" | grep -qi bzImage; then
  cp -v "$EMU_OUT/kernel" "$EXPORT/kernel/bzImage"
  kernel_ok=true
elif [ -f "$EMU_OUT/boot.img" ]; then
  UNPACK=/tmp/beastphone-bootunpack
  rm -rf "$UNPACK"
  mkdir -p "$UNPACK"
  if command -v unpack_bootimg >/dev/null 2>&1; then
    unpack_bootimg --boot_img "$EMU_OUT/boot.img" --out "$UNPACK"
  elif [ -x "$AOSP_DIR/out/host/linux-x86/bin/unpack_bootimg" ]; then
    "$AOSP_DIR/out/host/linux-x86/bin/unpack_bootimg" --boot_img "$EMU_OUT/boot.img" --out "$UNPACK"
  fi
  if [ -f "$UNPACK/kernel" ] && file "$UNPACK/kernel" | grep -qi bzImage; then
    cp -v "$UNPACK/kernel" "$EXPORT/kernel/bzImage"
    kernel_ok=true
  fi
fi
if [ "$kernel_ok" = false ] && [ -f "$PREBUILT_K" ]; then
  file "$PREBUILT_K" | grep -qi bzImage || { echo "FATAL: prebuilt not bzImage"; exit 1; }
  cp -v "$PREBUILT_K" "$EXPORT/kernel/bzImage"
  kernel_ok=true
fi
if [ "$kernel_ok" = false ]; then
  echo "FATAL: no bzImage source found"
  exit 1
fi

# verify all 4 + minimum size
for f in kernel/bzImage system/system.img vendor/vendor.img product/product.img; do
  test -f "$EXPORT/$f" || { echo "MISSING $f"; exit 1; }
  sz=$(stat -c%s "$EXPORT/$f")
  if [ "$sz" -lt 1048576 ]; then
    echo "FATAL: $f too small ($sz bytes)"
    exit 1
  fi
  ls -lh "$EXPORT/$f"
done

# EXPORT_REPORT.txt
REPORT="$EXPORT/EXPORT_REPORT.txt"
{
  echo "BeastPhone Android Guest Export"
  echo "date: $(date -u -Iseconds)"
  echo "aosp_tag: $AOSP_TAG"
  echo "gsi_system: $GSI_OUT/system.img"
  echo "emu64x_vendor: $EMU_OUT/vendor.img"
  echo "emu64x_product: $EMU_OUT/product.img"
  echo ""
  echo "=== sizes ==="
  du -h "$EXPORT"/kernel/bzImage "$EXPORT"/system/system.img "$EXPORT"/vendor/vendor.img "$EXPORT"/product/product.img
  echo ""
  echo "=== sha256 ==="
  sha256sum "$EXPORT"/kernel/bzImage "$EXPORT"/system/system.img "$EXPORT"/vendor/vendor.img "$EXPORT"/product/product.img
  echo ""
  echo "=== file(1) ==="
  file "$EXPORT"/kernel/bzImage "$EXPORT"/system/system.img "$EXPORT"/vendor/vendor.img "$EXPORT"/product/product.img
} | tee "$REPORT"

# runtime-manifest.json
MANIFEST="$EXPORT/manifests/runtime-manifest.json"
mkdir -p "$EXPORT/manifests"
export EXPORT_DIR LUNCH_GSI LUNCH_PHASE2 AOSP_TAG
python3 - <<'PY'
import hashlib, json, os, time
export = os.environ["EXPORT_DIR"]
files = ["kernel/bzImage", "system/system.img", "vendor/vendor.img", "product/product.img"]
entries = {}
for rel in files:
    path = os.path.join(export, rel)
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    entries[rel] = {"sha256": h.hexdigest(), "bytes": os.path.getsize(path)}
doc = {
    "name": "beastphone-android-guest",
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "aosp_tag": os.environ.get("AOSP_TAG", ""),
    "lunch_gsi": os.environ.get("LUNCH_GSI", ""),
    "lunch_phase2": os.environ.get("LUNCH_PHASE2", ""),
    "artifacts": entries,
}
out = os.path.join(export, "manifests/runtime-manifest.json")
with open(out, "w") as f:
    json.dump(doc, f, indent=2)
print("wrote", out)
PY

# pack to Windows download folder
mkdir -p "$WIN_PACK"
TARBALL="$WIN_PACK/beastphone-android-guest.tar.gz"
rm -f "$TARBALL"
tar -czvf "$TARBALL" -C "$EXPORT" .
ls -lh "$TARBALL"
sha256sum "$TARBALL" | tee -a "$REPORT"
cp -v "$REPORT" "$WIN_PACK/EXPORT_REPORT.txt" 2>/dev/null || true

echo "=== $(date -u) EXPORT DONE ==="
echo "Download: $WIN_PACK/beastphone-android-guest.tar.gz"
touch "$BEASTPHONE_KIT/.export-done"
