# Contact sheets, one per section (by file-name prefix), from capture.mjs's
# screenshots: python3 sheets.py <shots dir> <out dir>
import sys, os, re
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
F = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../app/assets/fonts/')
tf = ImageFont.truetype(F + 'Geist-SemiBold.ttf', 44); lf = ImageFont.truetype(F + 'Geist-Medium.ttf', 28)
SECTIONS = {'01': 'Today', '02': 'Starting and focus', '03': 'Quick add', '04': 'Tasks, weekly reset, errand run',
  '05': 'Task editor', '06': 'Notes', '07': 'Progress', '08': 'Settings and templates', '09': 'Wrap-up and guide',
  '10': 'Small phone (360x800)', '11': 'Mac / desktop (1440x900)'}
files = sorted(f[:-4] for f in os.listdir(src) if f.endswith('.png'))
def label(n): return re.sub(r'^\d+-', '', n).replace('-', ' ').capitalize()
for sec, title in SECTIONS.items():
  names = [n for n in files if n.startswith(sec + '-')]
  if not names: continue
  mac = sec == '11'
  per, cols = (6, 2) if mac else (8, 4)
  parts = [names[i:i + per] for i in range(0, len(names), per)]
  for pi, part in enumerate(parts):
    ims = [Image.open(f'{src}/{n}.png').convert('RGB') for n in part]
    W, H = (1440, 900) if mac else (780, 1688)
    ims = [im if im.size == (W, H) else im.resize((W, int(im.size[1] * W / im.size[0]))) for im in ims]
    H = max(im.size[1] for im in ims)
    PAD, TOP = 48, 140
    c = min(cols, len(ims)); rows = (len(ims) + c - 1) // c
    sheet = Image.new('RGB', (PAD + c * (W + PAD), TOP + rows * (H + 70 + PAD)), '#E9ECEB')
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 46), f'Current design: {title}' + (f' ({pi + 1} of {len(parts)})' if len(parts) > 1 else ''), font=tf, fill='#111')
    for i, (n, im) in enumerate(zip(part, ims)):
      x = PAD + (i % c) * (W + PAD); y = TOP + (i // c) * (H + 70 + PAD)
      d.text((x, y), label(n), font=lf, fill='#333')
      sheet.paste(im, (x, y + 50)); d.rectangle([x - 1, y + 49, x + im.size[0], y + 50 + im.size[1]], outline='#B8BDBB')
    name = f'{sec}-{title.split(" (")[0].lower().replace(",", "").replace(" / ", "-").replace(" ", "-")}' + (f'-{pi + 1}' if len(parts) > 1 else '')
    # Keep sheets a reasonable upload size.
    if sheet.size[0] > 3400: sheet = sheet.resize((3400, int(sheet.size[1] * 3400 / sheet.size[0])), Image.LANCZOS)
    sheet.save(f'{out}/{name}.png', optimize=True)
    print(name, sheet.size, len(part))
