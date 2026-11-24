# Magisk modules for the Tab S 10.5 (SM-T800)

Sources for the modules built by `build-env/05-make-magisk-modules.sh` into `artifacts\<id>.zip`.

- `template/` – installer (`META-INF`) and `customize.sh` that gives every replaced file the SELinux
  label of the original.
- `modules/<id>/` – `module.prop`, `files` (module path ← file in the WSL build tree),
  optional `customize.sh` (appended to the template's) and any other file copied as is.

## `chagall_fixes` – everything we changed, in one module

| Fix | Module content | Source of truth |
|---|---|---|
| BT call audio: libbt as I2S slave + SCO config sent | `system/vendor/lib/libbt-vendor.so` | `BoardConfigCommon.mk`, `bluetooth/libbt_vndcfg.txt` (built) |
| Mic gain +15 dB, out-of-range values, BT SCO mic keeps AIF2 Master (FLL2) | `system/vendor/etc/mixer_paths_0.xml` | `patches/device/samsung/chagall-common/` 0001, 0002 |
| Speaker hardware EQ + limiter + loudness (WM5102: AIF1 → EQ1/2 (E1: −9/−3/0/+1/0 dB) → DRC1 (T1: +6 dB, ceiling −9 dBFS) → SPKOUT) – **only with our kernel** | same file, lines tagged `<!-- drc-speaker -->`; `post-fs-data.sh` strips them if `/sys/class/misc/wolfson_control` exists | chagall-common 0003, 0004 + `patches/kernel/samsung/exynos5420/0001` |
| VoIP to speaker (no earpiece) | `system/vendor/etc/audio_policy_configuration.xml` | `configs/audio/audio_policy_configuration.xml` |
| Working AEC/NS for VoIP (AOSP instead of broken LifeVibes) | `system/vendor/etc/audio_effects.xml` + `post-fs-data.sh` | `configs/audio/audio_effects.xml` |
| Fingerprint unlock (v6-v8): the Validity HAL leaked its 128 KB secure ion buffer every session, reported every enrolment as failed-but-saved, sent garbage in "removed" (Settings never refreshed); v7 also fixes a hang after the 60 s enrolment timeout (system_server watchdog restart loop - **do not use v6**) and a crash when a new request arrived while the previous session was still closing; v8: when the framework starts a new request without cancelling the running one, the HAL stops the old one instead of answering "Sensor is busy" (seen as an instant enrolment "timeout" after "Add fingerprint") | `system/lib/hw/fingerprint.universal5420.so` | `patches/device/samsung/chagall-common/` 0005, 0006 (built) |
| Enrolment pages say "swipe the home button" instead of "touch the sensor on the back" (v6) | `system/product/overlay/FingerprintSwipeSettings.apk` | `magisk/overlays/FingerprintSwipeSettings/`, built by `build-env/05a-build-overlays.sh` |
| AudioFX: not touched (v5). v2-v4 hid it; the owner prefers it for headphones. It enables Equalizer + Bass Boost + Virtualizer per output by default - switch its **speaker** profile off, the hardware chain is tuned without it | - | - |

`post-fs-data.sh` adds the JamesDSP library/effect to `audio_effects.xml` when the
`ainur_jamesdsp` module is active, and writes the same content into JamesDSP's own copy of that
file (it generates one from the stock config at install time) – so the two modules never disagree
and nothing has to be edited by hand after (re)installing JamesDSP.

**Fingerprint after upgrading to v6**: enrolments made with the old HAL can leave a "ghost" template
in `/data/validity/finger.db` that Settings does not list (so it cannot be deleted there) and that
spoils matching. If unlock keeps failing: delete all fingerprints in Settings, then as root
`stop vendor.fps_hal; mv /data/validity/finger.db /data/validity/finger.db.old; start vendor.fps_hal`,
and enrol again. It is a **swipe** sensor (home button): slow, straight swipes; a few rejected
swipes before a match are normal (the matcher answers 601 for "not similar enough").

**Enrol the same finger in all 3 slots** (Settings allows 3). A swipe sees only a strip of the
finger, and every swipe is matched against all stored prints: with one enrolment about 1 swipe in
6 unlocked, with the same finger enrolled 3 times nearly every swipe did (2026-11-24; the
successful unlocks matched slots 1, 2 and 3 alike). Loosening the matcher threshold from 1:100000
to 1:50000 did not help (1 of 21) and was not adopted.

Installing `chagall_fixes` marks the old single-purpose modules (`chagall_bt_sco_fix`,
`chagall_mic_fix`, `chagall_voip_speaker`, `chagall_bt_sco_slave`) for removal.

Installation is refused on anything but chagallwifi / Android 10 (`customize.sh`).

## Package for other users – `artifacts\release\`

`build-env/07-make-release.sh` (in WSL, after 03-overlay) builds what can be handed out:

- `chagall_fixes.zip` – the module above.
- `chagall_kernel_nohook.zip` – `magisk/kernel-zip/` + our kernel. The Magisk app installs every zip
  as a module (it never runs the zip's update-binary), so the zip is a tiny marker module whose
  `customize.sh` calls `kernel/swap.sh`; in TWRP `update-binary` calls the same script. Swaps only the kernel inside the boot image on the tablet (ramdisk/Magisk kept), after
  checking device and current kernel md5; backs the boot image up to `/sdcard/chagall_kernel/`,
  verifies by read-back. `sh kernel/swap.sh --repack in.img zImage out.img` is the PC self test
  (output is byte-identical to `build-env/boot-repack.py`).
- `chagall_kernel_stock.zip` – same installer with the ROM's kernel (undo).
- `README.md` (from `magisk/release/`), `source/` (patches with e-mail addresses removed), `SHA256SUMS`.

## After a firmware reinstall – checklist

1. Flash ROM (LineageOS 17.1 "deathly" for chagallwifi), Magisk (25.2), reboot.
1b. **Our kernel** (Wolfson Control hook removed – needed for the speaker DRC; everything else works
   without it, the module then just skips DRC). The kernel lives in the boot image, not in the
   module. Easiest: Magisk app → Install from storage → `artifacts\release\chagall_kernel_nohook.zip`.
   By hand: pull the new Magisk-patched boot image, swap in our kernel, flash it back:
   ```
   cd /d D:\SOURCES\android_device_samsung_universal5420-common
   adb shell "su -c 'dd if=/dev/block/platform/dw_mmc.0/by-name/BOOT of=/sdcard/boot-magisk.img'"
   adb pull /sdcard/boot-magisk.img artifacts\
   wsl -d Ubuntu -- python3 build-env/boot-repack.py artifacts/boot-magisk.img artifacts/kernel-nohook/zImage artifacts/boot-nohook-new.img
   adb push artifacts\boot-nohook-new.img /sdcard/
   adb shell "su -c 'dd if=/sdcard/boot-nohook-new.img of=/dev/block/platform/dw_mmc.0/by-name/BOOT'"
   ```
   then reboot; `adb shell uname -v` must show the `Wed Nov 11 00:23:52 CET 2026` build (or newer).
   (Or ask Claude: the same steps with checksum verification were used on 2026-11-11.)
2. Magisk modules (Install from storage), then reboot once at the end:
   - `chagall_fixes` (this repo, `artifacts\chagall_fixes.zip`)
   - `ainur_jamesdsp` (Magisk-Modules-Repo) – installer needs
     `audio-session-2026-11/magisk/ainur_jamesdsp_common_install.sh.patch` (volume keys are not
     detected; patch hard-selects the Original UI)
   - MagiskHidePropsConf, playintegrityfix (third party, as before)
3. App settings (live in app data, no module can set them):
   - JamesDSP: since the hardware DRC (2026-11-11) JamesDSP is **switched off** and not needed for
     speaker protection. If you want it back (e.g. for its EQ): ⋮ → **Reg: Global**; then restore
     the saved preset (limiter −9 dB, EQ, compander):
     ```
     cd /d D:\SOURCES\android_device_samsung_universal5420-common
     adb push "audio-session-2026-11\jamesdsp-preset\Tab S 10.5" "/sdcard/JamesDSP/Presets/"
     ```
     and load "Tab S 10.5" in the app's preset menu. (Exported 2026-11-10, identical to the live
     settings at that time; values also in `audio-session-2026-11/NOTES.md`.)
   - SmartTube: Player → Misc → **Auto volume adjustment OFF**.
   - Deathly Adiutor: speaker boost **0 dB** (or uninstall).
4. Check (Windows cmd, from the repo folder):
   `adb shell "su -c 'ls /data/adb/modules; md5sum /vendor/lib/libbt-vendor.so /vendor/etc/*.xml'"`
