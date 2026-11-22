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

# Build identity: never let the machine's account name into a shipped artifact.
# build/soong/ui/build/kati.go:99-112 sets BUILD_USERNAME from the OS user and
# BUILD_HOSTNAME from the hostname *only when they are not already in the environment*, so
# exporting them here fixes every downstream place at once:
#   ro.build.user / ro.build.host                      (buildinfo.sh)
#   BUILD_NUMBER = eng.$(BUILD_USERNAME:0:6).<stamp>   version_defaults.mk:315
#     -> ro.build.version.incremental, ro.system.build.version.incremental,
#        ro.build.display.id, and META-INF/com/android/metadata post-build-incremental
#   FILE_NAME_TAG = eng.$(BUILD_USERNAME)              main.mk:83
#     -> target_files/ota intermediate names
# Without this, a build from this machine embeds the OS account name and the PC's hostname in the
# public zip. Use DEV_IDENTITY=1 to keep the real values for a private debugging build.
if [ "${DEV_IDENTITY:-0}" != "1" ]; then
  export BUILD_USERNAME="${BUILD_USERNAME:-lineage}"
  export BUILD_HOSTNAME="${BUILD_HOSTNAME:-localhost}"
fi
# Fresh BUILD_NUMBER/date for every run: main.mk:67 writes out/build_number.txt on every kati run,
# but build.prop recipes only `cat` it at recipe RUN time and no rule DEPENDS on it - deleting the
# stamp alone changes nothing (proven 2026-11-22: byte-identical zip). So delete the staging
# build.prop files too; their recipes then re-run and read the new stamp.
rm -f out/build_number.txt out/build_date.txt out/soong/dates_property
O2=out/target/product/chagallwifi
rm -f $O2/system/build.prop $O2/system/product/build.prop $O2/system/vendor/build.prop \
      $O2/system/vendor/odm/etc/build.prop $O2/vendor/build.prop $O2/odm/build.prop \
      $O2/product/build.prop 2>/dev/null

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
#
# GOTCHA: a module removed from PRODUCT_PACKAGES is NOT deleted from out/target/product/<dev>/ by
# an incremental build, and the image is packed from that directory - so the old file keeps
# shipping. The AudioFX removal hit exactly this (2026-11-21): the config was right, get_build_var
# showed 895 packages without AudioFX, and system/priv-app/AudioFX/AudioFX.apk was still in the
# image. After ANY PRODUCT_PACKAGES change run  m installclean  before bacon.
# INSTALLCLEAN=1 wipes the staging dir first - see the gotcha above; also needed after any
# build-identity change, because e.g. odm/etc/build.prop has no build_number.txt dependency and
# would otherwise keep a stale incremental from an older build.
if [ "${INSTALLCLEAN:-0}" = "1" ] && [ "$1" = bacon ]; then
  echo "== installclean $(date)"
  m installclean
fi
if [ "$1" = bacon ]; then
  for t in system-api-stubs-docs api-stubs-docs test-api-stubs-docs hiddenapi-lists-docs; do
    echo "== heavy step $t (-j1) $(date)"
    m -j1 "$t" || echo "== $t not available here, continuing"
  done
fi
# -j comes from the MEMORY, not from nproc (policy revised 2026-11-21 evening: keep RAM under
# control, let the CPU run full). jobs = (MemTotal_MB - 1400 - 2048) / 250, capped at nproc.
# The constants are measured on this tree: ninja itself holds ~1.4 GB, the soong/kati JVMs ~2 GB
# resident, a C++ job peaks around 250 MB. On the 6 GB VM that is ~9-10 jobs even with 16 cores;
# going higher makes the build swap, which is slower than fewer jobs - a swap storm is what
# OOM-killed Metalava on 2026-11-21. Override with JOBS=... if you want more.
_mem_mb=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))
_jobs=$(( (_mem_mb - 1400 - 2048) / 250 ))
[ "$_jobs" -gt "$(nproc)" ] && _jobs=$(nproc)
[ "$_jobs" -lt 1 ] && _jobs=1
echo "RAM ${_mem_mb} MB | cores $(nproc) | -j${JOBS:-$_jobs}"
m -j"${JOBS:-$_jobs}" "$@" || { echo "BUILD FAILED"; exit 1; }
