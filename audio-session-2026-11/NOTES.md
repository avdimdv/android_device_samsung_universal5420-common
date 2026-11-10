# Galaxy Tab S 10.5 (chagallwifi) – audio session handoff (2026-11-08/09)

Work done interactively with Claude (Cowork), continued in Claude Code. This folder holds the
findings; paths below are relative to this folder.

## Status 2026-11-10 (end of Claude Code session)

| Area | State |
|---|---|
| Build chain | WSL `~/lineage`, reproduces the shipped libbt byte-identically (`../build-env/`) |
| Mic gain | fixed (patch 0001 for chagall-common) |
| BT HFP/SCO calls | **fixed, audio both ways** (libbt config + patch 0002 AIF2/FLL2); volume tuning parked |
| VoIP without BT | fixed: goes to speaker (no earpiece in audio policy) |
| VoIP echo on speaker | gross bug fixed (working AEC config); residual echo = Telegram's AECM + JamesDSP |
| Delivery | one Magisk module **`chagall_fixes`** (`../magisk/`, checklist in `../magisk/README.md`) |
| Repo | local branch `audio-bt-call-fixes` (never push); Galaxy Alpha plan in worktree `D:\SOURCES\galaxy-alpha` |

## Device / environment

| Item | Value |
|---|---|
| Device | Samsung Galaxy Tab S 10.5 Wi-Fi, SM-T800, codename `chagallwifi` |
| ROM | Unofficial LineageOS 17.1 (Android 10, API 29), XDA thread 4270943 – maintainer has stopped |
| Kernel | 3.4 (Samsung exynos5420), 32-bit ARM (armeabi-v7a), SELinux Enforcing |
| Root | Magisk 25.2. `adb root` is disabled → use `adb shell "su -c '...'"` (shell granted in Magisk) |
| Audio codec | Wolfson/Cirrus **WM5102** (Arizona; earlier notes said WM5110 – wrong, see "Why DRC/EQ…"); ALSA DAIs `wm5102-aif1/2/3` |
| ALSA PCMs | `00-00 Pri_Dai aif1`, `00-01 Voice aif2`, `00-02 BT Tx/Rx aif3`, `00-03 Sec_Dai aif1` |
| Audio HAL | `audio.primary.universal5420` (`TARGET_AUDIOHAL_VARIANT := samsung`), mixer file `/vendor/etc/mixer_paths_0.xml` (`/vendor` → `/system/vendor`) |
| BT chip | Broadcom BCM4350 on `/dev/ttySAC0`, `libbt-vendor.so` built with `SCO_USE_I2S_INTERFACE` |
| Tools on device | `tinymix` yes; `tinycap`/`tinyplay` **no** |
| Host | Windows PC, `adb` from `C:\Program Files (x86)\Android\android-sdk\platform-tools` |

## DANGER – things that hard-crash / hang this kernel

1. **Routing WM5110 DRC1 (hardware compressor) and then un-routing it while a stream is
   active** (`SPKOUTx Input 1 = DRC1x`, then back) froze playback; leaving DRC routed made
   the next **reboot hang** (needed Power+VolDown force restart). Do not use DRC1/DRC2.
2. **Reading `/proc/asound/card0/pcm0p/sub0/status` during playback** → hard lockup /
   watchdog panic (proven: `logs/lastcrash.txt`, process `head`).
3. **Reading debugfs `/sys/kernel/debug/asoc/.../dapm/*`** → reboot (very likely, same session).
   Listing `/proc/<pid>/fd` for `/dev/snd/pcm*` is safe.
