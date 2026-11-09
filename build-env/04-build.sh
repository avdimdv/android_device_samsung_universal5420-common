#!/bin/bash
# Run in WSL:  bash 04-build.sh [target...]
#   no args       -> libbt-vendor + audio HAL only (minutes, for Magisk testing)
#   bacon         -> full flashable ROM zip (hours)
set -e
TOP=${TOP:-$HOME/lineage}
cd "$TOP"
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR=$HOME/.ccache
ccache -M 40G >/dev/null
export LC_ALL=C
source build/envsetup.sh
# HazouPH security/compat patches (idempotent: skips patches already applied)
if [ ! -f .patches-applied ]; then
  bash device/samsung/universal5420-common-patches/apply_patch.sh || exit 1
  [ -f device/samsung/universal5420-common-patches/Android.mk ] && { echo "PATCHES FAILED"; exit 1; }
  touch .patches-applied
fi
breakfast chagallwifi ${VARIANT:-userdebug}  # BoardConfig uses SELINUX_IGNORE_NEVERALLOWS -> userdebug only (tablet's "user" is spoofed by Magisk props)
if [ $# -eq 0 ]; then set -- libbt-vendor audio.primary.universal5420; fi
m -j$(nproc) "$@" || { echo "BUILD FAILED"; exit 1; }
