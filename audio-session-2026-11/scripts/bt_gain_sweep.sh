# BT SCO gain sweep. Uplink  : AIF3RX -> ASRC2 -> AIF1TX1/2 Input 2 Volume
#                    Downlink: AIF1RX -> ASRC1 -> AIF3TX1/2 Input 1 Volume   (32 = 0 dB, 48 = +16 dB)
# Waits for the BT mic path (ASRC2L Input = AIF3RX1); 30 s per step; restores 32 at the end.
up()   { tinymix "AIF1TX1 Input 2 Volume" $1; tinymix "AIF1TX2 Input 2 Volume" $1; }
down() { tinymix "AIF3TX1 Input 1 Volume" $1; tinymix "AIF3TX2 Input 1 Volume" $1; }
active() { tinymix "ASRC2L Input" | grep -q '>AIF3RX1'; }
log() { echo "$(date +%T) $*"; }
restore() { up 32; down 32; log "restored 0 dB"; }
hold() { i=0; while [ $i -lt 30 ]; do sleep 1; i=$((i+1)); active || { log "call ended"; restore; exit 0; }; done; }
log "waiting for BT call mic (up to 15 min)"
n=0; until active; do sleep 1; n=$((n+1)); [ $n -gt 900 ] && { log "timeout"; exit 1; }; done
log "BT mic active"
for g in 32 38 42 46 48; do up $g; log "UPLINK $((g-32)) dB"; hold; done
up 32
for g in 32 38 42 46 48; do down $g; log "DOWNLINK $((g-32)) dB"; hold; done
restore
while active; do sleep 1; done
log "call ended"
