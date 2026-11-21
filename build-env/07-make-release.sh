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
kzip() {  # <zip name> <zImage> <md5> <description> <short name>
  local W; W=$(mktemp -d)
  cp -r "$REPO/magisk/kernel-zip/." "$W/"
  mkdir -p "$W/kernel"; cp "$2" "$W/kernel/zImage"
  printf 'KNAME="%s"\nKMD5=%s\nACCEPT="%s %s"\n' "$4" "$3" "$STOCK_MD5" "$OURS_MD5" > "$W/kernel/info"
  cp "$REL/README.md" "$W/"; cp -r "$REL/source" "$W/"
  chmod 0755 "$W/META-INF/com/google/android/update-binary"
  # module.prop: the Magisk app installs every zip as a module (customize.sh does the swap)
  { echo "id=${1%.zip}"; echo "name=Tab S 10.5 (SM-T800) kernel: $5"; echo "version=v1"; echo "versionCode=1"; echo "author=Dmitry"
    echo "description=Marker only. Installing this zip swapped the kernel inside the boot image ($4). Removing the module does NOT change the kernel; install the other kernel zip for that."
  } > "$W/module.prop"
  sh -n "$W/META-INF/com/google/android/update-binary"; sh -n "$W/kernel/swap.sh"; sh -n "$W/customize.sh"
  rm -f "$REL/$1"; (cd "$W" && zip -qr "$REL/$1" .); rm -rf "$W"
  echo "$1: kernel $3"
}
kzip chagall_kernel_nohook.zip "$OURS"  "$OURS_MD5"  "hook-free kernel (73a7ba1f + Wolfson Control hook removed)" "hook-free"
kzip chagall_kernel_stock.zip  "$STOCK" "$STOCK_MD5" "ROM's original kernel (73a7ba1f)" "stock"

(cd "$REL" && sha256sum *.zip > SHA256SUMS && cat SHA256SUMS)
if grep -rIl -E '[A-Za-z0-9._-]+@[A-Za-z0-9-]+\.[a-z]{2,}' "$REL/source" "$REL/README.md" | grep -v noreply; then
  echo "WARNING: files above still contain an e-mail address"; fi

# --- the ROM zip is NOT built by this script, but if one exists it must be clean too.
# Without BUILD_USERNAME/BUILD_HOSTNAME in the environment, soong_ui takes them from the OS
# (build/soong/ui/build/kati.go:99-112) and the machine's account name ends up in the public
# artifact in several places at once: ro.build.user, ro.build.host, and via
# BUILD_NUMBER = eng.$(BUILD_USERNAME:0:6).<stamp> (version_defaults.mk:315) in
# ro.build.version.incremental, ro.system.build.version.incremental, ro.build.display.id and
# META-INF/com/android/metadata's post-build-incremental. 04-build.sh now exports generic values.
ROM=${ROM:-$(ls "$TOP"/out/target/product/chagallwifi/lineage-*-chagallwifi.zip 2>/dev/null | head -1)}
ROM=${ROM:-$(ls ~/lineage/out/target/product/chagallwifi/lineage-*-chagallwifi.zip 2>/dev/null | head -1)}
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
  echo "checking ROM zip for build identity: $ROM"
  LEAK=0
  unzip -p "$ROM" 'META-INF/com/android/metadata' 2>/dev/null > /tmp/rel-meta
  grep -qE 'eng\.(avdeev|avdeev\.|munich)' /tmp/rel-meta && { echo "  LEAK: metadata incremental"; LEAK=1; }
  # build.prop lives inside system.img; unpack the target_files instead, it is the same content
  TF=$(ls "$HOME"/lineage/out/target/product/chagallwifi/obj/PACKAGING/target_files_intermediates/*/SYSTEM/build.prop 2>/dev/null | head -1)
  if [ -n "$TF" ]; then
    for pat in 'ro.build.user=avdeev' 'ro.build.host=D-DA-NOTE' 'eng\.avdeev'; do
      grep -qE "$pat" "$TF" && { echo "  LEAK in SYSTEM/build.prop: $pat"; LEAK=1; }
    done
  else
    echo "  (target_files SYSTEM/build.prop not found - cannot verify)"
  fi
  [ "$LEAK" = 0 ] && echo "  clean" || echo "  >>> do not publish this zip; rebuild via 04-build.sh"
fi

ls -la "$REL"
