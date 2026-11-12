
# ---- chagall_fixes ----
# Only for the Galaxy Tab S 10.5 Wi-Fi on LineageOS 17.1 (Android 10): the module replaces
# libbt-vendor.so and audio configs that were built for exactly this device and ROM.
DEV=$(getprop ro.product.device); [ -n "$DEV" ] || DEV=$(getprop ro.build.product)
SDK=$(getprop ro.build.version.sdk)
[ "$DEV" = chagallwifi ] || abort "! This module is only for chagallwifi (SM-T800); this device is '$DEV'."
[ "$SDK" = 29 ] || abort "! This module is only for LineageOS 17.1 (Android 10); this ROM is SDK $SDK."
case "$(getprop ro.lineage.version)" in
  17.1*) ;;
  *) ui_print "! WARNING: not LineageOS 17.1 ('$(getprop ro.lineage.version)') - made for the 17.1 'deathly' ROM" ;;
esac

if [ -e /sys/class/misc/wolfson_control ]; then
  ui_print "- kernel: stock (Wolfson Control present)"
  ui_print "  -> speaker hardware EQ/limiter stays OFF; flash chagall_kernel_nohook.zip to get it"
else
  ui_print "- kernel: hook-free -> speaker hardware EQ + limiter ON"
fi

# chagall_fixes replaces the earlier single-purpose modules: mark them for removal on next boot.
for m in chagall_bt_sco_fix chagall_mic_fix chagall_voip_speaker chagall_bt_sco_slave; do
  if [ -d "/data/adb/modules/$m" ]; then
    touch "/data/adb/modules/$m/remove"
    ui_print "- old module $m will be removed on reboot"
  fi
done
# v2-v4 hid AudioFX; it is left alone now (make sure nothing of that is carried over)
rm -rf "$MODPATH/system/priv-app"
ui_print "- reboot to activate"
