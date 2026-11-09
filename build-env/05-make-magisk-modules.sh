#!/bin/bash
# Build Magisk modules from magisk/modules/<id>/ (module.prop + files list) and magisk/template/.
# Files are taken from the WSL build tree, so run 03-overlay (and 04-build for libraries) first.
# Run in WSL:  bash 05-make-magisk-modules.sh [module-id ...]    (default: all)
#   -> <repo>/artifacts/<module-id>.zip
set -eo pipefail
TOP=${TOP:-$HOME/lineage}
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
ART=${ART:-$REPO/artifacts}
MODS=${*:-$(ls "$REPO/magisk/modules")}
mkdir -p "$ART"
for ID in $MODS; do
  M=$REPO/magisk/modules/$ID
  [ -f "$M/module.prop" ] || { echo "no such module: $ID"; exit 1; }
  W=$(mktemp -d)
  cp -r "$REPO/magisk/template/." "$W/"
  cp "$M/module.prop" "$W/"
  grep -v '^\s*#' "$M/files" | while read -r DEST SRC; do
    [ -n "$DEST" ] || continue
    [ -f "$TOP/$SRC" ] || { echo "$ID: missing $TOP/$SRC"; exit 1; }
    mkdir -p "$W/$(dirname "$DEST")"
    cp "$TOP/$SRC" "$W/$DEST"
    case "$DEST" in *.xml) python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$W/$DEST" ;; esac
    echo "$ID: $DEST  $(md5sum < "$W/$DEST" | cut -d' ' -f1)"
  done
  OUT=$ART/$ID.zip
  rm -f "$OUT"; (cd "$W" && zip -qr "$OUT" .)
  rm -rf "$W"
  echo "  -> $OUT"
done