4. **Wolfson Control speaker EQ** (`echo 1 > /sys/class/misc/wolfson_control/switch_eq_speaker`,
   SPKOUT ← EQ3/EQ4) → speaker playback **stalls** (`out_write: I/O error`, "write blocked for
   20–40 s"), no kernel crash. `echo 0` while idle restores the routing but the codec **stays
   stuck until a reboot** (2026-11-10). "Mixer dropped sample"/"ASRC underclocked" in dmesg are
   normal background noise on this codec, also during healthy playback.

### Why DRC/EQ on the speaker fails (2026-11-10 findings)
- The codec is a **WM5102** (kernel builds only `CONFIG_MFD_WM5102`/`SND_SOC_WM5102`; probe rejects
  other IDs), not WM5110 as written above.
- `arizona-control.c` = AndreiLux "Wolfson Control" (`/sys/class/misc/wolfson_control/`) hooks every
  codec register write (`arizona_control_regmap_hook` in regmap.c). "Hidden"/"active" fields are
  locked to the first value written at boot: **`SPKOUTx Input 1` (OUT4 mix input 1) is locked to
  AIF1RX1/2** – mixer/tinymix writes return OK but are replaced, while DAPM believes them. So the
  earlier "route SPKOUT to DRC1" never reached the chip; DAPM powered a DRC path that did not exist.
- EQ/DRC/LHPF run at `FX_RATE` (reg 0xE00), which **nothing in this kernel ever sets** (no control,
  no code) – prime suspect for the stalls when EQ3/EQ4 or DRC1 feed the speaker.
- Next step needs our own kernel build: expose "FX Rate" (as upstream), make the SPKOUT input
  pass-through in arizona-control (or drop the hook), then route DRC1 in mixer_paths so DAPM
  sequences it. Script for live tests: `scripts/drc_test.sh` (refuses changes unless idle).

## WM5110 control ranges (verified with tinymix on device)

- `INxx Volume` (analog mic PGA): 0..31 = 0..+31 dB
- `INxx Digital Volume`, `* Digital Volume` (outputs): 0..191, 128 = 0 dB, 0.5 dB/step
- Mixer inputs `XXX Input N Volume`: 0..48, 32 = 0 dB, 1 dB/step (max +16 dB)
- No analog speaker gain control exists. `Speaker High Performance Switch` = Off (untested).
- `DRC1` bytes control + `DRC1_MINGAIN/MAXGAIN/NG_MINGAIN` enums exist (see danger above).

## Findings

### Speaker (too quiet, distorts when boosted)
- Stock `speaker` path: `SPKOUTL/R Input 1 Volume = 42` (+10 dB) and
  `Speaker Digital Volume = 125` (−1.5 dB) → **+8.5 dB digital gain before the class-D amp**,
  so anything above ≈ −8.5 dBFS clips. Boost apps (Deathly Adiutor) add more clipping.
- Original file also had **out-of-range values silently rejected by the kernel**:
  `voice-speaker` 70 (max 48), `voice-rec-mic` IN1L 42 (max 31), `voice-rec-headset-mic` IN1R 39.
- Hardware fix (DRC) is unusable (see danger). Solution taken: **software limiter/compressor
  via JamesDSP** before the +8.5 dB, limiter threshold −9 dB.

### Mic (barely audible) – FIXED
- `main-mic`: IN1L 24 → **30**, IN1L Digital 128 → **146** (+15 dB total); call paths +4 dB;
  invalid values clamped to 31. Speaker values left stock. Now in
  `../patches/device/samsung/chagall-common/0001-*.patch` (the ROM takes mixer_paths from chagall-common).
- Delivered in Magisk module `chagall_fixes` (`../magisk/modules/`, built by `../build-env/05-make-magisk-modules.sh`). Confirmed working.

### VoIP calls (Telegram) play nothing until "Speaker" is pressed
- Cause: `configs/audio/audio_policy_configuration.xml` in this device tree lists
  **`Earpiece` in `<attachedDevices>`**; the Wi-Fi tablet has no earpiece, so Telecom routes
  communication audio to EARPIECE (seen in logcat: `route: EARPIECE`).
- **Fix (verified 2026-11-09, committed):** Earpiece removed from attachedDevices, devicePorts and routes
  in `configs/audio/audio_policy_configuration.xml`. Engine falls back to
  `defaultOutputDevice` (Speaker); Telecom only offers EARPIECE if `TYPE_BUILTIN_EARPIECE` exists.
  In module `chagall_fixes`. Telegram call without BT went to `speaker` at once. Note: file is shared by all universal5420 devices.

### BT call gain (PARKED 2026-11-10 – redo with two people)
- Uplink (Jabra mic → far end): `AIF1TX1/2 Input 2 Volume` (AIF3RX→ASRC2→AIF1TX), default 32 = 0 dB,
  max 48 = +16 dB. Downlink (far end → earbuds): `AIF3TX1/2 Input 1 Volume`, same range.
  Neither is set by any mixer path (init value only), so `tinymix` changes during a call stick.
- Sweep script `scripts/bt_gain_sweep.sh` (+ `scripts/bt_gain_sweep_restart.sh`): push both to
  `/data/local/tmp/` (sweep as `gainstep.sh`), run the restart script as root; it waits for
  `ASRC2L Input = AIF3RX1`, then 30 s steps 0/6/10/14/16 dB uplink, then downlink, logs times to
  `/data/local/tmp/gainstep.log`. One run done 01:11–01:16 (BT SCO stream volume at max 15/15),
  no verdict yet. Test setup: tablet+Jabra in one room, second phone with a second person.
- When values are known: add them to `bt-sco-hs-mic` / `bt-sco-headset` as patch 0003 in
  `patches/device/samsung/chagall-common/`, bump `chagall_fixes` to v2.
- BT recording outside calls (e.g. ASR app) cannot work: HAL starts the SCO PCMs only in
  MODE_IN_COMMUNICATION/IN_CALL (`hardware/samsung/audio/audio_hw.c`), capture times out.

### Speakerphone VoIP echo (far end hears itself)
- Cause (fixed 2026-11-10, `configs/audio/audio_effects.xml`): pre_processing pointed to NXP LifeVibes
  `liblvvetx.so`; it always fails (`LVVEFS_Create` error 8, capture is 48 kHz). Telegram/WebRTC
  saw a platform AEC, disabled its own, and the platform one never ran → no AEC at all.
  Now AOSP `libaudiopreprocessing.so` (AEC + NS for voice_communication only, as AOSP default).
- WebRTC ignores the AOSP AEC/NS by UUID (`canUseAcousticEchoCanceler: false`, it even disables
  the auto-attached ones) and runs its own AECM (`echo_canceller: mobile_mode 1`, fixed
  `delay_estimate 150 ms`). Residual distorted echo remains; it drops further with JamesDSP off
  (its compressor/limiter makes the echo path non-linear). Mic gain changes don't help (linear).
- Ideas not done: keep JamesDSP off call audio (toggle in calls / separate VoIP output), or
  rebuild libaudiopreprocessing with other UUIDs so WebRTC uses it (sees post-JDSP reference
  and real delay via HAL `push_echo_reference`, same AECM algorithm).
- JamesDSP ships its own copy of `/vendor/etc/audio_effects.xml` (generated from the stock one at
  its install). `chagall_fixes/post-fs-data.sh` rewrites both copies at every boot (repo file + jdsp
  lines when JamesDSP is active) – no hand edit any more. Expected md5 with JamesDSP: `05cd6c98…`.
  (Old pre-fix JamesDSP copy saved as `../artifacts/audio_effects.jdsp.orig.xml`.)

### Bluetooth
- **A2DP music**: does not go through the codec. `persist.bluetooth.disableabsvol=true` is already
  set in this tree (`system_prop.mk`) → headset volume independent. User accepts this.
- **HFP/SCO calls (Telegram + Jabra Elite 75t): FIXED 2026-11-09** (audio both ways, volume low).
  History below; two causes, see "Root cause" and "2026-11-09 test".
  - SCO link comes up, CVSD narrowband (`bt_wbs=off`), HAL applies `bt-sco-headset`/`bt-sco-mic`,
    AIF3 routing correct (`AIF3TX1 Input 1 = ASRC1L`, `ASRC2L Input = AIF3RX1`), and the HAL
    has `pcmC0D2p` + `pcmC0D2c` open during the call (`logs/bt_test.txt`).
  - Installed `libbt-vendor.so` (`bluetooth/libbt-vendor.orig.so`): no runtime SCO params in
    `bt_vendor.conf`; compiled-in `bt_sco_i2spcm_param` at file offset **0x4014** =
    `01 01 00 01` = {I2S enabled, **role master**, 8 kHz, 256 kHz clk}.
  - **This tree's `bluetooth/libbt_vndcfg.txt` says `SCO_I2SPCM_IF_ROLE = 0` (slave)** – the
    shipped build doesn't match this tree revision (or the cfg isn't applied).
  - Tested patched lib with role = slave (`bluetooth/libbt-vendor.role-slave.so`, Magisk module
    `magisk/TabS_bt_call_test.zip`, id `chagall_bt_sco_slave`): **still silent** → should be
    disabled/removed on the tablet.
  - No `AIF3 Mode` mixer control (only `AIF2 Mode`). Next suspects: kernel machine driver
    AIF3 `dai_fmt` (I2S vs DSP, master/slave) in `kernel/samsung/exynos5420` sound/soc/samsung,
    BT chip PCM pin config, compare with stock Samsung firmware's BT config.
  - Logs: `logs/btcall_log.txt`, `logs/bt_debug.txt`, `logs/bt_test.txt`.
  - **Root cause found (Claude Code session, 2026-11-09), fix in source, not yet tested on device:**
    1. Kernel `sound/soc/samsung/adonisuniv_wm5102.c` (`adonisuniv_wm5102_aif3_hw_params`) sets
       AIF3 to `SND_SOC_DAIFMT_I2S | CBM_CFM` → **codec is I2S clock master, BT chip must be slave**
       (AIF3 clocked from ASYNCCLK/FLL2, which the `AIF2Master` path + open pcmC0D1 start).
       The tree's `SCO_I2SPCM_IF_ROLE = 0` is therefore correct.
    2. `hardware/broadcom/libbt` (lineage-17.1) reads **`BOARD_CUSTOM_BT_CONFIG`**, not
       `BOARD_BLUEDROID_VENDOR_CONF` → `libbt_vndcfg.txt` was ignored, `vnd_generic.txt` used
       (role default = 1 master, 3 Mbaud). That is why the shipped lib has role=1.
    3. The Treble BT HAL (`hardware/interfaces/bluetooth/1.0/default/vendor_interface.cc`) never
       calls `BT_VND_OP_SCO_CFG` / `SET_AUDIO_STATE`, so `hw_sco_config()` (the I2S/PCM VSC) is
       **never sent** unless libbt is built with `BTHW_FW_EXTENDED_CONFIGURATION = TRUE`.
       → explains why patching the role byte alone changed nothing.
    - Fix: `BoardConfigCommon.mk` adds `BOARD_CUSTOM_BT_CONFIG`; `bluetooth/libbt_vndcfg.txt` adds
      `BTHW_FW_EXTENDED_CONFIGURATION = TRUE`, keeps role 0, baud set to 3000000 (what actually ran).
    - Verify after flashing new lib: `logcat | grep -iE "I2SPCM config|sco I2S/PCM config result"`
      right after toggling BT on – expect `I2SPCM config {0x1, 0x0, 0x0, 0x1}` and result 0.
    - If still silent: SCO routing (PCM vs HCI) is left at firmware default in I2S mode; next step
      would be a libbt patch that also sends `HCI_VSC_WRITE_SCO_PCM_INT_PARAM` (routing 0).
  - Build chain: see `../build-env/README.md`. **Verified**: unmodified build of libbt-vendor.so is
    byte-identical to the tablet's (md5 ab514846...), generated from `vnd_generic.txt`.
  - Fixed lib: md5 e5793f73..., Magisk module id `chagall_bt_sco_fix`. Before the fix, a BT off/on log shows
    `vendor lib fwcfg completed` going straight to `OnFirmwareConfigured` (no I2SPCM config sent).
  - **2026-11-09 test of sco-fix lib:** `I2SPCM config {0x1, 0x0, 0x0, 0x1}`, result 0, A2DP fine,
    SCO link opens (CVSD, `bt_wbs=off`), HAL opens AIF3 8 kHz/BCLK 256 kHz – but call still silent
    both ways. Log (`artifacts/bt_sco_fix_call.txt`): when Telegram opens the mic, path
    `bt-sco-mic` → `bt-sco-hs-mic` → `verb-voicecall` sets `AIF2 Mode` = Slave, and
    `set_aif2_mode()` in the machine driver **stops FLL2** on Master→Slave. FLL2 = ASYNCCLK
    feeds AIF2/AIF3; nothing restarts it (only AIF2 hw_params does) and no modem drives AIF2 on
    Wi-Fi models → AIF3 has no clocks → silence. Same in the stock mixer file.
  - Fix (**verified 2026-11-09: BT call audio both ways**, volume low): `<ctl name="AIF2 Mode" value="Master" />` at the end of `bt-sco-hs-mic`
    (libaudioroute: direct `<ctl>` = last wins, sub-`<path>` duplicates = first wins). In
    `../patches/device/samsung/chagall-common/0002-*.patch`; in module `chagall_fixes`.

