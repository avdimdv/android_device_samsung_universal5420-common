# Galaxy Tab S 10.5 Wi-Fi (SM-T800) – audio and Bluetooth call fixes

For **chagallwifi** on **LineageOS 17.1 "deathly"** (HazouPH's unofficial build, Android 10) with
**Magisk** (tested with 25.2). Tested on one tablet only (module and kernel zip installed from the
Magisk app; the TWRP path of the kernel zip is untested). Use at your own risk.

| File | What it is | Needed? |
|---|---|---|
| `chagall_fixes.zip` | Magisk module with all fixes | yes |
| `chagall_kernel_nohook.zip` | Same kernel as the ROM's, with one bug removed. Enables the speaker EQ + limiter | optional |
| `chagall_kernel_stock.zip` | Puts the ROM's original kernel back | only to undo |
| `source/` | Kernel patch and audio config patches | – |

## What the module fixes

- **Bluetooth calls (HFP) have audio in both directions.** In the ROM the Bluetooth chip never gets
  its call-audio setup, and a mixer path stops the clock of the Bluetooth audio line.
- **Microphone is louder** (+15 dB on the main mic; some out-of-range mixer values corrected).
- **VoIP calls (Telegram, WhatsApp …) play on the speakers** without tapping "Speaker". The ROM
  declares a phone earpiece that this tablet does not have, so calls were silent.
- **Echo canceller / noise suppression config works.** The ROM points to Samsung effects that fail
  to load; the module uses Android's own. (Apps with their own echo canceller, e.g. Telegram,
  ignore it – some echo on speakerphone remains.)
- **Speaker: hardware EQ + limiter** in the WM5102 audio chip – about +6 dB louder with a hard
  ceiling (no clipping at full volume) and the bass the small speakers cannot play removed.
  **Only with `chagall_kernel_nohook.zip`**; with the ROM's kernel the module leaves this part out
  automatically and the speaker sounds as before.

The module does not touch AudioFX. On **our own ROM build AudioFX is not installed at all** - it
would put a software EQ/bass boost and a second compressor in front of the hardware EQ + limiter,
which only makes the speaker quieter and cause pumping. If you are on the prebuilt Deathly ROM,
AudioFX is still there: switch it **off for the speaker** (it keeps a profile per output device),
because its bass boost works against the tuned speaker chain. For headphones it is a matter of
taste - nothing in the module touches the headphone path.

The module is systemless: nothing on the system/vendor partitions is changed. Disable or remove it
in Magisk and everything is stock again.

## Install

1. Magisk app → Modules → **Install from storage** → `chagall_fixes.zip` → Reboot.
2. Optional, for the speaker EQ + limiter: Magisk app → Modules → Install from storage →
   `chagall_kernel_nohook.zip` → Reboot. (It also installs from TWRP → Install.)
   A small entry "Tab S 10.5 (SM-T800) kernel: hook-free" stays in the module list as a
   marker; it does nothing at boot. Removing it does not change the kernel.

Order does not matter; the module checks the kernel at every boot.

If you use JamesDSP, Viper or a similar speaker booster, switch its limiter/boost off once the
hardware limiter is active – they would add up.

## What the kernel zip does, and why it is needed

The ROM's kernel contains "Wolfson Control" (the sound tweaks in the Deathly kernel app). Its hook
drops a lock in the middle of every audio-chip register write and silently replaces writes to the
speaker input. Routing the speaker through the chip's EQ/limiter then freezes playback until
reboot. The kernel in the zip is HazouPH's kernel source at commit `73a7ba1f` (the one the ROM
ships) with that hook removed (`source/kernel-0001-*.patch`), built with the same toolchain.
Side effect: the sound tweaks of the Deathly kernel app have no effect any more.

The zip does **not** flash a boot image. It takes the boot image that is on your tablet, replaces
only the kernel inside it and writes it back – Magisk stays installed. It

- refuses to run on another device, or if the kernel on the tablet is not the known ROM kernel
  (md5 `86f50505f53dfd8780a8eca17398ca63`) – e.g. another ROM build;
- saves the current boot image to `Internal storage/chagall_kernel/boot-before-*.img`;
- reads the result back and restores the old image if it does not match.

After **reflashing the ROM or reinstalling Magisk into the boot image** the kernel is stock again:
flash `chagall_kernel_nohook.zip` once more.

## Undo

- Module: Magisk app → Modules → remove `Tab S 10.5 (SM-T800) audio + BT fixes` → Reboot.
- Kernel: flash `chagall_kernel_stock.zip` the same way, or in TWRP: Install → Install Image →
  `chagall_kernel/boot-before-*.img` → Boot.
- Tablet does not boot after the kernel zip: hold Power + Volume Down until it restarts, switch to
  Power + Home + Volume Up as soon as the screen goes black to enter TWRP, then restore the boot
  image as above.
- Tablet does not boot after the module: hold Volume Down while it boots (Magisk safe mode,
  disables all modules).

## Not fixed

- Bluetooth call volume/mic level is whatever the headset decides; not tuned.
- Recording from a Bluetooth mic outside of calls does not work (audio HAL limitation).
- Residual speakerphone echo in apps that use their own echo canceller.

## Source

- ROM device tree / kernel: `github.com/hazouph/android_device_samsung_universal5420-common`,
  `android_device_samsung_chagall-common`, `android_kernel_samsung_exynos5420`
  (branch `lineage-17.1-deathly`).
- `source/kernel-*.patch` – on kernel commit `73a7ba1f` (GPL-2.0).
- `source/chagall-common-*.patch` – `mixer_paths_0.xml` changes.
- `source/universal5420-common.diff` – Bluetooth vendor library config, audio policy, audio effects.
