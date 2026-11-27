"""Cut the ForgeGUI HUD art into separate transparent pieces (tools/forge_cutout.py).

Input: the three 1672x941 RGBA PNGs from ForgeGUI. Output: one trimmed PNG per piece.
The free-plan "Made with" watermark (bottom right, x>=1310, y>=830) is removed: where it
touches a piece, that corner is rebuilt by mirroring the piece's clean left side.
Stray bright-green pixels (generator artefacts on the rope ties) are toned to navy.
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
WM_X, WM_Y = 1310, 830


def pieces(path):
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    m = ndimage.binary_closing(a[..., 3] > 30, iterations=3)
    lab, _ = ndimage.label(m)
    found = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        if (s[0].stop - s[0].start) * (s[1].stop - s[1].start) < 20000:
            continue  # watermark bits
        found.append((s, lab == i + 1))
    return a, found


def clean(a, s, mask, mirror):
    y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
    piece = a.copy()
    piece[~mask] = 0
    if mirror:
        # true right edge = mirror of the left edge around the piece's upper rows
        rows = np.where(mask[: WM_Y - 40].any(axis=0))[0]
        left, right = rows.min(), rows.max()
        for y in range(WM_Y - 20, y1):
            for x in range(WM_X - 30, right + 1):
                mx = left + (right - x)
                piece[y, x] = a[y, mx] if mask[y, mx] else 0
        x1 = right + 1
    # tone down green artefacts
    r, g, b = piece[..., 0].astype(int), piece[..., 1].astype(int), piece[..., 2].astype(int)
    green = (g > 110) & (g > r * 1.35) & (g > b * 1.35)
    piece[green, 0:3] = (44, 58, 78)
    pad = 4
    crop = piece[max(0, y0 - pad): y1 + pad, max(0, x0 - pad): x1 + pad]
    return Image.fromarray(crop)


jobs = {
    "roblox-survival-game-hud-set-for-the-last-2.png": {0: "porthole", 1: "bar"},
    "roblox-survival-game-hud-set-for-the-last-3.png": {0: "panel", 1: "scroll"},
    "roblox-survival-game-hud-set-for-the-last.png": {0: "close", 1: "title"},
}
for f, names in jobs.items():
    a, found = pieces(f"{src}/{f}")
    found.sort(key=lambda p: (p[0][0].start, p[0][1].start))
    # pieces sorted top-to-bottom: map by order of appearance
    order = sorted(range(len(found)), key=lambda i: found[i][0][0].start)
    for rank, i in enumerate(order):
        s, mask = found[i]
        name = names[rank] if rank in names else None
        if not name:
            continue
        touches = s[1].stop > WM_X and s[0].stop > WM_Y
        img = clean(a, s, mask, touches)
        img.save(f"{out}/{name}.png")
        print(name, img.size, "mirrored corner" if touches else "")
