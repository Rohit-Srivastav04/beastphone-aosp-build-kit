# BeastPhone AOSP Build Kit

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0ea5e9,50:6366f1,100:7c3aed&height=120&section=header&text=BeastPhone%20AOSP%20Build%20Kit&fontSize=38&fontColor=ffffff&desc=Android%20guest%20images%20for%20BeastBrowser&descSize=16&descAlign=center&animation=fadeIn" alt="BeastPhone AOSP Build Kit" />

<br/>

[![BeastBrowser](https://img.shields.io/badge/Project-BeastBrowser-0ea5e9?style=for-the-badge&labelColor=0b1220&logo=googlechrome&logoColor=white)](https://beastbrowser.com)
[![Android](https://img.shields.io/badge/Android-14_AOSP-22d3ee?style=for-the-badge&labelColor=0b1220&logo=android&logoColor=0b1220)](https://source.android.com/)
[![Runtime](https://img.shields.io/badge/Runtime-crosvm%20%2B%20WHPX-6366f1?style=for-the-badge&labelColor=0b1220&logo=windows&logoColor=white)](https://beastbrowser.com)
[![Maintainer](https://img.shields.io/badge/Maintainer-Rohit_Srivastav-7c3aed?style=for-the-badge&labelColor=0b1220&logo=github&logoColor=white)](https://github.com/Rohit-Srivastav04)

[Website](https://beastbrowser.com) · [Issues](https://github.com/Rohit-Srivastav04/beastphone-aosp-build-kit/issues) · [Profile](https://github.com/Rohit-Srivastav04)

</div>

> **Project:** [BeastBrowser](https://beastbrowser.com) — BeastPhone Android guest runtime  
> **Made by:** Rohit Srivastav · [GitHub @Rohit-Srivastav04](https://github.com/Rohit-Srivastav04)

Scripts and docs to build **Android guest images** for BeastPhone runtime  
(**Windows → WHPX → crosvm**). Not for Android Emulator / AVD.

Current pinned release: **Android 14** `android-14.0.0_r67` (AP2A)

---

## What this builds

| Artifact | Source |
|----------|--------|
| `system/system.img` | GSI Phase 1 (`generic_x86_64`) |
| `vendor/vendor.img` | Phase 2 (`emu64x`) |
| `product/product.img` | Phase 2 (`emu64x`) |
| `kernel/bzImage` | emu64x kernel or prebuilt |
| `initrd/initrd.img` | vendor_boot + generic ramdisk merge |
| `vbmeta/vbmeta.img` | optional |

Output tarballs land in your Windows folder (WSL: `/mnt/c/Users/<you>/beastphone-build/`).

---

## Quick start (new VM / RDP)

### 1. Clone this repo

**WSL (Ubuntu 22.04):**

```bash
git clone https://github.com/Rohit-Srivastav04/beastphone-aosp-build-kit.git ~/beastphone-build
cd ~/beastphone-build
```

**Windows path (optional):** same folder at `C:\Users\<you>\beastphone-build`

If your Windows username is not `Anshul`, set before running scripts:

```bash
export BEASTPHONE_WIN_USER="YourName"
```

### 2. Bootstrap (once)

```bash
bash ~/beastphone-build/01-bootstrap-ubuntu.sh
```

### 3. Full pipeline (long — hours)

```bash
bash ~/beastphone-build/run-full-pipeline.sh
```

Or step by step:

```bash
bash 02-aosp-sync.sh          # repo sync (~hours, ~350GB)
bash 03-aosp-build.sh         # Phase 1 GSI system.img
bash 50-handoff-orchestrator.sh  # Phase 2 + export v1 tarball
bash 39-export-initrd.sh      # initrd + v2 tarball
bash 40-verify-initrd.sh      # sanity check
```

### 4. Download artifacts

From Windows:

- `C:\Users\<you>\beastphone-build\beastphone-android-guest-v2-initrd.tar.gz`
- `EXPORT_REPORT.txt` (sizes + SHA256)

Extract on local PC to BeastBrowser runtime path (see BeastPhone docs).

---

## Version update (Android 14 → 15, new `rXX`)

Edit **one file**: `VERSION.conf`

```bash
AOSP_TAG="android-15.0.0_r34"      # new tag
LUNCH_GSI="aosp_x86_64-ap3a-userdebug"
LUNCH_PHASE2="sdk_phone64_x86_64-ap3a-userdebug"
KERNEL_PREBUILT_REL="kernel/prebuilts/..."  # verify in new tree
```

Then:

```bash
rm -rf ~/aosp/out   # recommended on major version bump
bash 02-aosp-sync.sh
bash run-full-pipeline.sh
```

Details: [docs/VERSION-UPDATE.md](docs/VERSION-UPDATE.md)

---

## Google Drive upload (optional)

1. Copy `rclone-auth.txt.example` → `rclone-auth.txt` (OAuth token — **never commit**)
2. `python3 36-setup-rclone-drive.py`
3. `bash 38-upload-guest-tarball.sh`

---

## Repo layout

```
VERSION.conf          ← version pins (edit on bump)
lib/common.sh         ← shared paths
01-bootstrap-ubuntu.sh
02-aosp-sync.sh
03-aosp-build.sh      ← Phase 1 GSI
06-phase2-emu64x-build.sh
05-export-beastphone.sh
39-export-initrd.sh
50-handoff-orchestrator.sh
run-full-pipeline.sh
docs/                 ← VM requirements, restart guide
releases/             ← EXPORT_REPORT + checksums per release
```

---

## Requirements

- Ubuntu 22.04 (WSL2 on Windows or native Linux VM)
- 64 GB RAM minimum, 128 GB recommended
- 512 GB–1 TB disk
- See [docs/VM-REQUIREMENTS.md](docs/VM-REQUIREMENTS.md)

---

## About

Part of the **BeastBrowser** ecosystem — [beastbrowser.com](https://beastbrowser.com)

Built and maintained by **Rohit Srivastav** for the BeastPhone guest stack (crosvm + WHPX on Windows).

---

## License

Scripts: use freely for BeastPhone / internal builds.  
AOSP artifacts follow Android Open Source Project licenses.
