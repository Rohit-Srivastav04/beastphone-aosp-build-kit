#!/usr/bin/env bash
BEASTPHONE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BEASTPHONE_KIT/lib/common.sh"
INITRD="$EXPORT_DIR/initrd/initrd.img"
test -f "$INITRD" || { echo "Missing $INITRD"; exit 1; }
ls -lh "$INITRD"
file "$INITRD"
cpio -t < "$INITRD" 2>/dev/null | grep -E '^init$|lib/modules' | head -15
