
# chagall_fixes replaces the earlier single-purpose modules: mark them for removal on next boot.
for m in chagall_bt_sco_fix chagall_mic_fix chagall_voip_speaker chagall_bt_sco_slave; do
  if [ -d "/data/adb/modules/$m" ]; then
    touch "/data/adb/modules/$m/remove"
    ui_print "- old module $m will be removed on reboot"
  fi
done
