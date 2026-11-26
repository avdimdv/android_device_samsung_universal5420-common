# Build chain – LineageOS 17.1 "deathly" for chagallwifi (SM-T800)

Reproduces the unofficial ROM from XDA thread 4270943 (maintainer HazouPH) on this
Windows PC, using WSL2 Ubuntu 20.04 (the officially supported host for 17.1).

## Sources

| What | Where |
|---|---|
| Base | `LineageOS/android` branch `lineage-17.1` (shallow, `--depth=1`) |
| Device/kernel/vendor list | `HazouPH/local_manifests` branch `lineage-17.1-exynos5420`, file `roomservice.xml` |
| This repo | `HazouPH/android_device_samsung_universal5420-common` branch `lineage-17.1-deathly` |
| Kernel | `HazouPH/android_kernel_samsung_exynos5420` branch `lineage-17.1-deathly` (defconfig `lineageos_chagallwifi_defconfig`) |
| Extra patches | `HazouPH/android_device_samsung_universal5420-common-patches` (security backports, applied by `apply_patch.sh`) |

## Steps (Windows, from this folder)

```
wsl -d Ubuntu -u root -- bash 01-setup-host.sh      # once: packages + repo
wsl -d Ubuntu -- bash 02-sync.sh                    # ~70 GB into ~/lineage (ext4 inside WSL)
wsl -d Ubuntu -- bash 03-overlay-local-tree.sh      # this repo (incl. uncommitted edits) + patches/ into the tree
wsl -d Ubuntu -- bash 04-build.sh                   # libbt-vendor + audio HAL only
wsl -d Ubuntu -- bash 04-build.sh bacon             # full flashable zip
wsl -d Ubuntu -- bash 05-make-magisk-modules.sh     # artifacts\<module-id>.zip for testing without reflashing
wsl -d Ubuntu -- bash 05b-make-key-migration.sh     # artifacts\key-migration-hazouph-to-aosp.zip
INSTALLCLEAN=1 bash 04-build.sh bacon, then 07b-make-rom-release.sh   # ROM release in artifacts\rom-release\
```

## Changes to other repos: `patches/`

`patches/<project path>/*.patch` (git format-patch) are applied by `03-overlay` to that project of
the build tree, after resetting it to its manifest revision (or to `BASE` if that file exists):

| Project | What |
|---|---|
| `device/samsung/chagall-common` | audio (mic gain, BT SCO, speaker EQ/limiter), fingerprint HAL fixes, 5 slots, "swipe" wording |
| `kernel/samsung/exynos5420` | Wolfson Control regmap hook removed (needed for the speaker EQ/limiter) |
| `vendor/lineage` | `EXCLUDE_AUDIOFX` guard (AudioFX removed) |
| `frameworks/av` | camcorder: NV21 encoder input, Codec2 gralloc guards, swcodec APEX `/system/lib` fallback |
| `frameworks/base` | Play Integrity Basic without root (GmsIntegritySpoof) |
| `hardware/samsung_slsi/exynos` | libcsc null-plane guard (+ an exynos5430-only codec flag, no effect here) |
| `packages/apps/Snap` | camera icon not hidden after a fresh flash; no forced software video stabilisation |

The last four come from the Galaxy Alpha port (same chipset family, same tree) and are copied here
unchanged. `frameworks/av` additionally gets 3 of HazouPH's camera patches at `envsetup` time
(`device/samsung/universal5420-common-patches`, applied by its `vendorsetup.sh`); the result was
checked to be identical to the tree the release ROM was built from.
To change one: edit in `~/lineage/device/samsung/chagall-common`, commit, then
`git format-patch --zero-commit -o <repo>/patches/device/samsung/chagall-common m/lineage-17.1`.

## Magisk modules: `magisk/`

`magisk/template/` = installer (`META-INF`) + `customize.sh` that copies each replaced file's
SELinux label. `magisk/modules/<id>/` = `module.prop` + `files` (module path → source in the build
tree). `05-make-magisk-modules.sh [id ...]` zips them into `artifacts\<id>.zip`.

Output: `~/lineage/out/target/product/chagallwifi/` (WSL path
`\\wsl$\Ubuntu\home\<user>\lineage\out\target\product\chagallwifi`).
Single modules land in `.../vendor/lib/` (e.g. `libbt-vendor.so`) and can be tested via a
Magisk module without reflashing.

## Where things live and how files move

```
D:\SOURCES\android_device_samsung_universal5420-common   (this repo, Windows, you edit here)
   │  03-overlay: git diff of tracked files (CRLF→LF) applied on top of the same commit
   ▼
WSL2 "Ubuntu" 20.04  ~/lineage                           (Linux ext4 disk =
   │  .repo (31 GB git data) + checked-out sources          %LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu_*\LocalState\ext4.vhdx)
   │  04-build: Soong/Make + clang, ccache in ~/.ccache
   ▼
~/lineage/out/... (libs), ~/lineage/device/... (configs, incl. patched chagall-common)
   │  05-make-magisk-modules: zip + write over /mnt/d (WSL's view of D:\)
   ▼
D:\...\artifacts\<module-id>.zip   → adb push to /sdcard/Download → Magisk
```

- WSL sees Windows drives as `/mnt/c`, `/mnt/d`; Windows sees the Linux disk as `\\wsl$\Ubuntu\home\<user>`.
- The overlay only carries **tracked** files that changed. A brand-new file must be `git add`-ed
  (staging is enough) or it will not reach the build tree.
- Nothing is uploaded anywhere; the only network traffic is `repo sync` / `git fetch` from GitHub.

## Notes

- Keep the tree on the WSL ext4 disk, never on `/mnt/c` or `/mnt/d` (10x slower, case issues).
- WSL default RAM is half the host (15 GB). If a full build gets OOM-killed (metalava/doclava),
  set `memory=24GB` and `swap=32GB` in `%USERPROFILE%\.wslconfig`, then `wsl --shutdown`.
- Disk: the WSL disk lives on C: (≈220 GB free at setup). Source ≈ 70 GB, out ≈ 80 GB, ccache 40 GB max.