### JamesDSP setup (current, working)
- Module: `Magisk-Modules-Repo/ainur_jamesdsp` (MMT-Extended). Install aborted with
  "Volume key not detected" (getevent swamped by sensor events) – fixed by
  `magisk/ainur_jamesdsp_common_install.sh.patch` (hard-select Original UI). App: `james.dsp`,
  engine `JamesDSP v4.01`, `/vendor/lib/soundfx/libjamesdsp.so`, registered in audio_effects.
- **Android rule that bit us:** AudioFlinger suspends all global (session 0) effects whenever
  any other session has an enabled effect. Culprits found and removed:
  - LineageOS **AudioFX** (`org.lineageos.audiofx`) → was `pm disable`; now hidden systemlessly by
    `chagall_fixes` (`system/priv-app/AudioFX/.replace`)
  - **SmartTube** (`org.smarttube.stable`) → Player → Misc → **"Auto volume adjustment" OFF**
    (it enables LoudnessEnhancer on its session; Volume 100% alone was not enough).
- JamesDSP ⋮ → **Reg: Global** (Conventional mode does not work with SmartTube: it never
  broadcasts its audio session).
- Speaker profile: limiter threshold **−9 dB**; FIR/IIR EQ (IIR 8 order) 25/40/63/100 Hz ≈ −9,
  160 −6, 250 −3, 2.5k/4k ≈ +1.5, rest 0; Dynamic range compander enabled, curve
  95 Hz 0, 200 +0.2→~0.4, 400–3.4k +0.55→~0.8, 7.5k +0.3→~0.5 (user tweaked last values);
  bass boost, reverb, convolver etc. off. Screenshots in `screenshots/`.
  Saved preset "Tab S 10.5" (on tablet `/sdcard/JamesDSP/Presets/Tab S 10.5/`) exported to
  `jamesdsp-preset/` (identical to live settings on 2026-11-10).
