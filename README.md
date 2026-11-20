Copyright 2020 - The LineageOS Project

Common Samsung Exynos 5420 repository

---

## Releases

Published on this repo's **Releases** page: the `chagall_fixes` Magisk module, the two kernel-swap
zips and the GPL source patches, with `SHA256SUMS`. What each file is, how to install it and how to
undo it is documented in the `README.md` that ships inside the release (source:
`magisk/release/README.md`).

### Making a release by hand

1. In WSL (tree at `~/lineage`), build the pieces the package needs:
   `build-env/03-overlay-local-tree.sh`, then `build-env/04-build.sh` (produces the Bluetooth vendor
   library the module installs), then `build-env/06-build-kernel.sh` (produces
   `artifacts/kernel-nohook/zImage`).
2. `bash build-env/07-make-release.sh` assembles `artifacts/release/`: the module zip, both kernel
   zips, `source/` (kernel + audio patches with all e-mail addresses stripped), `README.md` and
   `SHA256SUMS`. It verifies the stock kernel md5 before packaging and prints a warning if any
   e-mail address survived.
3. Tag the commit the release corresponds to and publish. Either with the GitHub CLI:

   ```sh
   git tag -a v5 -m "chagall_fixes v5" && git push origin v5
   gh release create v5 \
     --title "chagall_fixes v5 (SM-T800 audio + BT fixes)" \
     --notes-file magisk/release/README.md \
     artifacts/release/chagall_fixes.zip \
     artifacts/release/chagall_kernel_nohook.zip \
     artifacts/release/chagall_kernel_stock.zip
   ```

   or without it: GitHub web UI -> **Releases -> Draft a new release** -> choose the tag -> paste the
   contents of `magisk/release/README.md` as the description -> attach the three zips and the
   `source/` folder (zip it first; the web UI only takes files).
4. Check the published assets download and that `SHA256SUMS` matches what you get.

Before anything here goes to a public venue (XDA): no Samsung/Google proprietary files in the
downloads, no serials / IMEIs / e-mail addresses / account names anywhere, and the private working
notes must be removed or rewritten for outsiders.
