#!/usr/bin/env python3
"""Compare two ARM zImages (or a boot.img and a zImage) after decompressing the kernel payload.

Old Samsung drivers embed __DATE__/__TIME__, so two builds of identical source never match
byte-for-byte. This masks date ("Mmm dd yyyy") and time ("hh:mm:ss") strings and reports what is
left. Usage: kernel-compare.py <a> <b>     (a/b: zImage, or boot.img -> kernel taken from it)
"""
import lzma, re, struct, sys, zlib

def zimage(path):
    d = open(path, 'rb').read()
    if d[:8] == b'ANDROID!':
        ks = struct.unpack_from('<I', d, 8)[0]
        ps = struct.unpack_from('<I', d, 36)[0]
        d = d[ps:ps + ks]
    return d

def image(z):
    # chagallwifi uses CONFIG_KERNEL_LZMA (payload starts with props 0x5d 00 00); gzip as fallback
    for m in re.finditer(rb'\x5d\x00\x00', z):
        try:
            out = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(z[m.start():])
            if len(out) > 1 << 20:
                return out
        except lzma.LZMAError:
            pass
    i = z.find(b'\x1f\x8b\x08')
    if i >= 0:
        return zlib.decompressobj(31).decompress(z[i:])
    sys.exit('no LZMA/gzip kernel payload found')

DATE = re.compile(rb'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ 0-9]\d \d{4}')
TIME = re.compile(rb'[0-2]\d:[0-5]\d:[0-5]\d')
def mask(b):
    return TIME.sub(b'??:??:??', DATE.sub(b'??? ?? ????', b))

a, b = (image(zimage(p)) for p in sys.argv[1:3])
print(f'decompressed: {len(a)} vs {len(b)} bytes')
if len(a) != len(b):
    print('DIFFERENT size -> different source/config'); sys.exit(1)
raw = sum(x != y for x, y in zip(a, b))
ma, mb = mask(a), mask(b)
left = [i for i, (x, y) in enumerate(zip(ma, mb)) if x != y]
print(f'differing bytes: {raw} raw, {len(left)} after masking date/time strings')
for i in left[:10]:
    print(f'  @{i:#x}: {a[max(0,i-16):i+16]!r}\n        {b[max(0,i-16):i+16]!r}')
sys.exit(0 if not left else 1)
