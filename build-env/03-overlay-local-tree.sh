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
git -c core.autocrlf=true -C "$SRC" diff HEAD -- . ':!audio-session-2026-11' ':!build-env' ':!CLAUDE.md' | git -C "$DST" apply --whitespace=nowarn
git -C "$DST" status --short
