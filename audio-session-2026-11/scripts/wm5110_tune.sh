#!/system/bin/sh
# Live tuning for Galaxy Tab S 10.5 (WM5110 codec) with tinymix.  v5
# Run on the tablet as root:   sh /sdcard/wm5110_tune.sh <mode>
#
#   files     - which mixer_paths files exist + Magisk modules (run once)
#   state     - short summary of current speaker/mic settings (run WHILE MUSIC PLAYS)
#   mic       - raise main mic gain (+15 dB)   (start a recording first)
#   mic-off   - mic back to stock path values
#   bt-state  - Bluetooth call routing/levels   (run DURING a BT call)
#   bt        - BT call: +6 dB to headset, +6 dB from headset mic
#   bt-off    - BT back to 0 dB
#   bt-test   - DURING a BT call: Bluetooth link test -> /sdcard/bt_test.txt + bt_mic.wav
#   lastcrash - after an unexpected reboot: save crash log -> /sdcard/lastcrash.txt
#
# Nothing here is permanent. A reboot always gives a clean state.

T=tinymix
command -v $T >/dev/null 2>&1 || { echo "tinymix not found"; exit 1; }

show() {  # print a control; for long enum lists print only the selected item
  v=$($T "$1" 2>&1)
  case "$v" in
    *dsrange*) echo "$v" | sed 's/ *(dsrange.*//' ;;
    *'>'*) echo "$1: $(echo "$v" | sed 's/.*>\([^ ]*\).*/\1/')" ;;
    *)     echo "$v" ;;
  esac
}

case "$1" in
files)
  for f in /vendor/etc/mixer_paths*.xml /system/etc/mixer_paths*.xml \
           /system/vendor/etc/mixer_paths*.xml /odm/etc/mixer_paths*.xml; do
    [ -f "$f" ] || continue
    echo "== $f  ($(wc -c < "$f") bytes)"
    grep -n -A3 '<path name="speaker">' "$f"
  done
  echo; echo "== Magisk modules:"; ls /data/adb/modules 2>/dev/null
  echo; echo "== modules that replace mixer files:"
  find /data/adb/modules -name 'mixer_paths*' 2>/dev/null ;;
state)
  for c in "SPK Switch" "Speaker Digital Volume" "SPKOUTL Input 1" "SPKOUTL Input 1 Volume" \
           "SPKOUTR Input 1" "SPKOUTR Input 1 Volume" "SPKOUTL Input 2" "SPKOUTL Input 3" \
           "Speaker High Performance Switch" \
           "IN1L Volume" "IN1L Digital Volume" "LHPF1 Input 1" "AIF1TX1 Input 1" \
           "AIF1TX1 Input 1 Volume"; do
    show "$c"
  done
  ;;
mic)
  $T "IN1L Volume" 30
  $T "IN1L Digital Volume" 146
  show "IN1L Volume"; show "IN1L Digital Volume" ;;
mic-off)
  $T "IN1L Volume" 24
  $T "IN1L Digital Volume" 128
  show "IN1L Volume"; show "IN1L Digital Volume" ;;
bt-state)
  # Run DURING a Bluetooth call / VoIP call with the BT headset.
  # If "AIF3TX1 Input 1" shows None during the call, the BT voice does not go
  # through the audio chip and these controls can't change it.
  for c in "AIF3TX1 Input 1" "AIF3TX1 Input 1 Volume" "AIF3TX2 Input 1 Volume" \
           "ASRC1L Input" "ASRC2L Input" \
           "AIF1TX1 Input 2" "AIF1TX1 Input 2 Volume" "AIF1TX2 Input 2 Volume"; do
    show "$c"
  done ;;
bt)
  # +6 dB both ways. 32 = 0 dB, 1 dB per step, max 48 (+16 dB, will clip).
  # Volume you hear in the BT headset:
  $T "AIF3TX1 Input 1 Volume" 38
  $T "AIF3TX2 Input 1 Volume" 38
  # BT headset mic -> apps:
  $T "AIF1TX1 Input 2 Volume" 38
  $T "AIF1TX2 Input 2 Volume" 38
  echo "BT call volume +6 dB, BT mic +6 dB" ;;
lastcrash)
  # Run right after an unexpected reboot: saves the previous boot's kernel log tail
  O=/data/local/tmp/lastcrash.txt
  for f in /sys/fs/pstore/* /proc/last_kmsg; do
    [ -f "$f" ] && { echo "== $f"; tail -120 "$f"; }
  done > $O 2>&1
  sync; cp $O /sdcard/lastcrash.txt; sync
  echo "saved /sdcard/lastcrash.txt ($(wc -l < $O) lines)" ;;
bt-test)
  # Run DURING a Bluetooth call, and keep talking into the Jabra for ~8 s.
  # v5: does NOT read /proc/asound/.../status (that crashed the kernel).
  O=/data/local/tmp/bt_test.txt
  : > $O
  step() { echo "== $1" >> $O; sh -c "$2" >> $O 2>&1; echo >> $O; sync; }
  # which audio devices are open (just lists file handles, no driver calls)
  step "open audio devices (D0=main, D2=Bluetooth link)" \
       "ls -l /proc/[0-9]*/fd 2>/dev/null | grep -o '/dev/snd/pcm.*' | sort | uniq -c"
  step "tools" "command -v tinycap tinyplay"
  # try to record straight from the Bluetooth link of the audio chip
  if command -v tinycap >/dev/null 2>&1; then
    rm -f /data/local/tmp/bt_mic.wav
    tinycap /data/local/tmp/bt_mic.wav -D 0 -d 2 -c 1 -r 8000 -b 16 >> $O 2>&1 &
    P=$!
    sleep 8
    kill -INT $P 2>/dev/null; sleep 1
    step "recording" "ls -l /data/local/tmp/bt_mic.wav"
    cp /data/local/tmp/bt_mic.wav /sdcard/bt_mic.wav 2>/dev/null
  fi
  step "done" "true"
  cp $O /sdcard/bt_test.txt; sync
  echo "saved /sdcard/bt_test.txt and /sdcard/bt_mic.wav" ;;
bt-off)
  $T "AIF3TX1 Input 1 Volume" 32
  $T "AIF3TX2 Input 1 Volume" 32
  $T "AIF1TX1 Input 2 Volume" 32
  $T "AIF1TX2 Input 2 Volume" 32
  echo "BT back to 0 dB" ;;
*)
  sed -n '2,16p' "$0" ;;
esac
