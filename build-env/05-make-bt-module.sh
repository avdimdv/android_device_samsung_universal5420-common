#!/bin/bash
# Package the freshly built libbt-vendor.so as a Magisk module for on-device testing.
# Run in WSL:  bash 05-make-bt-module.sh
#   -> <repo>/artifacts/TabS_bt_sco_fix.zip, libbt-vendor.so, libbt-vendor.so.md5
set -e
TOP=${TOP:-$HOME/lineage}
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
LIB=$TOP/out/target/product/chagallwifi/system/vendor/lib/libbt-vendor.so
TPL=$REPO/audio-session-2026-11/magisk/TabS_bt_call_test.zip
ART=${ART:-$REPO/artifacts}
OUT=$ART/TabS_bt_sco_fix.zip
mkdir -p "$ART"
W=$(mktemp -d)
cd "$W"
unzip -q "$TPL" META-INF/* customize.sh
mkdir -p system/vendor/lib && cp "$LIB" system/vendor/lib/
cat > module.prop <<P
id=chagall_bt_sco_fix
name=Tab S 10.5 BT call fix (libbt rebuilt)
version=v1
versionCode=1
author=Dmitry
description=libbt-vendor.so rebuilt with BOARD_CUSTOM_BT_CONFIG + BTHW_FW_EXTENDED_CONFIGURATION (I2S slave). Disable if BT breaks.
P
rm -f "$OUT"; zip -qr "$OUT" .
rm -rf "$W"
cp "$LIB" "$ART/libbt-vendor.so"
md5sum "$LIB" | cut -d' ' -f1 > "$ART/libbt-vendor.so.md5"
ls -l "$ART"; cat "$ART/libbt-vendor.so.md5"
