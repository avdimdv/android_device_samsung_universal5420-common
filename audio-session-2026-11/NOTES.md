# Galaxy Tab S 10.5 (chagallwifi) – audio session handoff (2026-11-08/09)

Work done interactively with Claude (Cowork). This folder holds everything
needed to continue in Claude Code. Paths below are relative to this folder.

## Device / environment

| Item | Value |
|---|---|
| Device | Samsung Galaxy Tab S 10.5 Wi-Fi, SM-T800, codename `chagallwifi` |
| ROM | Unofficial LineageOS 17.1 (Android 10, API 29), XDA thread 4270943 – maintainer has stopped |
| Kernel | 3.4 (Samsung exynos5420), 32-bit ARM (armeabi-v7a), SELinux Enforcing |
| Root | Magisk 25.2. `adb root` is disabled → use `adb shell "su -c '...'"` (shell granted in Magisk) |
| Audio codec | Wolfson/Cirrus **WM5110** ("Florida"); ALSA DAIs show up as `wm5102-aif1/2/3` |
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
  invalid values clamped to 31. Speaker values left stock. See `config/mixer_paths_0.micfix.diff`.
- Installed as Magisk module `magisk/TabS_mic_fix.zip` (id `chagall_mic_fix`). Confirmed working.

### VoIP calls (Telegram) play nothing until "Speaker" is pressed
- Cause: `configs/audio/audio_policy_configuration.xml` in this device tree lists
  **`Earpiece` in `<attachedDevices>`**; the Wi-Fi tablet has no earpiece, so Telecom routes
  communication audio to EARPIECE (seen in logcat: `route: EARPIECE`).
- **Fix (2026-11-09, pending test):** Earpiece removed from attachedDevices, devicePorts and routes
  in `configs/audio/audio_policy_configuration.xml` (uncommitted). Engine falls back to
  `defaultOutputDevice` (Speaker); Telecom only offers EARPIECE if `TYPE_BUILTIN_EARPIECE` exists.
  Test module: `artifacts/TabS_voip_speaker.zip` (id `chagall_voip_speaker`, from
  `build-env/07-make-policy-module.sh`). Note: file is shared by all universal5420 devices.

### Bluetooth
- **A2DP music**: does not go through the codec. `persist.bluetooth.disableabsvol=true` is already
  set in this tree (`system_prop.mk`) → headset volume independent. User accepts this.
- **HFP/SCO calls (Telegram + Jabra Elite 75t): total silence both directions.** Not fixed.
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
  - Fixed lib: `bluetooth/libbt-vendor.sco-fix.so` (md5 e5793f73...), Magisk module
    `../artifacts/TabS_bt_sco_fix.zip` (id `chagall_bt_sco_fix`). Before the fix, a BT off/on log shows
    `vendor lib fwcfg completed` going straight to `OnFirmwareConfigured` (no I2SPCM config sent).
  - **2026-11-09 test of sco-fix lib:** `I2SPCM config {0x1, 0x0, 0x0, 0x1}`, result 0, A2DP fine,
    SCO link opens (CVSD, `bt_wbs=off`), HAL opens AIF3 8 kHz/BCLK 256 kHz – but call still silent
    both ways. Log (`artifacts/bt_sco_fix_call.txt`): when Telegram opens the mic, path
    `bt-sco-mic` → `bt-sco-hs-mic` → `verb-voicecall` sets `AIF2 Mode` = Slave, and
    `set_aif2_mode()` in the machine driver **stops FLL2** on Master→Slave. FLL2 = ASYNCCLK
    feeds AIF2/AIF3; nothing restarts it (only AIF2 hw_params does) and no modem drives AIF2 on
    Wi-Fi models → AIF3 has no clocks → silence. Same in the stock mixer file.
  - Fix (**verified 2026-11-09: BT call audio both ways**, volume low): `<ctl name="AIF2 Mode" value="Master" />` at the end of `bt-sco-hs-mic`
    in `config/mixer_paths_0.micfix.xml` (libaudioroute: direct `<ctl>` = last wins, sub-`<path>`
    duplicates = first wins). Packaged by `build-env/06-make-mixer-module.sh` as
    `artifacts/TabS_mic_fix.zip` v2 (same id `chagall_mic_fix`, replaces v1).

### JamesDSP setup (current, working)
- Module: `Magisk-Modules-Repo/ainur_jamesdsp` (MMT-Extended). Install aborted with
  "Volume key not detected" (getevent swamped by sensor events) – fixed by
  `magisk/ainur_jamesdsp_common_install.sh.patch` (hard-select Original UI). App: `james.dsp`,
  engine `JamesDSP v4.01`, `/vendor/lib/soundfx/libjamesdsp.so`, registered in audio_effects.
- **Android rule that bit us:** AudioFlinger suspends all global (session 0) effects whenever
  any other session has an enabled effect. Culprits found and removed:
  - LineageOS **AudioFX** (`org.lineageos.audiofx`) → `pm disable org.lineageos.audiofx`
  - **SmartTube** (`org.smarttube.stable`) → Player → Misc → **"Auto volume adjustment" OFF**
    (it enables LoudnessEnhancer on its session; Volume 100% alone was not enough).
- JamesDSP ⋮ → **Reg: Global** (Conventional mode does not work with SmartTube: it never
  broadcasts its audio session).
- Speaker profile: limiter threshold **−9 dB**; FIR/IIR EQ (IIR 8 order) 25/40/63/100 Hz ≈ −9,
  160 −6, 250 −3, 2.5k/4k ≈ +1.5, rest 0; Dynamic range compander enabled, curve
  95 Hz 0, 200 +0.2→~0.4, 400–3.4k +0.55→~0.8, 7.5k +0.3→~0.5 (user tweaked last values);
  bass boost, reverb, convolver etc. off. Screenshots in `screenshots/`.
- Verified via `dumpsys media.audio_flinger`: JamesDSP `Enabled y, Suspended n` during
  SmartTube playback (`logs/jdsp_check8.txt`).

## Current state of the tablet

- Magisk modules: MagiskHidePropsConf, playintegrityfix, `chagall_mic_fix` (keep),
  `ainur_jamesdsp` (keep), `chagall_bt_sco_slave` (useless – disable/remove).
- AudioFX disabled; Deathly Adiutor speaker boost set to 0 dB (still installed).
- SmartTube auto volume off.

## Suggested next steps (for Claude Code)

1. Fold the mixer_paths mic fix + out-of-range fixes into the device repo that ships
   `mixer_paths_0.xml` (likely the chagall/klimt device repo, not this common tree).
2. Fix VoIP earpiece routing in `configs/audio/audio_policy_configuration.xml` (or Magisk overlay).
3. BT SCO: inspect kernel AIF3 DAI format / clocking vs `libbt_vndcfg.txt`; explain why the
   shipped lib has role=1 although the tree says 0.
4. Optional: try `Speaker High Performance Switch` = 1 (quality, not loudness).

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
(not Downloads – changed 2026-11-09 at his request).
