#!/bin/bash
# Package audio-session-2026-11/config/mixer_paths_0.micfix.xml as the chagall_mic_fix Magisk module
# (same id as the original, so installing it replaces v1).
# Run in WSL:  bash 06-make-mixer-module.sh   -> <repo>/artifacts/TabS_mic_fix.zip
set -e
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
SRC=$REPO/audio-session-2026-11/config/mixer_paths_0.micfix.xml
TPL=$REPO/audio-session-2026-11/magisk/TabS_mic_fix.zip
ART=${ART:-$REPO/artifacts}
OUT=$ART/TabS_mic_fix.zip
VER=${VER:-2}
xmllint --noout "$SRC" 2>/dev/null || python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$SRC"
mkdir -p "$ART"
W=$(mktemp -d)
cd "$W"
unzip -q "$TPL" META-INF/* customize.sh
mkdir -p system/vendor/etc && cp "$SRC" system/vendor/etc/mixer_paths_0.xml
cat > module.prop <<P
id=chagall_mic_fix
name=Tab S 10.5 mic gain + BT SCO clock fix
version=v$VER
versionCode=$VER
author=Dmitry
description=mixer_paths_0.xml: main mic +15 dB, out-of-range values fixed, BT SCO mic keeps AIF2 Master (FLL2 not stopped).
P
rm -f "$OUT"; zip -qr "$OUT" .
rm -rf "$W"
ls -l "$OUT"; md5sum "$SRC"
