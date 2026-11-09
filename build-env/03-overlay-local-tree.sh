#!/bin/bash
# Bring the uncommitted edits of the Windows working copy (D:\SOURCES\...universal5420-common)
# into the WSL build tree as a clean, LF-only patch. core.autocrlf=true is forced because the
# Windows checkout has CRLF files and WSL git does not read the Windows git config.
# Run in WSL:  bash 03-overlay-local-tree.sh
set -e
TOP=${TOP:-$HOME/lineage}
SRC=/mnt/d/SOURCES/android_device_samsung_universal5420-common
DST=$TOP/device/samsung/universal5420-common
WIN_HEAD=$(git -C "$SRC" rev-parse HEAD)
git -C "$DST" checkout -q -- . && git -C "$DST" clean -qfd
git -C "$DST" cat-file -e "$WIN_HEAD" 2>/dev/null || git -C "$DST" fetch -q "$SRC" "$WIN_HEAD"
git -C "$DST" checkout -q "$WIN_HEAD"
PATCH=$(mktemp)
git -c core.autocrlf=true -C "$SRC" diff HEAD -- . ':!audio-session-2026-11' ':!build-env' ':!artifacts' ':!CLAUDE.md' > "$PATCH" 2>/dev/null
if [ -s "$PATCH" ]; then git -C "$DST" apply --whitespace=nowarn "$PATCH"; else echo "no uncommitted edits"; fi
rm -f "$PATCH"
echo "build tree at $(git -C "$DST" log --oneline -1)"
git -C "$DST" status --short

# patches/<project path>/*.patch: changes to other repos of the tree (e.g. chagall-common ships
# mixer_paths_0.xml). Each project is reset to its manifest revision and the patches re-applied.
cd "$SRC/patches"
for PROJ in $(find . -name '*.patch' -printf '%h\n' | sed 's#^\./##' | sort -u); do
  P=$TOP/$PROJ
  BASE=$(git -C "$P" for-each-ref --format='%(refname)' refs/remotes/m | head -1)
  [ -n "$BASE" ] || { echo "$PROJ: no manifest ref"; exit 1; }
  git -C "$P" am --abort 2>/dev/null || true
  git -C "$P" checkout -q -- . && git -C "$P" checkout -q --detach "$BASE"
  git -C "$P" -c user.name=build-env -c user.email=build-env@localhost am -q "$SRC/patches/$PROJ"/*.patch
  echo "$PROJ: $(git -C "$P" log --oneline "$BASE"..HEAD | wc -l) patch(es) on $(git -C "$P" rev-parse --short "$BASE")"
done
