# artifacts/

Everything produced for the PC/tablet ends up here (not in Downloads):

- `TabS_bt_sco_fix.zip` – Magisk module from `build-env/05-make-bt-module.sh`
- `libbt-vendor.so` + `libbt-vendor.so.md5` – the library inside that module
- adb captures (`dumpsys`, `logcat`, screenshots) taken during testing

Binaries and captures are git-ignored (see `.gitignore`); only this README is tracked.
