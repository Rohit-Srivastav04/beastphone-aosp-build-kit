#!/usr/bin/env bash
# One-command pipeline: sync → Phase1 → Phase2 → export → initrd export
set -euo pipefail
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"

echo "=== BeastPhone full pipeline ==="
echo "Kit: $BEASTPHONE_KIT | AOSP tag: $AOSP_TAG"

bash "$BEASTPHONE_KIT/02-aosp-sync.sh"
bash "$BEASTPHONE_KIT/03-aosp-build.sh"
bash "$BEASTPHONE_KIT/50-handoff-orchestrator.sh"
bash "$BEASTPHONE_KIT/39-export-initrd.sh"

echo "=== Pipeline complete. Tarballs in $WIN_PACK ==="
