#!/bin/bash
# Run as normal user in WSL:  bash 02-sync.sh   (tree goes to ~/lineage, ext4 inside WSL)
set -e
TOP=${TOP:-$HOME/lineage}
mkdir -p "$TOP/.repo/local_manifests" && cd "$TOP"
[ -d .repo/manifests ] || repo init -u https://github.com/LineageOS/android.git -b lineage-17.1 --depth=1 --no-clone-bundle </dev/null
# Exact source list used by the unofficial "deathly" ROM (HazouPH, XDA thread 4270943)
curl -sf -o .repo/local_manifests/roomservice.xml \
  https://raw.githubusercontent.com/HazouPH/local_manifests/lineage-17.1-exynos5420/roomservice.xml
rm -f .repo/local_manifests/*$'\r'
repo sync -c -j8 --no-tags --no-clone-bundle --optimized-fetch --prune --force-sync --fail-fast </dev/null
