from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

root = Path(__file__).resolve().parents[1]
destination = root / "Resources/Assets.xcassets/AppIcon.appiconset"
size = 1024

canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
surface = Image.new("RGBA", (size, size), (0, 0, 0, 0))
pixels = surface.load()
for y in range(size):
    for x in range(size):
        t = (x + y) / (size * 2)
        glow = max(0.0, 1.0 - ((x - 250) ** 2 + (y - 120) ** 2) ** 0.5 / 900)
        pixels[x, y] = (
            int(12 + 27 * glow),
            int(17 + 45 * glow),
            int(28 + 78 * glow + 12 * t),
            255,
        )

mask = Image.new("L", (size, size), 0)
ImageDraw.Draw(mask).rounded_rectangle((62, 62, 962, 962), radius=220, fill=255)
shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((80, 95, 944, 959), radius=210, fill=(0, 0, 0, 155))
canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(34)))
canvas.alpha_composite(Image.composite(surface, Image.new("RGBA", (size, size)), mask))

draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((63, 63, 961, 961), radius=219, outline=(255, 255, 255, 78), width=4)
bars = [(260, 560, 352, 750), (406, 430, 498, 750), (552, 285, 644, 750), (698, 485, 790, 750)]
for box in bars:
    draw.rounded_rectangle(box, radius=38, fill=(70, 144, 235, 255), outline=(135, 210, 255, 180), width=4)
draw.line((230, 820, 790, 820), fill=(220, 237, 255, 115), width=18)
draw.arc((165, 125, 845, 410), 205, 333, fill=(255, 255, 255, 88), width=22)

for px in (16, 32, 64, 128, 256, 512, 1024):
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(destination / f"icon-{px}.png")

print("Generated app icons.")