- Verified via `dumpsys media.audio_flinger`: JamesDSP `Enabled y, Suspended n` during
  SmartTube playback (`logs/jdsp_check8.txt`).

## Current state of the tablet

As of 2026-11-10 02:40 (Magisk 25.2):
- Modules: **`chagall_fixes` v1** (ours, verified after reboot: libbt `e5793f73`, mixer `f0c7fdab`,
  policy `452e5695`, effects `05cd6c98`, AudioFX hidden, BT SCO config result 0), `ainur_jamesdsp`,
  `playintegrityfix`, `MagiskHidePropsConf` (**disabled**, was already; PIF covers it).
  Old `chagall_bt_sco_fix` / `chagall_mic_fix` / `chagall_voip_speaker` / `chagall_bt_sco_slave` removed.
- Deathly Adiutor speaker boost 0 dB (still installed); SmartTube auto volume off.
- `/data/local/tmp` cleaned 2026-11-10 (only `50i96f79`, `7037kk` left – not ours, 2025). Sweep log
  and the old JamesDSP effects copy were saved to `../artifacts/` first.
- `adb reboot` with USB connected may end on the Samsung charging screen (LPM) → hold Power.

## Next steps (open)

1. **BT call gain** (parked, needs a second person) – see "BT call gain" above.
2. **Speakerphone echo residual** – options in "Speakerphone VoIP echo" (JamesDSP off during calls,
   or AOSP preprocessing with changed UUIDs so WebRTC uses it).
