# MeeVPN UI images: the big connect button (ring off / on with glow) and the
# padlock pictogram (on = leading colour, off = grey). Drawn 4x, scaled down.
# Usage: python3 ui-assets.py outdir
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys, os
out = sys.argv[1]
K = 4
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def ring(name, size, fill, edge, width, glow=None):
    S = size * K
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    pad = 30 * K
    if glow:
        g = Image.new('L', (S, S), 0)
        ImageDraw.Draw(g).ellipse([pad - 4*K, pad - 4*K, S - pad + 4*K, S - pad + 4*K], outline=255, width=16*K)
        g = g.filter(ImageFilter.GaussianBlur(14 * K)).point(lambda v: int(v * 0.75))
        img = Image.composite(Image.new('RGBA', (S, S), glow + (255,)), img, g)
    d = ImageDraw.Draw(img)
    d.ellipse([pad, pad, S - pad, S - pad], fill=fill + (255,), outline=edge + (255,), width=width * K)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(out, name))

def lock(name, size, colour):
    W = size * K
    m = Image.new('L', (W, W), 0); d = ImageDraw.Draw(m)
    bx0, by0, bx1, by1 = W*.10, W*.42, W*.90, W*.94
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=W*.09, fill=255)
    lw = int(W*.10); sw = W*.56; cx = W/2; top = W*.04
    d.arc([cx-sw/2, top, cx+sw/2, top+sw], 180, 360, fill=255, width=lw)
    d.rectangle([cx-sw/2, top+sw/2-1, cx-sw/2+lw, by0+K], fill=255)
    d.rectangle([cx+sw/2-lw, top+sw/2-1, cx+sw/2, by0+K], fill=255)
    d.text((cx, (by0+by1)/2 + W*.01), 'VPN', font=ImageFont.truetype(FONT, int(W*.29)), fill=0, anchor='mm')
    img = Image.new('RGBA', (W, W), colour + (0,))
    img.putalpha(m)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(out, name))

ring('ring-off.png', 300, (22, 22, 24), (95, 127, 69), 5)
ring('ring-on.png', 300, (30, 43, 20), (207, 236, 160), 6, glow=(120, 170, 100))
lock('lock-on.png', 110, (231, 255, 205))
lock('lock-off.png', 110, (130, 130, 130))
