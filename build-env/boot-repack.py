#!/usr/bin/env python3
"""Replace the kernel in a (Magisk-patched) Android v0 boot image, keep everything else.

  boot-repack.py <old boot.img> <new zImage> <out boot.img>

Keeps header addresses, page size, cmdline, ramdisk (Magisk) and the Samsung "SEANDROIDENFORCE"
footer; recomputes kernel size and the SHA-1 id exactly like mkbootimg (verified against the input
image before writing).
"""
import hashlib, struct, sys

old, zimage, out = sys.argv[1:4]
d = open(old, 'rb').read()
assert d[:8] == b'ANDROID!', 'not an Android boot image'
ks, ka, rs, ra, ss, sa, ta, ps = struct.unpack_from('<8I', d, 8)
pg = lambda n: (n + ps - 1) // ps * ps
kern = d[ps:ps + ks]
rd = d[ps + pg(ks):ps + pg(ks) + rs]
sec = d[ps + pg(ks) + pg(rs):ps + pg(ks) + pg(rs) + ss]
end = ps + pg(ks) + pg(rs) + pg(ss)

def img_id(k, r, s):
    h = hashlib.sha1()
    for blob in (k, r, s):
        h.update(blob); h.update(struct.pack('<I', len(blob)))
    return h.digest()

assert d[576:596] == img_id(kern, rd, sec), 'id check failed: unknown image variant'
footer = b'SEANDROIDENFORCE' if d[end:end + 16] == b'SEANDROIDENFORCE' else b''

nk = open(zimage, 'rb').read()
hdr = bytearray(d[:ps])
struct.pack_into('<I', hdr, 8, len(nk))
hdr[576:608] = img_id(nk, rd, sec).ljust(32, b'\0')
pad = lambda b: b + b'\0' * (pg(len(b)) - len(b))
img = bytes(hdr) + pad(nk) + pad(rd) + (pad(sec) if ss else b'') + footer
open(out, 'wb').write(img)
print(f'{out}: kernel {ks} -> {len(nk)} bytes, ramdisk {rs} kept, footer {"yes" if footer else "no"}, '
      f'total {len(img)} bytes')
