"""Generates the settings-window nav icons (Media/ui/nav-*.tga): white glyphs on transparent, 64x64.

Original artwork drawn with Pillow primitives; run from the repo root: python3 tools/make_nav_icons.py
The addon tints them at runtime (muted when idle, dark on the selected accent bar).
"""
import math
import os

from PIL import Image, ImageDraw

SIZE = 64
SS = 8
OUT = os.path.join("Media", "ui")
W = (255, 255, 255, 255)


def canvas():
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def p(v):
    return v * SS


def finish(img, name):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(OUT, "nav-%s.tga" % name)
    img.save(path, format="TGA", rle=False)
    return path


def gear():
    img, d = canvas()
    cx = cy = 32
    teeth = 8
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        x, y = cx + math.cos(a) * 22, cy + math.sin(a) * 22
        pts = []
        for da, r in ((-0.22, 26), (0.22, 26), (0.22, 17), (-0.22, 17)):
            pts.append((p(cx + math.cos(a + da) * r), p(cy + math.sin(a + da) * r)))
        d.polygon(pts, fill=W)
        _ = x, y
    d.ellipse([p(cx - 19), p(cy - 19), p(cx + 19), p(cy + 19)], fill=W)
    d.ellipse([p(cx - 8), p(cy - 8), p(cx + 8), p(cy + 8)], fill=(255, 255, 255, 0))
    return finish(img, "general")


def sparkle():
    img, d = canvas()
    def star(cx, cy, r, w):
        pts = []
        for i in range(8):
            a = math.pi * i / 4 - math.pi / 2
            rr = r if i % 2 == 0 else r * w
            pts.append((p(cx + math.cos(a) * rr), p(cy + math.sin(a) * rr)))
        d.polygon(pts, fill=W)
    star(27, 30, 24, 0.22)
    star(49, 14, 10, 0.25)
    star(49, 50, 8, 0.25)
    return finish(img, "features")


def panel():
    img, d = canvas()
    d.rounded_rectangle([p(6), p(8), p(58), p(56)], radius=p(6), outline=W, width=p(4))
    d.rectangle([p(6), p(8), p(58), p(20)], fill=W)
    for i, w in enumerate((38, 30, 34)):
        y = 28 + i * 9
        d.rounded_rectangle([p(14), p(y), p(14 + w), p(y + 4)], radius=p(2), fill=W)
    return finish(img, "overlay")


def moon():
    img, d = canvas()
    d.ellipse([p(8), p(8), p(56), p(56)], fill=W)
    d.ellipse([p(24), p(2), p(66), p(44)], fill=(255, 255, 255, 0))
    for cx, cy, r in ((44, 40, 3), (52, 24, 2)):
        d.ellipse([p(cx - r), p(cy - r), p(cx + r), p(cy + r)], fill=W)
    return finish(img, "afk")


def unit_frame():
    img, d = canvas()
    d.rounded_rectangle([p(4), p(14), p(60), p(50)], radius=p(5), outline=W, width=p(4))
    d.ellipse([p(10), p(20), p(28), p(38)], fill=W)
    d.rounded_rectangle([p(33), p(22), p(54), p(28)], radius=p(2), fill=W)
    d.rounded_rectangle([p(33), p(33), p(48), p(38)], radius=p(2), fill=W)
    return finish(img, "reveal")


def pin():
    img, d = canvas()
    cx, cy, r = 32, 25, 18
    d.ellipse([p(cx - r), p(cy - r), p(cx + r), p(cy + r)], fill=W)
    d.polygon([(p(cx - 15), p(cy + 10)), (p(cx + 15), p(cy + 10)), (p(cx), p(58))], fill=W)
    d.ellipse([p(cx - 7), p(cy - 7), p(cx + 7), p(cy + 7)], fill=(255, 255, 255, 0))
    return finish(img, "zonetext")


def fonts():
    img, d = canvas()
    # Large "A" with a crossbar and a small single-story "a" beside it.
    d.line([(p(8), p(54)), (p(22), p(10))], fill=W, width=p(8))
    d.line([(p(22), p(10)), (p(36), p(54))], fill=W, width=p(8))
    for cx, cy in ((8, 54), (36, 54), (22, 10)):
        d.ellipse([p(cx - 4), p(cy - 4), p(cx + 4), p(cy + 4)], fill=W)
    d.rectangle([p(14), p(38), p(30), p(44)], fill=W)
    d.ellipse([p(38), p(34), p(58), p(54)], outline=W, width=p(5))
    d.rectangle([p(53), p(34), p(58), p(54)], fill=W)
    return finish(img, "fonts")


def gradient():
    img, d = canvas()
    d.rounded_rectangle([p(4), p(14), p(60), p(50)], radius=p(5), outline=W, width=p(4))
    steps = 6
    for i in range(steps):
        x0 = 11 + i * 7.2
        a = int(70 + 185 * i / (steps - 1))
        d.rectangle([p(x0), p(21), p(x0 + 7.2), p(43)], fill=(255, 255, 255, a))
    return finish(img, "gradient")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (gear, sparkle, panel, moon, unit_frame, pin, fonts, gradient):
        print(fn())
