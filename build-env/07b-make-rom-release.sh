#!/bin/bash
# Package our own Tab S ROM for a GitHub release into <repo>/artifacts/rom-release/:
#   lineage-17.1-<date>-UNOFFICIAL-chagallwifi.zip, key-migration-hazouph-to-aosp.zip,
#   README.md (from rom-release/README.md), SHA256SUMS
# and check every file for build identity / personal data (same rules as 07-make-release.sh).
# Run in WSL after 04-build.sh bacon:  bash 07b-make-rom-release.sh [rom.zip]
set -eo pipefail
TOP=${TOP:-$HOME/lineage}
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
REL=$REPO/artifacts/rom-release
ROM=${1:-$(ls -t "$TOP"/out/target/product/chagallwifi/lineage-17.1-*-UNOFFICIAL-chagallwifi.zip | head -1)}
[ -f "$ROM" ] || { echo "no ROM zip: $ROM"; exit 1; }

rm -rf "$REL"; mkdir -p "$REL"
cp "$ROM" "$REL/"
bash "$REPO/build-env/05b-make-key-migration.sh" >/dev/null
cp "$REPO/artifacts/key-migration-hazouph-to-aosp.zip" "$REL/"
tr -d '\r' < "$REPO/rom-release/README.md" > "$REL/README.md"

FAIL=0
# --- build identity inside the ROM (see 04-build.sh: BUILD_USERNAME/BUILD_HOSTNAME)
OK_USER='^(lineage|android|builder|nobody)$'
OK_HOST='^(localhost|android-build|wsl-build|localhost\.localdomain)$'
OK_INCR='^eng\.(lineage?|android|builder)\.[0-9]{8}\.[0-9]{6}$'
inc=$(unzip -p "$ROM" META-INF/com/android/metadata | sed -n 's/^post-build-incremental=//p')
echo "$inc" | grep -qE "$OK_INCR" || { echo "LEAK: post-build-incremental=$inc"; FAIL=1; }
BP=$TOP/out/target/product/chagallwifi/system/build.prop
for kv in "ro.build.user:$OK_USER" "ro.build.host:$OK_HOST" "ro.build.version.incremental:$OK_INCR"; do
  k=${kv%%:*}; re=${kv#*:}; v=$(sed -n "s/^$k=//p" "$BP" | head -1)
  echo "$v" | grep -qE "$re" || { echo "LEAK in build.prop: $k=$v"; FAIL=1; }
done
# the out dir must be the build the zip came from
[ "$(unzip -p "$ROM" META-INF/com/android/metadata | sed -n 's/^post-timestamp=//p')" = \
  "$(sed -n 's/^ro.build.date.utc=//p' "$BP")" ] || { echo "out/ system/build.prop is not from this zip"; FAIL=1; }
# kernel banner (compile.h): user@host
kb=$(strings -a "$TOP/out/target/product/chagallwifi/obj/KERNEL_OBJ/include/generated/compile.h" 2>/dev/null | sed -n 's/.*LINUX_COMPILE_BY "\(.*\)"/\1/p;s/.*LINUX_COMPILE_HOST "\(.*\)"/\1/p' | paste -sd@)
echo "kernel built by: ${kb:-?}"
echo "$kb" | grep -qE '^(nobody|lineage|builder)@(android-build|localhost)$' || { echo "LEAK: kernel banner $kb"; FAIL=1; }

# --- e-mail addresses in the small files (README, key-migration zip). The ROM image itself contains
# many public addresses (licences, AOSP test cert), so it is covered by the identity checks above.
NAMEPAT='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
LOCAL=$REPO/build-env/leak-patterns.local
[ -f "$LOCAL" ] && NAMEPAT="$NAMEPAT|$(tr -d '\r' < "$LOCAL" | grep -vE '^[[:space:]]*(#|$)' | paste -sd'|')"
D=$(mktemp -d); unzip -oq "$REL/key-migration-hazouph-to-aosp.zip" -d "$D"; cp "$REL/README.md" "$D/"
bad=$( (cd "$D" && grep -raoEi "$NAMEPAT" . 2>/dev/null) | sort -u || true); rm -rf "$D"
[ -z "$bad" ] || { echo "LEAK: $bad"; FAIL=1; }
# the user's own name/host must not be anywhere in the ROM's text metadata either
if [ -f "$LOCAL" ]; then
  unzip -p "$ROM" META-INF/com/android/metadata META-INF/com/google/android/updater-script \
    | grep -qiE "$(tr -d '\r' < "$LOCAL" | grep -vE '^[[:space:]]*(#|$)' | paste -sd'|')" \
    && { echo "LEAK: local pattern in ROM metadata"; FAIL=1; }
  grep -qiE "$(tr -d '\r' < "$LOCAL" | grep -vE '^[[:space:]]*(#|$)' | paste -sd'|')" "$BP" \
    && { echo "LEAK: local pattern in build.prop"; FAIL=1; }
fi

(cd "$REL" && sha256sum *.zip > SHA256SUMS && cat SHA256SUMS)
[ "$FAIL" = 0 ] && echo "clean - $REL" || { echo ">>> do not publish"; exit 1; }
