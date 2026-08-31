# Version update guide

## Single source of truth: `VERSION.conf`

| Field | Meaning |
|-------|---------|
| `AOSP_TAG` | `repo init -b` branch (e.g. `android-14.0.0_r67`) |
| `LUNCH_GSI` | Phase 1 lunch target → `system.img` |
| `LUNCH_PHASE2` | Phase 2 lunch target → `vendor.img`, `product.img`, boot ramdisks |
| `BUILD_ID` | Reference only (fingerprint string) |
| `KERNEL_PREBUILT_REL` | Fallback kernel path inside `~/aosp` |
| `BUILD_JOBS` | Parallel jobs (`m -j`) |

## Minor bump (same Android major, new `rXX`)

1. Edit `VERSION.conf` → new `AOSP_TAG`
2. `cd ~/aosp && repo sync` or `bash 02-aosp-sync.sh`
3. Rebuild: `bash 03-aosp-build.sh` then handoff / export scripts
4. Often `out/` can be reused — faster incremental build

## Major bump (14 → 15)

1. Update all fields in `VERSION.conf` (lunch `ap2a` → `ap3a`, etc.)
2. Verify `KERNEL_PREBUILT_REL` exists after sync:
   ```bash
   ls ~/aosp/kernel/prebuilts/*/x86_64/
   ```
3. Clean output (recommended):
   ```bash
   rm -rf ~/aosp/out
   ```
4. Full pipeline: `bash run-full-pipeline.sh`

## After each successful release

Save under `releases/<name>/`:

- `EXPORT_REPORT.txt`
- `CHECKSUMS.txt` (tarball SHA256)
- Optional: `runtime-manifest.json` from export

Do **not** commit multi-GB tarballs to git — use Drive or release storage.

## Finding lunch targets for a new tag

```bash
cd ~/aosp
source build/envsetup.sh
lunch   # list targets
# Pick x86_64 GSI + sdk_phone64_x86_64 for BeastPhone guest
```
