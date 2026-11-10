#!/bin/bash
# Build the chagallwifi kernel (zImage) standalone, with the ROM's toolchain and defconfig.
#   bash 06-build-kernel.sh           -> current checkout of kernel/samsung/exynos5420 (incl. patches/)
#   bash 06-build-kernel.sh <git-rev> -> that commit, in a separate git worktree ~/kbuild/src-<rev>
# Output: ~/kbuild/out-<tag>/arch/arm/boot/zImage
# Build stamps default to those of the kernel HazouPH shipped (uname -v on the tablet), so an
# unmodified source can be compared byte-for-byte with the kernel in a boot.img backup.
set -eo pipefail
TOP=${TOP:-$HOME/lineage}
K=$TOP/kernel/samsung/exynos5420
TC=$TOP/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-
REV=${1:-}
LV=()
if [ -n "$REV" ]; then
  SRC=$HOME/kbuild/src-$REV; TAG=$REV
  [ -d "$SRC" ] || git -C "$K" worktree add -f --detach "$SRC" "$REV" >/dev/null 2>&1
  # scripts/setlocalversion only appends "+" (untagged git tree) when .git is a directory;
  # in a worktree it is a file, so add it explicitly to match the shipped "3.4.113+".
  LV=(LOCALVERSION=+)
else
  SRC=$K; TAG=tree
fi
OUT=$HOME/kbuild/out-$TAG
rm -rf "$OUT"; mkdir -p "$OUT"
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-nobody}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-android-build}
export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-"Thu Jan 2 20:32:35 CET 2025"}
M=(make -C "$SRC" O="$OUT" ARCH=arm CROSS_COMPILE="$TC" "${LV[@]}" -j"$(nproc)")
"${M[@]}" lineageos_chagallwifi_defconfig > "$OUT/build.log" 2>&1
"${M[@]}" zImage >> "$OUT/build.log" 2>&1 || { tail -30 "$OUT/build.log"; echo "KERNEL BUILD FAILED"; exit 1; }
Z=$OUT/arch/arm/boot/zImage
echo "built $TAG ($(git -C "$SRC" log -1 --format='%h %s'))"
echo "  $(strings "$OUT/vmlinux" | grep -m1 '^Linux version')"
echo "  zImage $(stat -c %s "$Z") bytes  md5 $(md5sum < "$Z" | cut -d' ' -f1)"
