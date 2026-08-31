# Restart / resize safe guide

## Data that survives VM restart

| Data | Location |
|------|----------|
| AOSP source | `~/aosp` |
| Build progress | `~/aosp/out` |
| This kit | `~/beastphone-build` |
| Windows files | `C:\Users\<you>\` |

RDP disconnect on restart is normal. Reconnect after 2–5 minutes.

## After restart — resume build

```bash
cd ~/beastphone-build
# If Phase 1 was running:
bash 03-aosp-build.sh
# Or resume handoff watcher:
bash 50-handoff-orchestrator.sh
```

## Do not

- Delete VM or OS disk
- Delete `~/aosp` unless starting fresh sync

## Optional: auto-resume on boot

Use Windows-side scripts from your full RDP setup if installed (`INSTALL-AUTO-RESUME.ps1`).
