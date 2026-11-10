# Sourced by Magisk's install_module. Give every file this module replaces the SELinux label
# of the original (vendor files must not get Magisk's default system_file label).
for F in $(cd "$MODPATH" && find system -type f ! -name .replace); do
  CTX=$(ls -Z "/$F" 2>/dev/null | awk '{print $1}')
  if [ -z "$CTX" ]; then
    case "$F" in
      */etc/*) CTX=u:object_r:vendor_configs_file:s0 ;;
      *)       CTX=u:object_r:vendor_file:s0 ;;
    esac
  fi
  ui_print "- $F: $CTX"
  set_perm "$MODPATH/$F" 0 0 0644 "$CTX"
done
