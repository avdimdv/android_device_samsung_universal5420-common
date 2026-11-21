#!/bin/bash
# Run in WSL:  bash 04-build.sh [target...]
#   no args       -> libbt-vendor + audio HAL only (minutes, for Magisk testing)
#   bacon         -> full flashable ROM zip (hours)
set -e
TOP=${TOP:-$HOME/lineage}
cd "$TOP"
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR=$HOME/.ccache
ccache -M 40G >/dev/null
export LC_ALL=C
source build/envsetup.sh
# HazouPH security/compat patches (idempotent: skips patches already applied)
if [ ! -f .patches-applied ]; then
  bash device/samsung/universal5420-common-patches/apply_patch.sh || exit 1
  [ -f device/samsung/universal5420-common-patches/Android.mk ] && { echo "PATCHES FAILED"; exit 1; }
  touch .patches-applied
fi
breakfast chagallwifi ${VARIANT:-userdebug}  # BoardConfig uses SELINUX_IGNORE_NEVERALLOWS -> userdebug only (tablet's "user" is spoofed by Magisk props)
if [ $# -eq 0 ]; then set -- libbt-vendor audio.primary.universal5420; fi

# Metalava (the api-stubs/hiddenapi generators) runs as plain `java -jar metalava.jar` with NO
# -Xmx, so the JVM sizes its heap ergonomically from *currently free* memory. Under a busy build
# that collapsed to 242 MB..2 GB and the Tab S bacon died with java.lang.OutOfMemoryError at
# //frameworks/base:api-stubs-docs (2026-11-21 04:18). Give it a real heap. JDK_JAVA_OPTIONS
# (JDK 9+) is overridden by an explicit command-line -Xmx, so d8/r8/javac keep their own tuned
# sizes; 3072m is the value the Alpha full build has been using successfully.
export JDK_JAVA_OPTIONS="${JDK_JAVA_OPTIONS:--Xmx3072m}"

# These generators are single-threaded and memory-hungry: run them alone first so they never
# compete with the parallel part of the build (same order as the Alpha's full-build-low-memory.sh).
if [ "$1" = bacon ]; then
  for t in system-api-stubs-docs api-stubs-docs test-api-stubs-docs hiddenapi-lists-docs; do
    echo "== heavy step $t (-j1) $(date)"
    m -j1 "$t" || echo "== $t not available here, continuing"
  done
fi
# -j2, not -j$(nproc): builds must not saturate the machine (decided 2026-11-21 - build speed is
# explicitly less important than keeping ordinary work responsive). Pair with processors=2 in
# .wslconfig; more jobs than cores only adds queueing. Override with JOBS=... if you ever want
# a fast build while doing nothing else.
m -j"${JOBS:-2}" "$@" || { echo "BUILD FAILED"; exit 1; }
