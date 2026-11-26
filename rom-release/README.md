# Galaxy Tab S 10.5 Wi-Fi (SM-T800) – LineageOS 17.1 with audio, Bluetooth call and fingerprint fixes

Unofficial **LineageOS 17.1 (Android 10)** for **chagallwifi**, built from HazouPH's
`lineage-17.1-deathly` tree with the fixes of the `chagall_fixes` Magisk module built in.
`userdebug`, SELinux enforcing, signed with the public AOSP test keys. Tested on one tablet only.
Use at your own risk.

| File | What it is |
|---|---|
| `lineage-17.1-<date>-UNOFFICIAL-chagallwifi.zip` | The ROM (TWRP) |
| `key-migration-hazouph-to-aosp.zip` | Only when switching **from HazouPH's 17.1 with data kept** (see Install) |
| `SHA256SUMS` | Checksums |

## What is different from HazouPH's prebuilt ROM

Everything the `chagall_fixes` module and `chagall_kernel_nohook.zip` do, now inside the image:

- **Bluetooth calls (HFP) have audio in both directions.**
- **Microphone is louder** (+15 dB main mic, out-of-range mixer values corrected).
- **VoIP calls (Telegram, WhatsApp …) play on the speakers** without tapping "Speaker".
- **Echo canceller / noise suppression config works** (Android's own effects instead of Samsung's
  missing ones).
- **Speaker: hardware EQ + limiter** in the WM5102 chip – about +6 dB louder with no clipping, bass
  the small speakers cannot play removed. The kernel is built without the "Wolfson Control" hook
  that froze playback with this routing (the Deathly kernel app's sound tweaks have no effect).
- **AudioFX is not installed** – it would stack a software EQ and a second compressor in front of
  the hardware chain.
- **Fingerprint (swipe sensor in the home button) works**: fixed HAL (unlock, enrol/remove
  reporting, no hangs or crashes, no "Sensor is busy"), **5 slots instead of 3**, and Settings says
  **"swipe"** and points to the home button.
- **Play Integrity "Basic" passes without root or modules** (framework spoof for Google Play
  Services). Device/Strong do not pass on this hardware.
- **Camcorder**: correct colours and no hang when saving (Exynos encoder gets the camera's native
  NV21 format; software video decoder loads on this device).

Lost compared with HazouPH's ROM: **signature spoofing** (`FAKE_PACKAGE_SIGNATURE`). microG-based
setups that need it will not work; ReVanced's GmsCore does not need it for login.

## Install

You need TWRP. Back up first (TWRP backup of Boot, System and Data).

**A. From HazouPH's LineageOS 17.1, keeping apps and data**

HazouPH signs his builds with his own keys, this ROM uses the AOSP test keys. Without step 3 Android
finds that all its system apps changed their signature and does not boot properly.

1. If installed, **remove** (not disable) the `chagall_fixes` module and the kernel marker module
   ("Tab S 10.5 (SM-T800) kernel: …") in the Magisk app. The ROM contains the same files, and an
   old module would put its copies over the newer ones at every boot.
2. TWRP → Install → `lineage-17.1-…-chagallwifi.zip`. Google apps and Magisk are kept (their
   addon.d scripts run during the install).
3. TWRP → Install → `key-migration-hazouph-to-aosp.zip` – **before the first boot**. It rewrites the
   signing certificates in `/data/system/packages.xml` (nothing else), keeps a backup as
   `packages.xml.before-key-migration`, and does nothing if the file does not contain HazouPH's keys.
4. TWRP → Wipe → Advanced → **Dalvik/ART Cache** and **Cache**.
5. Reboot. The first boot takes several minutes and may restart once by itself.

**B. Clean install** (any other ROM, or from HazouPH's 18.1/20/21 – Android cannot go back a
version with data kept)

1. TWRP → Wipe → Format Data, and wipe System, Cache, Dalvik.
2. Install the ROM zip; optionally Google apps for Android 10 ARM (e.g. MindTheGapps 10.0.0 arm)
   and Magisk.
3. Reboot.

## Fingerprint: how to enrol

Enrol the **same finger in all 5 slots** and vary the swipes a little (slightly left, right, faster,
slower). A swipe sees only a strip of the finger and is compared with every stored print: with one
enrolment only about 1 swipe in 6 unlocks, with the same finger enrolled 5 times most swipes do.
Swipe slowly and straight. It is a 2014 swipe sensor – a few rejected swipes are normal.

If you enrolled fingerprints on HazouPH's ROM, remove them in Settings and enrol again; if unlock
still fails, as root:
`stop vendor.fps_hal; mv /data/validity/finger.db /data/validity/finger.db.old; start vendor.fps_hal`
(the old HAL can leave a hidden template behind that Settings cannot delete).

## Undo (back to HazouPH's ROM)

TWRP → copy `/data/system/packages.xml.before-key-migration` over `/data/system/packages.xml`
(TWRP → Advanced → File Manager, or `adb shell`), flash HazouPH's 17.1 zip, wipe Dalvik/Cache,
reboot. Or restore your TWRP backup.

## Not fixed

- Bluetooth call volume/mic level is whatever the headset decides; not tuned.
- Recording from a Bluetooth mic outside of calls does not work (audio HAL limitation).
- Residual speakerphone echo in apps that use their own echo canceller.
- Fingerprint: several swipes are sometimes needed; rarely, right after a quick lock/unlock, the
  sensor stays busy for up to a minute.
- No notification LED on this tablet.

## Source

- Base: `github.com/hazouph` – `android_device_samsung_universal5420-common`,
  `android_device_samsung_chagall-common`, `android_kernel_samsung_exynos5420`
  (branch `lineage-17.1-deathly`), LineageOS 17.1.
- Changes: this repository – the device tree itself, `patches/` (chagall-common, kernel,
  vendor/lineage, frameworks/av, frameworks/base, hardware/samsung_slsi/exynos, Snap; listed in
  `build-env/README.md`), `key-migration/`, build scripts in `build-env/`.
