# VM / RDP requirements

See also `NEW-RDP-REQUIREMENTS.txt` in repo root (seller checklist).

## Minimum

| Item | Value |
|------|-------|
| OS | Ubuntu 22.04 or Windows 11 + WSL2 Ubuntu 22.04 |
| RAM | 64 GB (128 GB preferred) |
| Disk | 512 GB usable (1 TB better) |
| CPU | 16+ vCPUs (32 preferred) |

## Windows + WSL2

- Nested virtualization **enabled**
- Not Trusted Launch
- Gen 2 VM
- Azure: Standard_D32s_v5 or similar DSv5 family

## Do not use for runtime

- Android Emulator / AVD images
- QEMU/Docker as BeastPhone guest runtime (build host only)

## Disk layout (typical)

| Path | Size |
|------|------|
| `~/aosp` | ~350 GB source |
| `~/aosp/out` | ~100+ GB build output |
| `~/.ccache` | optional 50–100 GB (speed) |

## Clone path convention

Clone this repo to `~/beastphone-build` so Windows path is:

`C:\Users\<you>\beastphone-build`

Tarballs and `EXPORT_REPORT.txt` are written there for easy RDP download.