3. BT-mic recording outside calls (ASR etc.) – needs an audio HAL change (start SCO PCMs when a
   BT SCO input is active, not only in call modes). Optional.
4. Optional: `Speaker High Performance Switch` = 1 (quality, not loudness).
5. Galaxy Alpha custom ROM – separate project, `D:\SOURCES\galaxy-alpha\DEVELOPMENT-PLAN.md`.

## Handy commands (Windows cmd, outside `adb shell`)

```
cd /d D:\SOURCES\android_device_samsung_universal5420-common
adb shell "su -c 'dumpsys media.audio_flinger'" > artifacts\af.txt 2>&1
adb exec-out screencap -p > artifacts\shot.png
adb shell "su -c 'tinymix'" > artifacts\tinymix.txt
```
`scripts/wm5110_tune.sh` (push to /sdcard, run as root): `state`, `mic`, `mic-off`,
`bt-state`, `bt`, `bt-off`, `bt-test`, `lastcrash`, `files`.

## Working with the user

Dmitry is a developer, but not an Android one. He prefers one copy-paste command block at a time and
explicit "run this in Windows cmd" vs "on the tablet". Output files go to `artifacts\` in this repo
(not Downloads – changed 2026-11-09 at his request). For reboots: ask once, then reboot via adb
yourself and re-set `adb logcat -G 16M` afterwards (default buffer rolls over during calls).
The local branches are never pushed.
