#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import math

ROOT = Path('/Users/mac/Desktop/tg_ai_sales_desktop')
OUT_DIR = ROOT / 'build' / 'icon_designs'
MAC_ICONSET = ROOT / 'macos' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
WIN_ICO = ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico'


def gradient_bg(size: int, c1, c2):
    img = Image.new('RGB', (size, size), c1)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        r = int(c1[0] * (1 - t) + c2[0] * t)
        g = int(c1[1] * (1 - t) + c2[1] * t)
        b = int(c1[2] * (1 - t) + c2[2] * t)
        d.line([(0, y), (size, y)], fill=(r, g, b))
    return img


def add_grid(img: Image.Image, alpha=35, step=64):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = img.size
    for x in range(0, w, step):
        d.line([(x, 0), (x, h)], fill=(120, 200, 255, alpha), width=1)
    for y in range(0, h, step):
        d.line([(0, y), (w, y)], fill=(120, 200, 255, alpha), width=1)
    return Image.alpha_composite(img.convert('RGBA'), layer).convert('RGB')


def rounded_mask(size: int, radius: int):
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return m


def draw_variant1(size=1024):
    # Deep blue neon AI-chat glyph
    img = gradient_bg(size, (15, 26, 58), (9, 132, 227))
    img = add_grid(img, alpha=28, step=size // 18)
    d = ImageDraw.Draw(img)

    # soft glow circle
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = size // 2, size // 2
    for r, a in [(360, 80), (300, 60), (240, 40)]:
        gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(97, 218, 251, a))
    glow = glow.filter(ImageFilter.GaussianBlur(36))
    img = Image.alpha_composite(img.convert('RGBA'), glow).convert('RGB')

    # speech bubble
    d = ImageDraw.Draw(img)
    bw, bh = int(size * 0.58), int(size * 0.42)
    x1, y1 = (size - bw) // 2, int(size * 0.24)
    x2, y2 = x1 + bw, y1 + bh
    d.rounded_rectangle((x1, y1, x2, y2), radius=int(size * 0.09), fill=(236, 249, 255), outline=(120, 220, 255), width=8)
    tail = [(int(size * 0.42), y2 - 4), (int(size * 0.50), int(size * 0.77)), (int(size * 0.56), y2 - 4)]
    d.polygon(tail, fill=(236, 249, 255), outline=(120, 220, 255))

    # AI chip mark
    chip_w, chip_h = int(size * 0.30), int(size * 0.20)
    cx1, cy1 = int(size * 0.35), int(size * 0.34)
    cx2, cy2 = cx1 + chip_w, cy1 + chip_h
    d.rounded_rectangle((cx1, cy1, cx2, cy2), radius=28, fill=(18, 56, 96), outline=(87, 223, 255), width=6)
    d.text((int(size * 0.43), int(size * 0.385)), 'AI', fill=(152, 245, 255))

    # pins
    for i in range(6):
        px = cx1 + (i + 1) * chip_w // 7
        d.line((px, cy1 - 18, px, cy1 - 2), fill=(87, 223, 255), width=4)
        d.line((px, cy2 + 2, px, cy2 + 18), fill=(87, 223, 255), width=4)

    # rounded app icon shape
    mask = rounded_mask(size, int(size * 0.23))
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img.convert('RGBA'), (0, 0), mask)
    return out


def draw_variant2(size=1024):
    img = gradient_bg(size, (18, 20, 40), (40, 86, 180))
    img = add_grid(img, alpha=22, step=size // 16)
    d = ImageDraw.Draw(img)

    # central hex ring
    cx, cy = size // 2, size // 2
    for r, w in [(310, 16), (240, 10), (180, 6)]:
        pts = []
        for k in range(6):
            a = math.pi / 3 * k - math.pi / 6
            pts.append((cx + int(r * math.cos(a)), cy + int(r * math.sin(a))))
        d.polygon(pts, outline=(109, 237, 255), width=w)

    d.ellipse((cx - 130, cy - 130, cx + 130, cy + 130), fill=(228, 247, 255), outline=(89, 224, 255), width=8)
    d.text((cx - 42, cy - 35), 'A', fill=(23, 65, 120))
    d.text((cx + 8, cy - 35), 'I', fill=(23, 65, 120))

    mask = rounded_mask(size, int(size * 0.23))
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img.convert('RGBA'), (0, 0), mask)
    return out


def draw_variant3(size=1024):
    img = gradient_bg(size, (9, 33, 48), (17, 156, 173))
    d = ImageDraw.Draw(img)
    # neon diagonal streaks
    for i in range(-3, 9):
        x = i * size // 6
        d.polygon([(x, 0), (x + 120, 0), (x + size // 3, size), (x + size // 3 - 120, size)], fill=(30, 210, 255, 35))

    # message dots + orbit
    cx, cy = size // 2, size // 2
    d.ellipse((cx - 210, cy - 170, cx + 210, cy + 170), outline=(113, 249, 255), width=10)
    for dx in (-80, 0, 80):
        d.ellipse((cx + dx - 24, cy - 24, cx + dx + 24, cy + 24), fill=(232, 252, 255))

    mask = rounded_mask(size, int(size * 0.23))
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img.convert('RGBA'), (0, 0), mask)
    return out


def save_variants():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    variants = [draw_variant1(), draw_variant2(), draw_variant3()]
    paths = []
    for i, icon in enumerate(variants, start=1):
        pth = OUT_DIR / f'desktop_icon_v{i}_1024.png'
        icon.save(pth)
        paths.append(pth)
    return paths


def apply_to_flutter(icon_1024: Path):
    img = Image.open(icon_1024).convert('RGBA')
    MAC_ICONSET.mkdir(parents=True, exist_ok=True)

    # macOS appiconset files used by this project
    for s in [16, 32, 64, 128, 256, 512, 1024]:
        resized = img.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(MAC_ICONSET / f'app_icon_{s}.png')

    # windows ico (multi-resolution)
    img.save(WIN_ICO, format='ICO', sizes=[(16,16), (24,24), (32,32), (48,48), (64,64), (128,128), (256,256)])


def main():
    variants = save_variants()
    # default apply variant 1
    apply_to_flutter(variants[0])
    print('Generated variants:')
    for p in variants:
        print(f' - {p}')
    print('Applied to:')
    print(f' - {MAC_ICONSET}')
    print(f' - {WIN_ICO}')


if __name__ == '__main__':
    main()
