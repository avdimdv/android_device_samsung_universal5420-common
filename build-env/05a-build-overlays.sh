#!/bin/bash
# Build the runtime resource overlays in magisk/overlays/<Name>/ (AndroidManifest.xml + res/) into
#   $TOP/out/target/product/chagallwifi/magisk-overlays/<Name>.apk
# with the tree's aapt2 and apksigner (test key), so 05-make-magisk-modules.sh can pick them up via
# the module's `files` list. Done by hand instead of as an Android.mk module because Soong does not
# notice new Android.mk files in this tree (cached module paths).
# Needs: a built tree (aapt2, framework-res) and apksigner (`m apksigner` once).
# Run in WSL:  bash 05a-build-overlays.sh
set -eo pipefail
TOP=${TOP:-$HOME/lineage}
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
OUT=$TOP/out/target/product/chagallwifi/magisk-overlays
AAPT2=$TOP/out/host/linux-x86/bin/aapt2
APKSIGNER=$TOP/out/host/linux-x86/bin/apksigner
FWRES=$TOP/out/target/product/chagallwifi/system/framework/framework-res.apk
KEY=$TOP/build/target/product/security/testkey
for t in "$AAPT2" "$APKSIGNER" "$FWRES"; do [ -e "$t" ] || { echo "missing $t (build the tree / m apksigner)"; exit 1; }; done
mkdir -p "$OUT"
for D in "$REPO"/magisk/overlays/*/; do
  N=$(basename "$D"); W=$(mktemp -d)
  "$AAPT2" compile --dir "$D/res" -o "$W/res.zip"
  "$AAPT2" link -o "$W/unsigned.apk" -I "$FWRES" --manifest "$D/AndroidManifest.xml" \
    --min-sdk-version 29 --target-sdk-version 29 "$W/res.zip"
  "$APKSIGNER" sign --key "$KEY.pk8" --cert "$KEY.x509.pem" --out "$OUT/$N.apk" "$W/unsigned.apk"
  rm -rf "$W"
  echo "$N.apk  $(md5sum < "$OUT/$N.apk" | cut -d' ' -f1)"
done
