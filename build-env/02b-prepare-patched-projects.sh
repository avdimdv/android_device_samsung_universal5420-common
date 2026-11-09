#!/bin/bash
# HazouPH's apply_patch.sh skips a patch when its Change-Id is already in `git log`.
# With a --depth=1 sync that history is missing, so already-merged fixes get re-applied
# and fail. This resets every patched project to its manifest revision and deepens history.
# Run in WSL after 02-sync.sh:  bash 02b-prepare-patched-projects.sh
set -e
TOP=${TOP:-$HOME/lineage}
cd "$TOP"
PD=device/samsung/universal5420-common-patches
projs=$(cd $PD && find . -name '*.patch' | sed -r 's|/[^/]+$||; s|^\./||' | sort -u)
for p in $projs; do
  [ -d "$p" ] || { echo "skip $p (not in tree)"; continue; }
  git -C "$p" am --abort >/dev/null 2>&1 || true
  rm -f "$PD/$p/.lastcommit"
done
repo sync -l -d --force-sync $projs </dev/null
for p in $projs; do
  [ -d "$p" ] || continue
  remote=$(git -C "$p" remote | head -1)
  echo "deepen $p"
  git -C "$p" fetch -q --deepen=3000 "$remote" || echo "WARN: deepen failed for $p"
done
# Patches already upstream in lineage-17.1 under a different Change-Id -> skip (*.bk is ignored)
#  041: same NPE fixed by 3eb409bcc54f "Avoid NullPointer access when using the default icon"
for f in frameworks/base/041-Fix-null-ptr-in-customtile.patch; do
  [ -f "$PD/$f" ] && mv "$PD/$f" "$PD/$f.bk"
done
rm -f "$TOP/.patches-applied" "$PD/Android.mk"
