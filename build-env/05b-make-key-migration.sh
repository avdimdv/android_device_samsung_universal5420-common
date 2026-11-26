#!/bin/bash
# Build the TWRP zip that moves a HazouPH LineageOS 17.1 install to this ROM's signing keys
# (see key-migration/update-binary.in for what it does and why).
#   old certs: key-migration/hazouph-certs.txt (public certificates from his ROM, one per role)
#   new certs: the AOSP test certificates in the build tree
# Output: artifacts/key-migration-hazouph-to-aosp.zip
# Run in WSL:  bash 05b-make-key-migration.sh
set -eo pipefail
TOP=${TOP:-$HOME/lineage}
REPO=/mnt/d/SOURCES/android_device_samsung_universal5420-common
SEC=$TOP/build/make/target/product/security
OUT=$REPO/artifacts/key-migration-hazouph-to-aosp.zip
W=$(mktemp -d)
mkdir -p "$W/META-INF/com/google/android"

PAIRS=$W/pairs
: > "$PAIRS"
while read -r role old; do
  [ -n "$role" ] || continue
  pem=$SEC/$role.x509.pem
  [ -f "$pem" ] || { echo "missing $pem"; exit 1; }
  new=$(openssl x509 -in "$pem" -outform DER | xxd -p | tr -d '\n')
  echo "$role $old $new" >> "$PAIRS"
  echo "$role: $(echo -n "$old" | xxd -r -p | sha256sum | cut -c1-16)... -> $(basename "$pem")"
done < <(tr -d '\r' < "$REPO/key-migration/hazouph-certs.txt")
[ "$(wc -l < "$PAIRS")" = 5 ] || { echo "expected 5 certificates"; exit 1; }

# insert the pairs where @PAIRS@ stands
tr -d '\r' < "$REPO/key-migration/update-binary.in" \
  | awk -v f="$PAIRS" '/^@PAIRS@$/ { while ((getline l < f) > 0) print l; next } { print }' \
  > "$W/META-INF/com/google/android/update-binary"
echo "# dummy - the work is done by update-binary" > "$W/META-INF/com/google/android/updater-script"
rm -f "$OUT"
(cd "$W" && zip -qr -X "$OUT" META-INF)
rm -rf "$W"
echo "wrote $OUT  $(md5sum < "$OUT" | cut -d' ' -f1)"
