# Restart the BT gain sweep: stop a running one, reset gains to 0 dB, start /data/local/tmp/gainstep.sh
# (= bt_gain_sweep.sh pushed under that name) in the background. Run as root: su -c "sh restart.sh"
for p in $(pgrep -f 'sh /data/local/tmp/gainstep.sh'); do kill $p; done
tinymix "AIF1TX1 Input 2 Volume" 32; tinymix "AIF1TX2 Input 2 Volume" 32
rm -f /data/local/tmp/gainstep.log
nohup sh /data/local/tmp/gainstep.sh > /data/local/tmp/gainstep.log 2>&1 &
sleep 2
echo "running: $(pgrep -f 'sh /data/local/tmp/gainstep.sh' | wc -l)"
cat /data/local/tmp/gainstep.log
tinymix "AIF1TX1 Input 2 Volume"; tinymix "ASRC2L Input" | grep -o '>[A-Za-z0-9]*'
