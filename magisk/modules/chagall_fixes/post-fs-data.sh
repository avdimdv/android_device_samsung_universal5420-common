#!/system/bin/sh
# /vendor/etc/audio_effects.xml = this module's AOSP pre-processing config (audio_effects.base.xml),
# plus the JamesDSP library/effect when the ainur_jamesdsp module is active. JamesDSP ships its own
# copy of the same file, generated from the stock one (broken LifeVibes AEC), so that copy gets the
# same content. Written with "cat >" to keep inode and SELinux label (works before or after mount).
MODDIR=${0%/*}
BASE=$MODDIR/audio_effects.base.xml
OUT=$MODDIR/system/vendor/etc/audio_effects.xml
J=/data/adb/modules/ainur_jamesdsp
TMP=$MODDIR/audio_effects.gen.xml

if [ -d "$J" ] && [ ! -f "$J/disable" ] && [ ! -f "$J/remove" ] &&
   [ -n "$(find "$J/system" -name libjamesdsp.so 2>/dev/null | head -n 1)" ]; then
  awk '{ print }
       /<libraries>/ { print "        <library name=\"jdsp\" path=\"libjamesdsp.so\"/>" }
       /<effects>/   { print "        <effect name=\"jamesdsp\" library=\"jdsp\" uuid=\"f27317f4-c984-4de6-9a90-545759495bf2\"/>" }' \
      "$BASE" > "$TMP"
else
  cp "$BASE" "$TMP"
fi

cat "$TMP" > "$OUT"
[ -f "$J/system/vendor/etc/audio_effects.xml" ] && cat "$TMP" > "$J/system/vendor/etc/audio_effects.xml"
rm -f "$TMP"
