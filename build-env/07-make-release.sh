#!/bin/bash
# Build the package for other users into <repo>/artifacts/release/:
#   chagall_fixes.zip          Magisk module (05-make-magisk-modules.sh)
#   chagall_kernel_nohook.zip  kernel swap zip (magisk/kernel-zip) with our kernel
#   chagall_kernel_stock.zip   same installer with the ROM's kernel (undo)
#   README.md, source/ (patches without e-mail addresses), SHA256SUMS
# Run in WSL after 03-overlay (+ 04-build for the BT library):  bash 07-make-release.sh
# Kernels: artifacts/kernel-nohook/zImage (06-build-kernel.sh / m kernel) and the ROM's kernel
# extracted from the stock boot image (artifacts/partbak-*/zImage.running).
set -eo pipefail
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
ART=$REPO/artifacts
REL=$ART/release
OURS=${OURS:-$ART/kernel-nohook/zImage}
STOCK=${STOCK:-$(ls "$ART"/partbak-*/zImage.running | head -1)}
STOCK_MD5=86f50505f53dfd8780a8eca17398ca63      # kernel in HazouPH's ROM (built from 73a7ba1f)
BASE_REV=lineage-17.1-deathly                    # upstream branch the device-tree diff is against

rm -rf "$REL"; mkdir -p "$REL/source"
[ "$(md5sum < "$STOCK" | cut -c1-32)" = "$STOCK_MD5" ] || { echo "stock kernel md5 mismatch: $STOCK"; exit 1; }
OURS_MD5=$(md5sum < "$OURS" | cut -c1-32)

# --- source (GPL): patches with personal e-mail addresses removed
strip_mail() { sed -E 's/^(From|Co-Authored-By): ([^<]*)<[^>]*>/\1: \2<>/; s/ <>$//'; }
for p in "$REPO"/patches/kernel/samsung/exynos5420/*.patch; do strip_mail < "$p" > "$REL/source/kernel-$(basename "$p")"; done
for p in "$REPO"/patches/device/samsung/chagall-common/*.patch; do strip_mail < "$p" > "$REL/source/chagall-common-$(basename "$p")"; done
git -C "$REPO" diff "$BASE_REV" HEAD -- BoardConfigCommon.mk bluetooth configs/audio > "$REL/source/universal5420-common.diff"
echo "kernel base commit: $(tr -d ' \r\n' < "$REPO/patches/kernel/samsung/exynos5420/BASE")" > "$REL/source/BASE.txt"
cp "$REPO/magisk/release/README.md" "$REL/README.md"

# --- module
ART=$REL bash "$REPO/build-env/05-make-magisk-modules.sh" chagall_fixes
(cd "$REL" && zip -q chagall_fixes.zip README.md)

# --- kernel zips
kzip() {  # <zip name> <zImage> <md5> <description>
  local W; W=$(mktemp -d)
  cp -r "$REPO/magisk/kernel-zip/." "$W/"
  mkdir -p "$W/kernel"; cp "$2" "$W/kernel/zImage"
  printf 'KNAME="%s"\nKMD5=%s\nACCEPT="%s %s"\n' "$4" "$3" "$STOCK_MD5" "$OURS_MD5" > "$W/kernel/info"
  cp "$REL/README.md" "$W/"; cp -r "$REL/source" "$W/"
  chmod 0755 "$W/META-INF/com/google/android/update-binary"
  sh -n "$W/META-INF/com/google/android/update-binary"
  rm -f "$REL/$1"; (cd "$W" && zip -qr "$REL/$1" .); rm -rf "$W"
  echo "$1: kernel $3"
}
kzip chagall_kernel_nohook.zip "$OURS"  "$OURS_MD5"  "hook-free kernel (73a7ba1f + Wolfson Control hook removed)"
kzip chagall_kernel_stock.zip  "$STOCK" "$STOCK_MD5" "ROM's original kernel (73a7ba1f)"

(cd "$REL" && sha256sum *.zip > SHA256SUMS && cat SHA256SUMS)
if grep -rIl -E '[A-Za-z0-9._-]+@[A-Za-z0-9-]+\.[a-z]{2,}' "$REL/source" "$REL/README.md" | grep -v noreply; then
  echo "WARNING: files above still contain an e-mail address"; fi
ls -la "$REL"
