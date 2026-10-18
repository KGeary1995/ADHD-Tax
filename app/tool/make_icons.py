"""Draws the ADHD Tax icon and writes every size each platform needs.

A timer ring (time blindness) around a "start" triangle (the whole point:
starting). Run from app/:  python3 tool/make_icons.py   (needs Pillow)
"""
from PIL import Image, ImageDraw

S = 4096  # draw big, scale down for smooth edges
BG_TOP, BG_BOTTOM = (31, 38, 66), (13, 15, 24)
ACCENT, ACCENT2 = (124, 156, 255), (177, 140, 255)


def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        img.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img.resize((size, size))


def art(full_bleed: bool, margin: float = 0.0, radius: float = 0.225):
    """The icon on a transparent canvas. full_bleed: square background to the
    edges (iOS and maskable icons, which the OS crops itself)."""
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = int(S * margin)
    box = (m, m, S - m, S - m)
    side = S - 2 * m
    bg = gradient(side, BG_TOP, BG_BOTTOM).convert("RGBA")
    mask = Image.new("L", (side, side), 0)
    md = ImageDraw.Draw(mask)
    if full_bleed:
        md.rectangle((0, 0, side, side), fill=255)
    else:
        md.rounded_rectangle((0, 0, side - 1, side - 1), radius=int(side * radius), fill=255)
    canvas.paste(bg, box[:2], mask)

    d = ImageDraw.Draw(canvas)
    c = S / 2
    # Content shrinks for full-bleed icons so it stays inside OS crop zones.
    r = side * (0.30 if full_bleed else 0.34)
    w = int(side * 0.065)
    ring = (c - r, c - r, c + r, c + r)
    d.arc(ring, 0, 360, fill=(48, 56, 88, 255), width=w)  # track
    d.arc(ring, -90, 180, fill=ACCENT + (255,), width=w)            # time left
    # Round caps on the arc ends.
    import math
    for ang in (-90, 180):
        a = math.radians(ang)
        x, y = c + (r - w / 2) * math.cos(a), c + (r - w / 2) * math.sin(a)
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=ACCENT + (255,))

    # Play triangle with a soft vertical gradient, nudged right to look centred.
    t = r * 0.62
    tri = Image.new("L", (S, S), 0)
    ImageDraw.Draw(tri).polygon(
        [(c - t * 0.42, c - t * 0.62), (c - t * 0.42, c + t * 0.62), (c + t * 0.70, c)],
        fill=255,
    )
    fill = gradient(S, ACCENT2, ACCENT).convert("RGBA")
    canvas.paste(fill, (0, 0), tri)
    return canvas


def save(img, size, path, flatten=False):
    out = img.resize((size, size), Image.LANCZOS)
    if flatten:  # iOS shows transparency as black; make it explicit
        bg = Image.new("RGB", out.size, BG_BOTTOM)
        bg.paste(out, (0, 0), out)
        out = bg
    out.save(path)


rounded = art(False, margin=0.0)
mac = art(False, margin=0.098, radius=0.225)  # macOS icons sit inside a margin
bleed = art(True)

for n in (192, 512):
    save(rounded, n, f"web/icons/Icon-{n}.png")
    save(bleed, n, f"web/icons/Icon-maskable-{n}.png")
save(bleed, 180, "web/icons/apple-touch-icon.png", flatten=True)
save(rounded, 64, "web/favicon.png")

for n in (16, 32, 64, 128, 256, 512, 1024):
    save(mac, n, f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{n}.png")

for folder, n in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    save(art(False, margin=0.06), n, f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")
print("icons written")
