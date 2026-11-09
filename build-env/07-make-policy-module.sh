#!/bin/bash
# Package configs/audio/audio_policy_configuration.xml (no Earpiece) as a Magisk module.
# Run in WSL:  bash 07-make-policy-module.sh   -> <repo>/artifacts/TabS_voip_speaker.zip
set -e
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
SRC=$REPO/configs/audio/audio_policy_configuration.xml
TPL=$REPO/audio-session-2026-11/magisk/TabS_mic_fix.zip
ART=${ART:-$REPO/artifacts}
OUT=$ART/TabS_voip_speaker.zip
VER=${VER:-1}
python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$SRC"
mkdir -p "$ART"
W=$(mktemp -d)
cd "$W"
unzip -q "$TPL" META-INF/* customize.sh
mkdir -p system/vendor/etc
sed 's/\r$//' "$SRC" > system/vendor/etc/audio_policy_configuration.xml   # Windows checkout is CRLF
cat > module.prop <<P
id=chagall_voip_speaker
name=Tab S 10.5 VoIP to speaker (no earpiece)
version=v$VER
versionCode=$VER
author=Dmitry
description=audio_policy_configuration.xml without Earpiece: VoIP calls use speaker / wired / BT headset instead of a non-existent earpiece.
P
rm -f "$OUT"; zip -qr "$OUT" .
rm -rf "$W"
ls -l "$OUT"
