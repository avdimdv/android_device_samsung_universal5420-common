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
| Mic gain +15 dB, out-of-range values, BT SCO mic keeps AIF2 Master (FLL2) | `system/vendor/etc/mixer_paths_0.xml` | `patches/device/samsung/chagall-common/` |
| VoIP to speaker (no earpiece) | `system/vendor/etc/audio_policy_configuration.xml` | `configs/audio/audio_policy_configuration.xml` |
| Working AEC/NS for VoIP (AOSP instead of broken LifeVibes) | `system/vendor/etc/audio_effects.xml` + `post-fs-data.sh` | `configs/audio/audio_effects.xml` |
| AudioFX off (it suspends global effects like JamesDSP) | `system/priv-app/AudioFX/.replace` | – |

`post-fs-data.sh` adds the JamesDSP library/effect to `audio_effects.xml` when the
`ainur_jamesdsp` module is active, and writes the same content into JamesDSP's own copy of that
file (it generates one from the stock config at install time) – so the two modules never disagree
and nothing has to be edited by hand after (re)installing JamesDSP.

Installing `chagall_fixes` marks the old single-purpose modules (`chagall_bt_sco_fix`,
`chagall_mic_fix`, `chagall_voip_speaker`, `chagall_bt_sco_slave`) for removal.

## After a firmware reinstall – checklist

1. Flash ROM (LineageOS 17.1 "deathly" for chagallwifi), Magisk (25.2), reboot.
2. Magisk modules (Install from storage), then reboot once at the end:
   - `chagall_fixes` (this repo, `artifacts\chagall_fixes.zip`)
   - `ainur_jamesdsp` (Magisk-Modules-Repo) – installer needs
     `audio-session-2026-11/magisk/ainur_jamesdsp_common_install.sh.patch` (volume keys are not
     detected; patch hard-selects the Original UI)
   - MagiskHidePropsConf, playintegrityfix (third party, as before)
3. App settings (live in app data, no module can set them):
   - JamesDSP: ⋮ → **Reg: Global**; then restore the saved preset (limiter −9 dB, EQ, compander):
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
