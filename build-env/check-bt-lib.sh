#!/bin/bash
# Show which vnd config libbt was built from and fingerprint the result.
O=${TOP:-$HOME/lineage}/out/target/product/chagallwifi
cat "$(find "$O/obj/SHARED_LIBRARIES/libbt-vendor_intermediates" -name vnd_buildcfg.h | head -1)"
L=$O/system/vendor/lib/libbt-vendor.so
ls -l "$L"; md5sum "$L"
echo "hw_sco_config reachable at fw init (expect 'sco I2S/PCM config result'):"
strings "$L" | grep -E "I2SPCM config|sco I2S/PCM config result|SCO I2S interface change"
