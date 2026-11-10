# CLAUDE.md

LineageOS 17.1 device tree for Samsung Exynos 5420 (universal5420-common), used for the
Galaxy Tab S 10.5 Wi-Fi (`chagallwifi`, SM-T800).

Audio/Bluetooth work lives in `audio-session-2026-11/` – read `audio-session-2026-11/NOTES.md`
first (status table at the top). It lists the device facts, the commands that **crash this
kernel** (avoid them), what is fixed (mic gain, BT HFP call audio, VoIP to speaker, AEC config,
JamesDSP limiter) and what is open (BT call gain – parked, residual speakerphone echo).
All on-device fixes ship as one Magisk module `chagall_fixes` (`magisk/README.md` has the
reinstall checklist).

Build chain (WSL Ubuntu 20.04, tree at `~/lineage`): see `build-env/README.md`. Edit files here
on D:\, then `build-env/03-overlay-local-tree.sh` + `04-build.sh` inside WSL.
Changes to other repos of the tree (e.g. `mixer_paths_0.xml`, which lives in chagall-common) are
kept as `patches/<project path>/*.patch`, applied by 03. Magisk modules: sources in
`magisk/`, built by `build-env/05-make-magisk-modules.sh` into `artifacts\` (git-ignored).
Branch `audio-bt-call-fixes` is local only – never push. Separate project: Galaxy Alpha custom
ROM plan on local orphan branch `galaxy-alpha`, worktree `D:\SOURCES\galaxy-alpha`.

The tablet is reachable with `adb` from this Windows PC; root only via
`adb shell "su -c '...'"` (adb root is disabled).
