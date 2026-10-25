"""Draws the Gumption icon and writes every size each platform needs.

A four-point star with curved sides on a night-sky radial: the star you
light when you start something. The design is docs/DECISIONS.md's 1.1
handoff (design/icon/*.svg); the shapes and colours here match it.
Run from app/:  python3 tool/make_icons.py   (needs Pillow and numpy)
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # draw big, scale down for smooth edges
K = S / 1024  # the handoff's SVGs are 1024 units across

STAR = (0xF4, 0xC7, 0x6A)
SKY_IN, SKY_OUT = (0x1E, 0x2A, 0x52), (0x0A, 0x0F, 0x1F)  # default

# The star: four cubic curves in the SVG's 1024 space, 52% of the width.
CURVES = [
    ((512, 246), (534, 438), (586, 490), (778, 512)),
    ((778, 512), (586, 534), (534, 586), (512, 778)),
    ((512, 778), (490, 586), (438, 534), (246, 512)),
    ((246, 512), (438, 490), (490, 438), (512, 246)),
]


def star_mask(scale: float = 1.0) -> Image.Image:
    """The star as an L mask, centred, `scale` times the handoff's size."""
    pts = []
    for p0, p1, p2, p3 in CURVES:
        for i in range(400):
            t = i / 400
            u = 1 - t
            x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
            y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
            pts.append((S / 2 + (x - 512) * K * scale, S / 2 + (y - 512) * K * scale))
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def radial(inner, outer) -> Image.Image:
    """SVG radialGradient cx=50% cy=30% r=90% on a square."""
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((xx - 0.5 * S) ** 2 + (yy - 0.3 * S) ** 2) / (0.9 * S)
    t = np.clip(d, 0, 1)[..., None]
    rgb = np.array(inner, np.float32) * (1 - t) + np.array(outer, np.float32) * t
    return Image.fromarray(rgb.round().astype(np.uint8), "RGB").convert("RGBA")


def lit_star(canvas: Image.Image, mask: Image.Image, color, glow: float):
    """The star with its glow: a 36-unit Gaussian blur at `glow` opacity
    under the shape (feGaussianBlur + feFuncA slope)."""
    if glow > 0:
        halo = Image.new("RGBA", (S, S), color + (0,))
        halo.putalpha(mask.filter(ImageFilter.GaussianBlur(36 * K)).point(lambda v: int(v * glow)))
        canvas.alpha_composite(halo)
    canvas.paste(Image.new("RGBA", (S, S), color + (255,)), (0, 0), mask)
    return canvas


def icon(bg=(SKY_IN, SKY_OUT), color=STAR, glow=0.8, scale=1.0):
    canvas = radial(*bg) if bg else Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return lit_star(canvas, star_mask(scale), color, glow)


def rounded(img: Image.Image, margin: float = 0.0, radius: float = 0.225):
    """`img` as a rounded square inside a transparent margin (web, Mac,
    legacy Android): those platforms don't round the corners themselves."""
    side = round(S * (1 - 2 * margin))
    shape = Image.new("L", (side, side), 0)
    ImageDraw.Draw(shape).rounded_rectangle((0, 0, side - 1, side - 1), radius=int(side * radius), fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = (S - side) // 2
    out.paste(img.resize((side, side), Image.LANCZOS), (m, m), shape)
    return out


def save(img, size, path, flatten=None):
    out = img.resize((size, size), Image.LANCZOS)
    if flatten:  # opaque: iOS and the stores reject or blacken transparency
        bg = Image.new("RGB", out.size, flatten)
        bg.paste(out, (0, 0), out)
        out = bg
    out.save(path)


default = icon()
dark = icon(bg=((0, 0, 0), (0, 0, 0)), glow=0.6)
tinted = icon(bg=None, color=(0xD9, 0xD9, 0xD9), glow=0)

# Web: rounded for browsers, full-bleed for maskable (the OS crops the
# middle 80%, which the star sits well inside).
for n in (192, 512):
    save(rounded(default), n, f"web/icons/Icon-{n}.png")
    save(default, n, f"web/icons/Icon-maskable-{n}.png")
save(default, 180, "web/icons/apple-touch-icon.png", flatten=SKY_OUT)
save(rounded(default), 64, "web/favicon.png")

mac = rounded(default, margin=0.098)  # macOS icons sit inside a margin
for n in (16, 32, 64, 128, 256, 512, 1024):
    save(mac, n, f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{n}.png")

# iPhone/iPad: one 1024 image per appearance (Contents.json lists them);
# iOS scales and rounds them itself. Default and dark are opaque; tinted
# keeps its transparency, as Apple's template expects.
ios_set = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
save(default, 1024, f"{ios_set}/Icon-App-1024.png", flatten=SKY_OUT)
save(dark, 1024, f"{ios_set}/Icon-App-1024-dark.png", flatten=(0, 0, 0))
save(tinted, 1024, f"{ios_set}/Icon-App-1024-tinted.png")

# Android: legacy square icons for old launchers, plus adaptive layers
# (108dp, of which the launcher shows the middle 72dp) for Android 8+.
legacy = rounded(default, margin=0.06)
adaptive_scale = 72 / 108  # same apparent star size as the iOS icon
fg = icon(bg=None, scale=adaptive_scale)
mono = icon(bg=None, color=(255, 255, 255), glow=0, scale=adaptive_scale)
res = "android/app/src/main/res"
for folder, n in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    save(legacy, n, f"{res}/mipmap-{folder}/ic_launcher.png")
    layer = round(n * 108 / 48)
    save(radial(SKY_IN, SKY_OUT), layer, f"{res}/mipmap-{folder}/ic_launcher_background.png")
    save(fg, layer, f"{res}/mipmap-{folder}/ic_launcher_foreground.png")
    save(mono, layer, f"{res}/mipmap-{folder}/ic_launcher_monochrome.png")

# Windows.
rounded(default).resize((256, 256), Image.LANCZOS).save(
    "windows/runner/resources/app_icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
)

# Store listing: Google Play wants a 512² opaque icon.
save(default, 512, "../docs/store/icon-512.png", flatten=SKY_OUT)
print("icons written")
