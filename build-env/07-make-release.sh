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
  # author is published in the Magisk app's module list, so it uses the same pseudonym as the
  # git identity - never a real name. See the leak scan at the bottom of this file.
  { echo "id=${1%.zip}"; echo "name=Tab S 10.5 (SM-T800) kernel: $5"; echo "version=v1"; echo "versionCode=1"; echo "author=avdim"
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
# TOP was never set in this script, so the first ls looked in /out/... and failed; with
# `set -eo pipefail` at the top that aborted the whole script *before* any of these checks ran -
# the leak scan silently did nothing while the zips above it were still written. Define it, and
# make a missing zip a normal empty result rather than an error.
TOP=${TOP:-$HOME/lineage}
first() { ls $1 2>/dev/null | head -1 || true; }
ROM=${ROM:-$(first "$TOP/out/target/product/chagallwifi/lineage-*-chagallwifi.zip")}
ROM=${ROM:-$(first "$HOME/lineage/out/target/product/chagallwifi/lineage-*-chagallwifi.zip")}

# The check is an ALLOWLIST, not a blacklist. This repo is public, and a blacklist would have to
# spell out the very account name, machine name and person it protects - publishing that is worse
# than the leak it detects. Anything not produced by these scripts therefore fails, which is the
# safe direction. Extra strings can be kept out of the repo in build-env/leak-patterns.local
# (git-ignored); if that file exists its lines are OR-ed into the scan.
OK_USER='^(lineage|android|builder|nobody)$'
OK_HOST='^(localhost|android-build|wsl-build|localhost\.localdomain)$'
OK_INCR='^(eng\.(lineage?|android|builder|alpha)\.[0-9]{8}\.[0-9]{6}|lineage_[A-Za-z0-9._-]+)$'
LOCAL_PAT=''
# tr -d '\r' is not cosmetic: this file lives on the Windows checkout, so it arrives CRLF, and
# every pattern then has a trailing CR - "name\r" matches nothing, so the scan would silently
# pass everything. Verified with a negative test, not by reading the code.
if [ -f "$REPO/build-env/leak-patterns.local" ]; then
  LOCAL_PAT=$(tr -d '\r' < "$REPO/build-env/leak-patterns.local" | grep -vE '^[[:space:]]*(#|$)' | paste -sd'|')
fi
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
  echo "checking ROM zip for build identity: $ROM"
  LEAK=0
  unzip -p "$ROM" 'META-INF/com/android/metadata' 2>/dev/null > /tmp/rel-meta || true
  inc=$(sed -n 's/^post-build-incremental=//p' /tmp/rel-meta | head -1)
  if [ -n "$inc" ] && ! echo "$inc" | grep -qE "$OK_INCR"; then
    echo "  LEAK: metadata post-build-incremental is not a release-style value: $inc"; LEAK=1
  fi
  # build.prop lives inside system.img; unpack the target_files instead, it is the same content
  TF=$(first "$HOME/lineage/out/target/product/chagallwifi/obj/PACKAGING/target_files_intermediates/*/SYSTEM/build.prop")
  if [ -n "$TF" ]; then
    for kv in ro.build.user:$OK_USER ro.build.host:$OK_HOST; do
      k=${kv%%:*}; re=${kv#*:}
      v=$(sed -n "s/^$k=//p" "$TF" | head -1)
      [ -n "$v" ] && ! echo "$v" | grep -qE "$re" && { echo "  LEAK in build.prop: $k=$v"; LEAK=1; }
    done
    for k in ro.build.version.incremental ro.system.build.version.incremental; do
      v=$(sed -n "s/^$k=//p" "$TF" | head -1)
      [ -n "$v" ] && ! echo "$v" | grep -qE "$OK_INCR" && { echo "  LEAK in build.prop: $k=$v"; LEAK=1; }
    done
  else
    echo "  (target_files SYSTEM/build.prop not found - cannot verify)"
  fi
  [ "$LEAK" = 0 ] && echo "  clean" || echo "  >>> do not publish this zip; rebuild via 04-build.sh"
fi

# --- every published artifact, not just the ROM.
# The scan above only looked at build.prop and zip metadata, so it missed the other way a name
# gets out: a literal in module.prop, which the Magisk app shows in its module list. v5 shipped a
# real first name there while every build-property check reported clean. So scan the finished zips
# themselves - generically: any e-mail address, and module.prop's author against an allowlist.
echo "checking published artifacts for personal identity"
NAMEPAT="[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
[ -n "$LOCAL_PAT" ] && NAMEPAT="$NAMEPAT|$LOCAL_PAT"
OK_AUTHOR='^(avdim|lineage|LineageOS)$'
# Exact addresses that are public and expected inside binaries (matched whole, case-insensitive):
#   android@android.com - subject of AOSP's public test certificate (the overlays are signed with
#                         build/target/product/security/testkey)
#   ljzyal@gmail.com    - original author of the fingerprint HAL, `.author` in fingerprint.c
#                         (upstream source, part of HazouPH's public tree)
OK_ADDR='android@android\.com|ljzyal@gmail\.com'
LEAK=0
for z in "$REL"/*.zip; do
  [ -f "$z" ] || continue
  D=$(mktemp -d); unzip -oq "$z" -d "$D" 2>/dev/null
  # text members verbatim, plus the kernel image via strings (zImage is compressed, so a plain
  # grep cannot see LINUX_COMPILE_BY/HOST in linux_banner - check compile.h in the kernel tree).
  # The "|| true" matters: with `set -eo pipefail` a grep that finds nothing returns 1, which
  # inside a command substitution would abort the whole script on the clean path.
  # -o lists every match as file:match, so an allowed address does not hide a second, real one
  # in the same file.
  bad=$( (cd "$D" && grep -raoEi "$NAMEPAT" . 2>/dev/null) | grep -viE ":($OK_ADDR)\$" \
         | cut -d: -f1 | sed 's#^\./##' | sort -u | tr '\n' ' ' || true)
  bad="$bad $(strings -a "$D"/kernel/zImage 2>/dev/null | grep -oiE "$NAMEPAT" | sort -u | tr '\n' ' ' || true)"
  bad=$(echo "$bad" | sed 's/^ *//;s/ *$//')
  au=$(sed -n 's/^author=//p' "$D/module.prop" 2>/dev/null | head -1)
  if [ -n "$au" ] && ! echo "$au" | grep -qE "$OK_AUTHOR"; then
    bad="$bad module.prop:author=$au"
  fi
  if [ -n "$bad" ]; then echo "  LEAK $(basename "$z"): $bad"; LEAK=1; else echo "  clean: $(basename "$z")"; fi
  rm -rf "$D"
done
[ "$LEAK" = 0 ] || echo "  >>> do not publish; fix the source and re-run this script"

ls -la "$REL"
