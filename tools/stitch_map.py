"""Stitch top-down Studio screen captures into the minimap image (tools/stitch_map.py).

Captures: 1528x882, FOV 45 (vertical), camera 1000 studs up looking straight down,
image right = +X, image down = +Z. Tiles: columns x = -500 / 500, rows z = -550 / 150 / 850
(files tile_a..tile_f, row-major). Output: a 1024x1024 map of X [-1050, 1050],
Z [-900, 1200] (Config.Minimap must match), lightly colour-graded.
"""
import math
import sys

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy.ndimage import map_coordinates

src = sys.argv[1] if len(sys.argv) > 1 else "."
out = sys.argv[2] if len(sys.argv) > 2 else "IslandMap.png"

W, H = 1528, 882
F = (H / 2) / math.tan(math.radians(45 / 2))
DIST = 1000 - 8  # camera height above the average ground
COLS = [-500, 500]
ROWS = [-550, 150, 850]
X0, Z0, SPAN, N = -1050, -900, 2100, 1024

tiles = {}
names = "abcdef"
k = 0
for r, cz in enumerate(ROWS):
    for c, cx in enumerate(COLS):
        im = np.asarray(Image.open(f"{src}/tile_{names[k]}.jpg").convert("RGB"), dtype=np.float32)
        tiles[(r, c)] = (cx, cz, im)
        k += 1

xs = X0 + (np.arange(N) + 0.5) * SPAN / N
zs = Z0 + (np.arange(N) + 0.5) * SPAN / N
gx, gz = np.meshgrid(xs, zs)
outimg = np.zeros((N, N, 3), np.float32)
col = (gx >= 0).astype(int)
row = np.where(gz < -200, 0, np.where(gz < 500, 1, 2))
for (r, c), (cx, cz, im) in tiles.items():
    mask = (row == r) & (col == c)
    px = W / 2 + (gx[mask] - cx) * F / DIST
    py = H / 2 + (gz[mask] - cz) * F / DIST
    for ch in range(3):
        outimg[..., ch][mask] = map_coordinates(im[..., ch], [py, px], order=1, mode="nearest")

# repaint the sea as one smooth gradient (the captures differ a little in brightness):
# bright turquoise by the shore fading to deep blue, with a pale foam line on the sand
from scipy.ndimage import distance_transform_edt, binary_opening

r_, g_, b_ = outimg[..., 0], outimg[..., 1], outimg[..., 2]
land = ~((b_ - r_ > 60) & (g_ - r_ > 30))
land = binary_opening(land, iterations=1)  # drop single-pixel specks
water = ~land
dist = distance_transform_edt(water) * SPAN / N  # studs from the shore
t = np.clip(dist / 260.0, 0, 1)[..., None]
shallow = np.array([70, 215, 220], np.float32)
deep = np.array([18, 96, 170], np.float32)
sea = shallow * (1 - t) + deep * t
foam = np.clip(1 - dist / 6.0, 0, 1)[..., None] * 0.6
sea = sea * (1 - foam) + np.array([235, 250, 250], np.float32) * foam
outimg = np.where(water[..., None], sea, outimg)

img = Image.fromarray(np.clip(outimg, 0, 255).astype(np.uint8))
img = ImageEnhance.Color(img).enhance(1.25)
img = ImageEnhance.Contrast(img).enhance(1.08)
img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
img.save(out)
print("wrote", out, img.size)
