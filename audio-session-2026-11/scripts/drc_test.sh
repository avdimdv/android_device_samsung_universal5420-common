#!/system/bin/sh
# WM5102 hardware DRC1 on the speaker, via Wolfson Control (run as root on the Tab S).
#
# Background: arizona-control.c ("Wolfson Control", /sys/class/misc/wolfson_control) hooks all
# codec register writes and LOCKS the speaker mixer input 1 (SPKOUT = OUT4) to the value written at
# boot – mixer_paths/tinymix writes to "SPKOUTx Input 1" are silently replaced, while DAPM believes
# them. Its own speaker-EQ switch re-routes SPKOUT to EQ3/EQ4 with hook-protected writes; the EQ3/4
# and DRC1 input muxes and DRC1 enable bits pass through. So:
#     AIF1RX1/2 -> DRC1L/R -> EQ3/EQ4 -> SPKOUTL/R      (DAPM never sees DRC1/EQ3 in its graph)
#
#   sh drc_test.sh state          routing, enables, DRC1 registers, output standby
#   sh drc_test.sh eqsp on|off    Wolfson Control speaker EQ bridge (SPKOUT <- EQ3/EQ4)
#   sh drc_test.sh drc on|off     put DRC1 in front of EQ3/EQ4 (needs eqsp on) / take it out
#   sh drc_test.sh log            codec/kernel messages since the last change
# Every change is refused unless all outputs are in standby (NOTES "DANGER").
WC=/sys/class/misc/wolfson_control
MARK=/data/local/tmp/drc_test.mark

standby_ok() { [ "$(dumpsys media.audio_flinger | grep -c 'Standby: no')" -eq 0 ]; }
sel() { tinymix "$1" | grep -o '>[A-Za-z0-9._]*' | tr -d '>'; }
need_idle() { standby_ok || { echo "REFUSED: an output is not in standby (stop playback, wait ~5 s)"; exit 1; }; }
mark() { dmesg | tail -n 1 | sed 's/^\[ *\([0-9.]*\)\].*/\1/' > $MARK; echo "$* at kernel time $(cat $MARK)"; }

case "$1" in
state)
  echo "SPKOUT L/R Input 1 : $(sel 'SPKOUTL Input 1') / $(sel 'SPKOUTR Input 1')"
  echo "EQ3 / EQ4 Input 1  : $(sel 'EQ3 Input 1') / $(sel 'EQ4 Input 1')"
  echo "DRC1 L/R Input 1   : $(sel 'DRC1L Input 1') / $(sel 'DRC1R Input 1')"
  echo "DRC1 L/R ENA       : $(tinymix DRC1L_ENA | sed 's/.*: //') / $(tinymix DRC1R_ENA | sed 's/.*: //')"
  echo "switch_eq_speaker  : $(cat $WC/switch_eq_speaker)"
  tinymix "DRC1"
  dumpsys media.audio_flinger | grep -E "Standby:" | sort | uniq -c
  ;;
eqsp)
  need_idle
  case "$2" in on) echo 1 > $WC/switch_eq_speaker ;; off) echo 0 > $WC/switch_eq_speaker ;; *) exit 1 ;; esac
  mark "eqsp $2"; sh $0 state
  ;;
drc)
  need_idle
  if [ "$2" = on ]; then
    [ "$(cat $WC/switch_eq_speaker)" = 1 ] || { echo "REFUSED: run 'eqsp on' first"; exit 1; }
    tinymix "DRC1L Input 1" AIF1RX1; tinymix "DRC1R Input 1" AIF1RX2
    tinymix DRC1L_ENA ON;            tinymix DRC1R_ENA ON
    tinymix "EQ3 Input 1" DRC1L;     tinymix "EQ4 Input 1" DRC1R
  elif [ "$2" = off ]; then
    tinymix "EQ3 Input 1" AIF1RX1;   tinymix "EQ4 Input 1" AIF1RX2
    tinymix DRC1L_ENA OFF;           tinymix DRC1R_ENA OFF
    tinymix "DRC1L Input 1" None;    tinymix "DRC1R Input 1" None
  else exit 1; fi
  mark "drc $2"; sh $0 state
  ;;
log)
  t=$(cat $MARK 2>/dev/null || echo 0)
  dmesg | awk -v t="$t" '{ s=$0; sub(/^\[ */,"",s); split(s,a,"]"); if (a[1]+0 > t+0) print }' \
    | grep -i -E "arizona|wm5102|drc|dapm|bias|sysclk|error|fail|timeout|lockup|bug|warn" | tail -n 40
  ;;
*) echo "usage: $0 state | eqsp on|off | drc on|off | log"; exit 1 ;;
esac
