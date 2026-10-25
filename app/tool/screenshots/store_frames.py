"""App Store screenshots: a caption over a phone frame holding a real
screenshot, on Night or Dawn backgrounds that alternate through the set
(the 1.1 design's "App Store screenshots" board).

Shoot the raw screens first (from app/, web build served on 8765), at the
6.3-inch iPhone size with a fake status bar and home indicator:

  node tool/screenshots/shoot.mjs raw/ raw-today / 402 874 --scale 3 --iphone --top 62
  ... started (tap Start), smaller (light, tap Smaller), focus, progress

then:  python3 tool/screenshots/store_frames.py raw/ out/   (needs Pillow)

Writes out/iphone-N-name.png at 1206x2622: App Store Connect (Oct 2026)
requires the 6.3-inch set and rejected 1290x2796 (docs/store/LISTING.md).

iPad (13-inch, landscape, so the sidebar and the Tasks detail pane show):
shoot raw/ipad-raw-{today,tasks,progress}.png at 1366 1024 --scale 2
--iphone --top 24; they come out as out/ipad-N-name.png at 2732x2048.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 1206, 2622
F = W / 1290  # the layout was drawn at 1290 wide
FONT = "assets/fonts/Sora-Bold.ttf"
UI = "assets/fonts/Manrope-SemiBold.ttf"

NIGHT = dict(top=(0x1E, 0x2A, 0x52), bottom=(0x0A, 0x0F, 0x1F), ink=(0xEE, 0xF0, 0xF8))
DAWN = dict(top=(0xFB, 0xE2, 0xC6), bottom=(0xF7, 0xF1, 0xE8), ink=(0x19, 0x20, 0x3A))

# (raw screenshot, caption, background, the screen's own status-bar ink)
FRAMES = [
    ("today", "Don’t decide.\nJust start.", NIGHT, "light"),
    ("started", "Starting lights\na star.", DAWN, "light"),
    ("smaller", "Shrink it until\nit’s easy.", NIGHT, "dark"),
    ("focus", "A timer that\nkeeps you company.", DAWN, "light"),
    ("progress", "Every start,\nwritten in your sky.", NIGHT, "light"),
]

IPAD_W, IPAD_H = 2732, 2048
IPAD_FRAMES = [
    ("today", "Don\u2019t decide. Just start.", NIGHT),
    ("tasks", "Every step, right beside the list.", DAWN),
    ("progress", "Every start, written in your sky.", NIGHT),
]


def background(theme, w=W, h=H):
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = min(1, y / (h * 0.7))
        img.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(theme["top"], theme["bottom"])))
    return img.resize((w, h))


def status_bar(screen, ink):
    """9:41, the Dynamic Island and a battery, drawn over the raw screen's
    empty status-bar inset (62pt at 3x)."""
    d = ImageDraw.Draw(screen)
    sw = screen.width
    k = sw / 1290
    color = (255, 255, 255) if ink == "light" else (0x19, 0x20, 0x3A)
    font = ImageFont.truetype(UI, round(51 * k))
    d.text((round(150 * k), round(95 * k)), "9:41", font=font, fill=color, anchor="mm")
    iw, ih = round(378 * k), round(111 * k)
    d.rounded_rectangle(((sw - iw) // 2, round(33 * k), (sw + iw) // 2, round(33 * k) + ih), radius=ih // 2, fill=(0, 0, 0))
    bx, by, bw, bh = round(1100 * k), round(78 * k), round(80 * k), round(38 * k)
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=round(11 * k), outline=color, width=max(2, round(4 * k)))
    d.rounded_rectangle((bx + round(8 * k), by + round(8 * k), bx + bw - round(22 * k), by + bh - round(8 * k)), radius=round(5 * k), fill=color)
    d.rounded_rectangle((bx + bw + round(4 * k), by + round(12 * k), bx + bw + round(9 * k), by + bh - round(12 * k)), radius=2, fill=color)
    return screen


def phone(screen_img, ink):
    """The screenshot inside a dark bezel with rounded corners."""
    sw = round(962 * F)
    sh = round(sw * screen_img.height / screen_img.width)
    bezel = round(22 * F)
    screen = status_bar(screen_img.convert("RGB"), ink).resize((sw, sh), Image.LANCZOS)
    body = Image.new("RGBA", (sw + 2 * bezel, sh + 2 * bezel), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, body.width - 1, body.height - 1), radius=round(150 * F), fill=(0x05, 0x07, 0x10, 255))
    d.rounded_rectangle((3, 3, body.width - 4, body.height - 4), radius=round(147 * F), outline=(0x3A, 0x42, 0x60, 255), width=3)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=round(128 * F), fill=255)
    body.paste(screen, (bezel, bezel), mask)
    return body


def frame(raw, caption, theme, ink):
    out = background(theme).convert("RGBA")
    d = ImageDraw.Draw(out)
    font = ImageFont.truetype(FONT, round(112 * F))
    d.multiline_text((W // 2, round(300 * F)), caption, font=font, fill=theme["ink"], anchor="mm", align="center", spacing=6)
    body = phone(raw, ink)
    out.alpha_composite(body, ((W - body.width) // 2, round(520 * F)))
    return out.convert("RGB")


def ipad_frame(raw, caption, theme):
    """Landscape: a one-line caption over an iPad with a slim bezel. The
    iPad's status bar is just the time and the battery."""
    out = background(theme, IPAD_W, IPAD_H).convert("RGBA")
    d = ImageDraw.Draw(out)
    d.text((IPAD_W // 2, 190), caption, font=ImageFont.truetype(FONT, 118), fill=theme["ink"], anchor="mm")
    screen = raw.convert("RGB")
    sd = ImageDraw.Draw(screen)
    ui = ImageFont.truetype(UI, 30)
    sd.text((48, 24), "9:41", font=ui, fill=(0xEE, 0xF0, 0xF8), anchor="lm")
    bx, by = screen.width - 96, 12
    sd.rounded_rectangle((bx, by, bx + 48, by + 24), radius=7, outline=(0xEE, 0xF0, 0xF8), width=3)
    sd.rounded_rectangle((bx + 5, by + 5, bx + 36, by + 19), radius=3, fill=(0xEE, 0xF0, 0xF8))
    sw = 2224
    sh = round(sw * screen.height / screen.width)
    bezel = 30
    screen = screen.resize((sw, sh), Image.LANCZOS)
    body = Image.new("RGBA", (sw + 2 * bezel, sh + 2 * bezel), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle((0, 0, body.width - 1, body.height - 1), radius=84, fill=(0x05, 0x07, 0x10, 255))
    bd.rounded_rectangle((3, 3, body.width - 4, body.height - 4), radius=81, outline=(0x3A, 0x42, 0x60, 255), width=3)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=56, fill=255)
    body.paste(screen, (bezel, bezel), mask)
    out.alpha_composite(body, ((IPAD_W - body.width) // 2, 320))
    return out.convert("RGB")


def main(src, dst):
    for i, (name, caption, theme, ink) in enumerate(FRAMES, 1):
        raw = Image.open(f"{src}/raw-{name}.png")
        frame(raw, caption, theme, ink).save(f"{dst}/iphone-{i}-{name}.png")
    for i, (name, caption, theme) in enumerate(IPAD_FRAMES, 1):
        try:
            raw = Image.open(f"{src}/ipad-raw-{name}.png")
        except FileNotFoundError:
            continue
        ipad_frame(raw, caption, theme).save(f"{dst}/ipad-{i}-{name}.png")
    print("frames written")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
