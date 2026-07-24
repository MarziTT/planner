"""Generate Android launcher icons at all densities from the AI-generated master."""
from PIL import Image

SRC = r"F:\PixelPlanner\assets\icons\Premium_mobile_app_icon__cente_2026-07-24T09-40-42.png"
MASTER = r"F:\PixelPlanner\assets\icons\dd_icon_master.png"
RES = r"F:\PixelPlanner\mobile_app\android\app\src\main\res"

DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

img = Image.open(SRC).convert("RGB")
w, h = img.size
print(f"source: {w}x{h}")

# 1. Cover the AI watermark (bottom-right) with background color sampled
#    from the bottom-left corner (same gradient zone, no watermark).
bg = img.getpixel((100, h - 44))
for y in range(h - 124, h):
    for x in range(620, w):
        img.putpixel((x, y), bg)
img.save(MASTER)
print("master saved (watermark removed)")

# 2. Emit every density.
for folder, size in DENSITIES.items():
    out = img.resize((size, size), Image.LANCZOS)
    path = rf"{RES}\{folder}\ic_launcher.png"
    out.save(path, "PNG")
    print(f"wrote {path} ({size}x{size})")

print("ALL_ICONS_DONE")
