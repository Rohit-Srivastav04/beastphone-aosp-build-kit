#!/usr/bin/env bash
# Shared paths for BeastPhone AOSP build scripts.
if [ -n "${BEASTPHONE_COMMON_LOADED:-}" ]; then
  return 0
fi
BEASTPHONE_COMMON_LOADED=1

# Kit root = folder containing VERSION.conf
if [ -z "${BEASTPHONE_KIT:-}" ]; then
  _here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [ -f "$_here/VERSION.conf" ]; then
    BEASTPHONE_KIT="$_here"
  elif [ -f "$HOME/beastphone-build/VERSION.conf" ]; then
    BEASTPHONE_KIT="$HOME/beastphone-build"
  else
    BEASTPHONE_KIT="$_here"
  fi
fi
export BEASTPHONE_KIT

if [ -f "${BEASTPHONE_KIT}/VERSION.conf" ]; then
  # shellcheck disable=SC1091
  source "${BEASTPHONE_KIT}/VERSION.conf"
fi

export HOME="${HOME:-/home/$(whoami)}"
export AOSP_DIR="${AOSP_DIR:-$HOME/aosp}"
export EXPORT_DIR="${EXPORT_DIR:-$HOME/beastphone-export}"
export BUILD_LOG_DIR="${BUILD_LOG_DIR:-$BEASTPHONE_KIT}"
export PATH="${HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

WIN_USER="${BEASTPHONE_WIN_USER:-Anshul}"
export WIN_PACK="${WIN_PACK:-/mnt/c/Users/${WIN_USER}/beastphone-build}"

GSI_OUT="${AOSP_DIR}/out/target/product/generic_x86_64"
EMU_OUT="${AOSP_DIR}/out/target/product/emu64x"
PREBUILT_K="${AOSP_DIR}/${KERNEL_PREBUILT_REL:-kernel/prebuilts/6.6/x86_64/kernel-6.6}"
