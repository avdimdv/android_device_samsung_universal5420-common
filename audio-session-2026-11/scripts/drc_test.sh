#!/system/bin/sh
# WM5102 hardware DRC1 in the speaker path – live tests (run as root on the Tab S).
# Needs OUR kernel (patches/kernel/.../0001: Wolfson Control hook removed); with the stock kernel
# SPKOUT input writes are silently replaced (see NOTES "Why DRC/EQ on the speaker fails").
#
#   sh drc_test.sh state       routing, DRC1 registers, output standby
#   sh drc_test.sh drc on      AIF1RX1/2 -> DRC1L/R -> SPKOUTL/R   (DAPM powers DRC1 with the path)
#   sh drc_test.sh drc off     AIF1RX1/2 -> SPKOUTL/R              (stock routing)
#   sh drc_test.sh cfg default|d2|<10 hex bytes>   DRC1 settings (raw DRC1_CTRL1..5)
#   sh drc_test.sh log         codec/kernel messages since the last change
# Every change is refused unless all outputs are in standby (NOTES "DANGER").
MARK=/data/local/tmp/drc_test.mark

standby_ok() { [ "$(dumpsys media.audio_flinger | grep -c '^  Standby: no')" -eq 0 ]; }
sel() { tinymix "$1" | grep -o '>[A-Za-z0-9._]*' | tr -d '>'; }
need_idle() { standby_ok || { echo "REFUSED: an output is not in standby (stop playback, wait ~5 s)"; exit 1; }; }
mark() { dmesg | tail -n 1 | sed 's/^\[ *\([0-9.]*\)\].*/\1/' > $MARK; echo "$* at kernel time $(cat $MARK)"; }

case "$1" in
state)
  echo "SPKOUT L/R Input 1 : $(sel 'SPKOUTL Input 1') / $(sel 'SPKOUTR Input 1')"
  echo "DRC1 L/R Input 1   : $(sel 'DRC1L Input 1') / $(sel 'DRC1R Input 1')"
  tinymix "DRC1"
  dumpsys media.audio_flinger | grep -E "^  Standby:" | sort | uniq -c
  ;;
drc)
  need_idle
  if [ "$2" = on ]; then
    tinymix "DRC1L Input 1" AIF1RX1; tinymix "DRC1R Input 1" AIF1RX2
    tinymix "SPKOUTL Input 1" DRC1L;  tinymix "SPKOUTR Input 1" DRC1R
  elif [ "$2" = off ]; then
    tinymix "SPKOUTL Input 1" AIF1RX1; tinymix "SPKOUTR Input 1" AIF1RX2
    tinymix "DRC1L Input 1" None;     tinymix "DRC1R Input 1" None
  else echo "usage: drc on|off"; exit 1; fi
  mark "drc $2"; sh $0 state
  ;;
eq)
  # hardware EQ in front of DRC1: AIF1RX1/2 -> EQ1/EQ2 -> DRC1L/R (needs "drc on")
  # gains 0..24, 12 = 0 dB; bands ~100 Hz shelf / 300 / 875 / 2.4k / 6.9 kHz shelf (chip defaults)
  need_idle
  if [ "$2" = on ]; then
    shift 2; set -- ${*:-3 9 12 13 12}      # E1: -9 -3 0 +1 0 dB
    for e in EQ1 EQ2; do
      b=1; for g in "$@"; do tinymix "$e B$b Volume" $g; b=$((b+1)); done
    done
    tinymix "EQ1 Input 1" AIF1RX1;  tinymix "EQ2 Input 1" AIF1RX2
    tinymix "DRC1L Input 1" EQ1;    tinymix "DRC1R Input 1" EQ2
  elif [ "$2" = off ]; then
    tinymix "DRC1L Input 1" AIF1RX1; tinymix "DRC1R Input 1" AIF1RX2
    tinymix "EQ1 Input 1" None;      tinymix "EQ2 Input 1" None
  else echo "usage: eq on [g1 g2 g3 g4 g5] | eq off"; exit 1; fi
  mark "eq $*"; sh $0 state
  for e in EQ1 EQ2; do echo "$e gains: $(for b in 1 2 3 4 5; do tinymix "$e B$b Volume" | sed 's/.*: //'; done | tr '\n' ' ')  input: $(sel "$e Input 1")"; done
  ;;
cfg)
  # DRC1_CTRL1..5 as 10 bytes (big-endian per register), ENA bits are masked by the control.
  #   default : 00 18 09 33 00 18 00 00 00 00   (QR+anticlip, 1:1 below/1:8 above a 0 dB knee)
  #   d2      : 00 18 09 33 00 28 05 10 00 00   (knee -30 dB in -> -12 dB out, limit above)
  need_idle
  case "$2" in
    default) set -- x 00 18 09 33 00 18 00 00 00 00 ;;
    d2)      set -- x 00 18 09 33 00 28 05 10 00 00 ;;
  esac
  shift
  [ $# -eq 10 ] || { echo "usage: cfg default|d2|<10 hex bytes>"; exit 1; }
  dec=""; for b in "$@"; do dec="$dec $(printf '%d' "0x$b")"; done   # tinymix wants decimal
  tinymix "DRC1" $dec
  mark "cfg $*"; sh $0 state
  ;;
log)
  t=$(cat $MARK 2>/dev/null || echo 0)
  dmesg | awk -v t="$t" '{ s=$0; sub(/^\[ */,"",s); split(s,a,"]"); if (a[1]+0 > t+0) print }' \
    | grep -i -E "arizona|wm5102|drc|dapm|error|fail|timeout|lockup|bug|warn" \
    | grep -v -E "FLL1|SYSCLK|ASYNCCLK|bias_level|BCLK|Spurious HPDET" | tail -n 30
  echo "write errors in logcat: $(logcat -d | grep -c -E 'out_write: error|write blocked')"
  ;;
*) echo "usage: $0 state | drc on|off | log"; exit 1 ;;
esac
