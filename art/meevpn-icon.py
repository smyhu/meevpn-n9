# MeeVPN icon: padlock with "VPN" cut out of the body (design by smyhu),
# project style: dark N9 background with gloss arc, pictogram 231,255,205, soft glow.
# Usage: python3 meevpn-icon.py background80.png n9mask80.png outdir
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys, os
K = 8; W = 80 * K
LIGHT = (231, 255, 205); GLOW = (120, 170, 100)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
base = Image.open(sys.argv[1]).convert('RGBA'); mask = Image.open(sys.argv[2]).convert('L'); out = sys.argv[3]

def pictogram(sx):
    m = Image.new('L', (W, W), 0); d = ImageDraw.Draw(m)
    # body
    bx0, by0, bx1, by1 = W*.18, W*.42, W*.82, W*.84
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=K*7, fill=255)
    # shackle
    lw = int(W*.085); sw = W*sx
    cx = W/2; top = W*.14
    d.arc([cx-sw/2, top, cx+sw/2, top+sw], 180, 360, fill=255, width=lw)
    d.rectangle([cx-sw/2, top+sw/2-1, cx-sw/2+lw, by0+K], fill=255)
    d.rectangle([cx+sw/2-lw, top+sw/2-1, cx+sw/2, by0+K], fill=255)
    # text cut out
    f = ImageFont.truetype(FONT, int(W*.235))
    d.text((cx, (by0+by1)/2 + K*0.5), 'VPN', font=f, fill=0, anchor='mm')
    return m

def make(sx):
    img = base.resize((W, W), Image.BICUBIC)
    m = pictogram(sx)
    g = m.filter(ImageFilter.GaussianBlur(K*1.6)).point(lambda v: int(v*.55))
    img = Image.composite(Image.new('RGBA', (W, W), GLOW+(255,)), img, g)
    img = Image.composite(Image.new('RGBA', (W, W), LIGHT+(255,)), img, m)
    s = img.resize((80, 80), Image.LANCZOS); s.putalpha(mask); return s

icon = make(0.46)
icon.save(os.path.join(out, 'meevpn80.png'))
for sz in (64, 48, 32):
    icon.resize((sz, sz), Image.LANCZOS).save(os.path.join(out, 'meevpn%d.png' % sz))
sheet = Image.new('RGBA', (320, 220), (0, 0, 0, 255))
sheet.alpha_composite(icon.resize((180, 180), Image.LANCZOS), (20, 20))
sheet.alpha_composite(icon, (220, 120))
sheet.save(os.path.join(out, 'meevpn-icon-preview.png'))
