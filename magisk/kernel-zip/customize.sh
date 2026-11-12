# Magisk app path (Modules -> Install from storage): the zip is installed as a small module whose
# only job is to swap the kernel now. The module that stays behind is just a marker in the list.
SKIPUNZIP=1
W=$TMPDIR/chagall_kernel
die() { ui_print " "; ui_print "! $1"; abort "! NOTHING WAS CHANGED."; }
rm -rf "$W"; mkdir -p "$W"
unzip -o "$ZIPFILE" 'kernel/*' -d "$W" >&2 || die "cannot unpack the zip"
unzip -o "$ZIPFILE" module.prop -d "$MODPATH" >&2
. "$W/kernel/swap.sh"
kernel_swap
rm -rf "$W"
# only one of the two kernel marker modules makes sense at a time
for m in chagall_kernel_nohook chagall_kernel_stock; do
  [ "$m" != "$MODID" ] && [ -d "/data/adb/modules/$m" ] && touch "/data/adb/modules/$m/remove"
done
