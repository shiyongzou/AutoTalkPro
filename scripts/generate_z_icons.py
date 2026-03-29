#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path('/Users/mac/Desktop/tg_ai_sales_desktop')
OUT = ROOT / 'build' / 'icon_designs'
OUT.mkdir(parents=True, exist_ok=True)


def pick_font(size: int):
    candidates = [
        '/System/Library/Fonts/SFNS.ttf',
        '/System/Library/Fonts/Supplemental/Avenir Next.ttc',
        '/System/Library/Fonts/Supplemental/Helvetica.ttc',
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ]
    for c in candidates:
        p = Path(c)
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size=size)
            except Exception:
                pass
    return ImageFont.load_default()


def rounded_mask(size, radius):
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return m


def gradient(size, top, bottom):
    img = Image.new('RGB', (size, size), top)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        color = (
            int(top[0] * (1 - t) + bottom[0] * t),
            int(top[1] * (1 - t) + bottom[1] * t),
            int(top[2] * (1 - t) + bottom[2] * t),
        )
        d.line([(0, y), (size, y)], fill=color)
    return img


def add_glow_text(base: Image.Image, text='Z', color=(130, 235, 255), font_size=620, y_offset=-30):
    size = base.size[0]
    font = pick_font(font_size)
    layer = Image.new('RGBA', base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) // 2
    y = (size - th) // 2 + y_offset

    # glow
    glow = Image.new('RGBA', base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.text((x, y), text, font=font, fill=(*color, 220))
    glow = glow.filter(ImageFilter.GaussianBlur(18))

    # core + stroke
    d.text((x, y), text, font=font, fill=(245, 252, 255, 255), stroke_width=6, stroke_fill=(80, 190, 240, 255))

    merged = Image.alpha_composite(base.convert('RGBA'), glow)
    merged = Image.alpha_composite(merged, layer)
    return merged


def variant1(size=1024):
    bg = gradient(size, (8, 16, 44), (24, 96, 180))
    d = ImageDraw.Draw(bg)
    # subtle vertical beams
    for i in range(8):
        x = 80 + i * 120
        d.rectangle((x, 0, x + 40, size), fill=(35, 140, 255, 18))
    img = add_glow_text(bg, text='Z', color=(86, 226, 255), font_size=640, y_offset=-20)
    return img


def variant2(size=1024):
    bg = gradient(size, (12, 22, 36), (16, 150, 140))
    d = ImageDraw.Draw(bg)
    # circuit points
    for p in [(180, 200), (820, 180), (220, 820), (780, 760), (520, 140), (520, 900)]:
        d.ellipse((p[0]-8, p[1]-8, p[0]+8, p[1]+8), fill=(120, 255, 230))
    d.line((180, 200, 520, 140), fill=(120, 255, 230, 180), width=4)
    d.line((820, 180, 520, 140), fill=(120, 255, 230, 180), width=4)
    d.line((220, 820, 520, 900), fill=(120, 255, 230, 180), width=4)
    d.line((780, 760, 520, 900), fill=(120, 255, 230, 180), width=4)
    img = add_glow_text(bg, text='Z', color=(120, 255, 235), font_size=620, y_offset=-20)
    return img


def variant3(size=1024):
    bg = gradient(size, (25, 10, 48), (92, 26, 112))
    d = ImageDraw.Draw(bg)
    # neon ring
    d.ellipse((120, 120, 904, 904), outline=(160, 120, 255), width=10)
    d.ellipse((200, 200, 824, 824), outline=(110, 220, 255), width=6)
    img = add_glow_text(bg, text='Z', color=(180, 170, 255), font_size=620, y_offset=-20)
    return img


def finalize(img: Image.Image, name: str):
    mask = rounded_mask(img.size[0], int(img.size[0] * 0.23))
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    path = OUT / name
    out.save(path)
    return path


def main():
    v1 = finalize(variant1(), 'desktop_icon_z_v1_1024.png')
    v2 = finalize(variant2(), 'desktop_icon_z_v2_1024.png')
    v3 = finalize(variant3(), 'desktop_icon_z_v3_1024.png')
    print(v1)
    print(v2)
    print(v3)


if __name__ == '__main__':
    main()
