#!/bin/bash
# Refresh pif/pif.json - the certified-device identity the ROM's GmsIntegritySpoof hands to Google
# Play services (Play Integrity "Basic") - from Google's newest Pixel Canary build, then build the
# TWRP zip that installs it on a device.
#
# Same public sources as the Play Integrity Fix module's autopif.sh: the Android beta pages on
# developer.android.com (Pixel models), flash.android.com (newest Canary build of that model) and
# the Pixel security bulletin (its patch level). Nothing about this device is sent anywhere.
#
# Usage: bash pif/update-pif.sh [--zip-only]
#   writes pif/pif.json (only if the identity changed) and artifacts/pif-update-<id>.zip
#   exit 0 = changed, 3 = already current (zip rebuilt anyway), other = failure (pif.json untouched)
# Env: PIF_PRODUCT=bluejay_beta to force a model (default: keep the current one if Google still
#      offers it, else the first one listed).
set -eo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
JSON=$REPO/pif/pif.json
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
get() { curl -fsSL --max-time 30 --retry 2 -A "Mozilla/5.0" "$@"; }

if [ "$1" != "--zip-only" ]; then
  get https://developer.android.com/about/versions > "$T/v.html"
  BETA=$(grep -B4 -A2 'data-icon="preview' "$T/v.html" | grep -o 'href="/about/versions/[^"]*[0-9]"' | cut -d\" -f2 | head -1 || true)
  [ -n "$BETA" ] || BETA=$(grep -oE 'href="/about/versions/[0-9]{2}"' "$T/v.html" | cut -d\" -f2 | sort -ru | head -1)
  [ -n "$BETA" ] || { echo "no beta page found"; exit 1; }
  get "https://developer.android.com$BETA" > "$T/latest.html"
  # factory-image and OTA download pages list the supported Pixels; use whichever lists more
  best=""; bestn=0
  for u in $(grep -oE 'href="[^"]*/download(-ota)?"' "$T/latest.html" | cut -d\" -f2 | sort -u); do
    get "https://developer.android.com$u" > "$T/dl.html" || continue
    n=$(grep -c '<tr id=' "$T/dl.html" || true)
    [ "$n" -gt "$bestn" ] && { bestn=$n; cp "$T/dl.html" "$T/models.html"; best=$u; }
  done
  [ "$bestn" -gt 0 ] || { echo "no Pixel model list found"; exit 1; }
  python3 - "$T/models.html" > "$T/models.txt" <<'PY'
import re, sys
h = open(sys.argv[1], encoding="utf-8", errors="replace").read()
for m in re.finditer(r'<tr id="([a-z0-9_]+)">\s*<td>([^<]+)</td>', h):
    print(m.group(1) + "_beta", m.group(2).strip(), sep="\t")
PY
  [ -s "$T/models.txt" ] || { echo "could not parse the model list ($best)"; exit 1; }
  CUR=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["FINGERPRINT"].split("/")[1])' "$JSON" 2>/dev/null || true)
  WANT=${PIF_PRODUCT:-$CUR}
  LINE=$(grep -P "^${WANT}\t" "$T/models.txt" | head -1 || true)
  [ -n "$LINE" ] || LINE=$(head -1 "$T/models.txt")
  PRODUCT=${LINE%%$'\t'*}; MODEL=${LINE#*$'\t'}; DEVICE=${PRODUCT%_beta}

  get https://flash.android.com > "$T/flash.html"
  KEY=$(grep -o '<body data-client-config=.*' "$T/flash.html" | cut -d\; -f2 | cut -d\& -f1)
  [ -n "$KEY" ] || { echo "no flash.android.com key"; exit 1; }
  get -H "Referer: https://flash.android.com" \
    "https://content-flashstation-pa.googleapis.com/v1/builds?product=$PRODUCT&key=$KEY" > "$T/builds.json"
  get https://source.android.com/docs/security/bulletin/pixel > "$T/bulletin.html"

  python3 - "$T/builds.json" "$T/bulletin.html" "$JSON" "$PRODUCT" "$DEVICE" "$MODEL" > "$T/pif.json" <<'PY'
import json, re, sys
builds, bulletin, old, product, device, model = sys.argv[1:7]
data = json.load(open(builds))
def meta(b):  # canary flag and id sit in "previewMetadata" (a dict, older replies: top level)
    pm = b.get("previewMetadata", {})
    return pm if isinstance(pm, dict) else {}
canary = [b for b in data.get("flashstationBuild", data.get("builds", []))
          if b.get("canary") or meta(b).get("canary")]
if not canary:
    sys.exit("no Canary build for " + product)
b = canary[-1]
bid, inc = b["releaseCandidateName"], b["buildId"]
m = re.search(r"canary-(\d{4})(\d{2})", meta(b).get("id", b.get("id", "")))
month = f"{m.group(1)}-{m.group(2)}" if m else ""
h = open(bulletin, encoding="utf-8", errors="replace").read()
sp = re.search(r"<td>(%s-\d{2})</td>" % re.escape(month), h) if month else None
patch = sp.group(1) if sp else (month + "-05" if month else "")
first_api = {"bluejay": 32, "panther": 33, "cheetah": 33, "lynx": 33, "felix": 33, "tangorpro": 33,
             "shiba": 34, "husky": 34, "akita": 34, "tokay": 34, "caiman": 34, "komodo": 34,
             "comet": 34, "tegu": 35, "stallion": 35}.get(device, 36)
try:
    prev = json.load(open(old))
except Exception:
    prev = {}
out = {
    "FINGERPRINT": f"google/{product}/{device}:CANARY/{bid}/{inc}:user/release-keys",
    "MANUFACTURER": "Google",
    "MODEL": model,
    "SECURITY_PATCH": patch,
    "DEVICE_INITIAL_SDK_INT": first_api,
    "spoofVendingBuild": prev.get("spoofVendingBuild", True),
}
if "nativeProps" in prev:
    out["nativeProps"] = prev["nativeProps"]
print(json.dumps(out, indent=2))
PY
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["FINGERPRINT"].count("/")==5 and d["SECURITY_PATCH"]' "$T/pif.json" \
    || { echo "generated identity looks wrong:"; cat "$T/pif.json"; exit 1; }
  if [ -f "$JSON" ] && cmp -s <(tr -d '\r' < "$JSON") "$T/pif.json"; then
    CHANGED=0; echo "pif.json is current: $(grep FINGERPRINT "$JSON")"
  else
    cp "$T/pif.json" "$JSON"; CHANGED=1; echo "pif.json updated:"; cat "$JSON"
  fi
fi

# --- TWRP zip: replaces /system/etc/pif.json, nothing else
ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["FINGERPRINT"].split("/")[3].split(":")[0])' "$JSON")
mkdir -p "$T/z/META-INF/com/google/android"
tr -d '\r' < "$JSON" > "$T/z/pif.json"
tr -d '\r' < "$REPO/pif/update-binary" > "$T/z/META-INF/com/google/android/update-binary"
echo "# dummy - the work is done by update-binary" > "$T/z/META-INF/com/google/android/updater-script"
mkdir -p "$REPO/artifacts"; Z=$REPO/artifacts/pif-update-$ID.zip; rm -f "$Z"
(cd "$T/z" && zip -qr -X "$Z" .)
echo "wrote $Z"
[ "${CHANGED:-1}" = 1 ] || exit 3
