#!/usr/bin/env python3
"""
يولّد أيقونة التطبيق (فقاعة محادثة جواها 3 أجهزة متوصلة = شبكة Mesh).

    python3 tool/generate_icon.py

بيكتب:
  • android/app/src/main/res/drawable-*/ic_launcher_{background,foreground,monochrome}.png
  • android/app/src/main/res/mipmap-*/ic_launcher.png   (أندرويد 7 القديم)
  • tool/icon_preview.png

لازم Pillow:  pip install pillow
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
S = 1024  # الرسم بدقة عالية وبعدين بنصغّر

TOP = (99, 102, 241)  # #6366F1
BOTTOM = (124, 58, 237)  # #7C3AED
INK = (79, 70, 229)  # #4F46E5

NODES = [(352, 508), (512, 372), (672, 508)]
NODE_R = 54
LINE_W = 34


def background() -> Image.Image:
    """تدرّج قُطري من فوق-شمال لتحت-يمين."""
    ramp = Image.linear_gradient("L").resize((S, S)).rotate(45, expand=False, resample=Image.BICUBIC)
    # الأركان بعد اللف بتبقى سودا: بنكبّر الوسط عشان يغطي
    ramp = ramp.resize((S * 2, S * 2)).crop((S // 2, S // 2, S // 2 + S, S // 2 + S))
    return Image.composite(Image.new("RGB", (S, S), BOTTOM), Image.new("RGB", (S, S), TOP), ramp)


def bubble_mask() -> Image.Image:
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((176, 196, 848, 692), radius=176, fill=255)
    # ذيل الفقاعة
    d.polygon([(300, 640), (268, 820), (452, 690)], fill=255)
    return m


def graph_mask() -> Image.Image:
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    for a, b in ((0, 1), (1, 2), (0, 2)):
        d.line([NODES[a], NODES[b]], fill=255, width=LINE_W)
    for x, y in NODES:
        d.ellipse((x - NODE_R, y - NODE_R, x + NODE_R, y + NODE_R), fill=255)
    return m


def foreground() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), mask=bubble_mask())
    img.paste(Image.new("RGBA", (S, S), INK + (255,)), mask=graph_mask())
    return img


def monochrome() -> Image.Image:
    mask = ImageChops.subtract(bubble_mask(), graph_mask())
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), mask=mask)
    return img


def legacy(bg: Image.Image, fg: Image.Image) -> Image.Image:
    """أيقونة جاهزة (مربع بحواف دايرة) للأجهزة القديمة."""
    out = bg.convert("RGBA")
    inner = fg.resize((int(S * 0.78), int(S * 0.78)), Image.LANCZOS)
    off = (S - inner.width) // 2
    out.alpha_composite(inner, (off, off))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, S, S), radius=int(S * 0.24), fill=255)
    out.putalpha(mask)
    return out


def main() -> None:
    bg, fg, mono = background(), foreground(), monochrome()
    sizes = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, size in sizes.items():
        d = RES / f"drawable-{density}"
        d.mkdir(parents=True, exist_ok=True)
        bg.resize((size, size), Image.LANCZOS).save(d / "ic_launcher_background.png")
        fg.resize((size, size), Image.LANCZOS).save(d / "ic_launcher_foreground.png")
        mono.resize((size, size), Image.LANCZOS).save(d / "ic_launcher_monochrome.png")
    full = legacy(bg, fg)
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        d = RES / f"mipmap-{density}"
        d.mkdir(parents=True, exist_ok=True)
        full.resize((size, size), Image.LANCZOS).save(d / "ic_launcher.png")
    full.resize((512, 512), Image.LANCZOS).save(ROOT / "tool/icon_preview.png")
    print("✅ الأيقونة اتولّدت")


if __name__ == "__main__":
    main()
