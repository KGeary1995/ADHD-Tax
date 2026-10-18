"""Draws the Unstuck icon and writes every size each platform needs.

A tangled loop that straightens into an arrow: stuck, then moving. Teal on
deep teal. Run from app/:  python3 tool/make_icons.py   (needs Pillow)
"""
import math

from PIL import Image, ImageDraw, ImageFilter

S = 4096  # draw big, scale down for smooth edges
BG_TOP, BG_BOTTOM = (18, 52, 64), (8, 18, 26)
STROKE_TOP, STROKE_BOTTOM = (140, 255, 210), (60, 200, 230)
GLOW = (90, 240, 200)


def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        img.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img.resize((size, size))


def mark(scale: float) -> Image.Image:
    """The tangle → arrow stroke as a mask, centred, `scale` of full size."""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    w = S * 0.075 * scale

    def at(x, y):  # design coordinates (0..1) → canvas, scaled about centre
        return (S / 2 + (x - 0.5) * S * scale, S / 2 + (y - 0.5) * S * scale)

    # One cursive loop on the left, then a straight run up and to the right.
    pts = []
    for i in range(3001):
        t = i / 3000
        if t < 0.62:
            u = t / 0.62 * 2 * math.pi
            x = 0.26 + 0.13 * math.sin(u) + 0.22 * (t / 0.62)
            y = 0.58 - 0.16 * (1 - math.cos(u)) * 0.9
        else:
            v = (t - 0.62) / 0.38
            x = 0.48 + (0.80 - 0.48) * v
            y = 0.58 + (0.34 - 0.58) * v
        pts.append(at(x, y))

    def dot(x, y):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)

    for p in pts:  # round brush stamps: smooth stroke, round joins and caps
        dot(*p)
    ex, ey = pts[-1]
    px, py = pts[-120]
    ang = math.atan2(ey - py, ex - px)
    head = S * 0.15 * scale
    for sgn in (1, -1):
        bx = ex - head * math.cos(ang + sgn * 0.62)
        by = ey - head * math.sin(ang + sgn * 0.62)
        steps = 200
        for k in range(steps + 1):
            dot(ex + (bx - ex) * k / steps, ey + (by - ey) * k / steps)
    # Centre the drawing and size it to 68% of the width (of the scaled
    # area), measured from its actual pixels rather than guessed.
    left, top, right, bottom = m.getbbox()
    k = (S * 0.68 * scale) / (right - left)
    cx, cy = (left + right) / 2, (top + bottom) / 2
    # Output pixel (x, y) samples input (cx + (x - S/2)/k, cy + (y - S/2)/k).
    return m.transform(
        m.size,
        Image.AFFINE,
        (1 / k, 0, cx - S / 2 / k, 0, 1 / k, cy - S / 2 / k),
        resample=Image.BICUBIC,
    )


def art(full_bleed: bool, margin: float = 0.0, radius: float = 0.225):
    """Icon on a transparent canvas. full_bleed: square background to the
    edges (iOS and maskable icons, which the OS crops itself)."""
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = int(S * margin)
    side = S - 2 * m
    bg = gradient(side, BG_TOP, BG_BOTTOM).convert("RGBA")
    shape = Image.new("L", (side, side), 0)
    sd = ImageDraw.Draw(shape)
    if full_bleed:
        sd.rectangle((0, 0, side, side), fill=255)
    else:
        sd.rounded_rectangle((0, 0, side - 1, side - 1), radius=int(side * radius), fill=255)
    canvas.paste(bg, (m, m), shape)

    # Full-bleed icons get cropped (maskable safe zone is the middle 80%).
    stroke = mark((side / S) * (0.80 if full_bleed else 1.0))
    halo = Image.new("RGBA", (S, S), GLOW + (0,))
    halo.putalpha(stroke.filter(ImageFilter.GaussianBlur(S * 0.025)).point(lambda v: int(v * 0.55)))
    canvas.alpha_composite(halo)
    canvas.paste(gradient(S, STROKE_TOP, STROKE_BOTTOM).convert("RGBA"), (0, 0), stroke)
    return canvas


def save(img, size, path, flatten=False):
    out = img.resize((size, size), Image.LANCZOS)
    if flatten:  # iOS shows transparency as black; make it explicit
        bg = Image.new("RGB", out.size, BG_BOTTOM)
        bg.paste(out, (0, 0), out)
        out = bg
    out.save(path)


rounded = art(False)
mac = art(False, margin=0.098)  # macOS icons sit inside a margin
bleed = art(True)

for n in (192, 512):
    save(rounded, n, f"web/icons/Icon-{n}.png")
    save(bleed, n, f"web/icons/Icon-maskable-{n}.png")
save(bleed, 180, "web/icons/apple-touch-icon.png", flatten=True)
save(rounded, 64, "web/favicon.png")

for n in (16, 32, 64, 128, 256, 512, 1024):
    save(mac, n, f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{n}.png")

# iPhone/iPad: full-bleed and opaque (the App Store rejects transparency);
# iOS rounds the corners itself.
ios_set = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for size, scale in (
    (20, 1), (20, 2), (20, 3), (29, 1), (29, 2), (29, 3), (40, 1), (40, 2),
    (40, 3), (60, 2), (60, 3), (76, 1), (76, 2), (83.5, 2), (1024, 1),
):
    label = f"{size:g}x{size:g}"
    save(bleed, round(size * scale), f"{ios_set}/Icon-App-{label}@{scale}x.png", flatten=True)

android = art(False, margin=0.06)
for folder, n in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    save(android, n, f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")
print("icons written")
