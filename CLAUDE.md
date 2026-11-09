# CLAUDE.md

LineageOS 17.1 device tree for Samsung Exynos 5420 (universal5420-common), used for the
Galaxy Tab S 10.5 Wi-Fi (`chagallwifi`, SM-T800).

Audio/Bluetooth investigation from a previous session lives in
`audio-session-2026-11/` – read `audio-session-2026-11/NOTES.md` first. It lists the
device facts, the commands that **crash this kernel** (avoid them), what is fixed
(mic gain, JamesDSP limiter for the speakers), and what is open (VoIP earpiece
routing in `configs/audio/audio_policy_configuration.xml`, Bluetooth SCO call audio).

Build chain (WSL Ubuntu 20.04, tree at `~/lineage`): see `build-env/README.md`. Edit files here
on D:\, then `build-env/03-overlay-local-tree.sh` + `04-build.sh` inside WSL.

The tablet is reachable with `adb` from this Windows PC; root only via
`adb shell "su -c '...'"` (adb root is disabled).
