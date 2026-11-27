import sys, numpy as np
from PIL import Image
from scipy import ndimage as ndi

def unchecker(img):
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    mx, mn = a.max(2), a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1)
    # the baked-in checkerboard: the grey levels found along the border
    edge = np.concatenate([mx[0], mx[-1], mx[:, 0], mx[:, -1]])
    levels = np.unique(np.round(edge / 8) * 8)
    counts = [(np.abs(edge - l) < 6).sum() for l in levels]
    keep = [l for l, c in zip(levels, counts) if c > len(edge) * 0.05]
    # anything between the checker greys (their anti-aliased seams included)
    near = (mx >= min(keep) - 14) & (mx <= max(keep) + 14)
    bgish = ((mx - mn) < 14) & near  # neutral grey (absolute chroma, so near-black counts)
    lab, _ = ndi.label(bgish)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, border[border > 0])
    # close tiny holes in the background mask (checker edges)
    bg = ndi.binary_closing(bg, iterations=1)
    alpha = (~bg).astype(np.float32)
    alpha = ndi.gaussian_filter(alpha, 0.7)
    alpha = np.clip((alpha - 0.15) / 0.7, 0, 1)
    out = np.dstack([a, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

def demagenta(img):
    a = np.asarray(img).astype(np.float32)
    rgb = a[..., :3] / 255
    import colorsys
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(2), rgb.min(2)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    s = d / np.maximum(mx, 1e-6)
    mag = (h > 0.75) & (h < 0.97) & (s > 0.2)
    # turn magenta glow into warm amber (keep brightness)
    v = mx
    newr, newg, newb = v, v * 0.62, v * 0.22 + (1 - s) * v * 0.3
    for i, c in enumerate([newr, newg, newb]):
        rgb[..., i] = np.where(mag, np.clip(c, 0, 1), rgb[..., i])
    a[..., :3] = rgb * 255
    return Image.fromarray(a.astype(np.uint8), 'RGBA')

def pieces(img, minArea=2000, pad=6):
    al = np.asarray(img)[..., 3] > 40
    al = ndi.binary_closing(al, iterations=3)
    lab, n = ndi.label(al)
    out = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        area = (lab[sl] == i + 1).sum()
        if area < minArea:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        box = (max(0, x0 - pad), max(0, y0 - pad), min(img.width, x1 + pad), min(img.height, y1 + pad))
        own = ndi.binary_dilation(lab == i + 1, iterations=pad)
        arr = np.asarray(img).copy()
        arr[..., 3] = np.where(own, arr[..., 3], 0)
        out.append((y0, x0, Image.fromarray(arr, 'RGBA').crop(box)))
    # reading order: rows then columns
    out.sort(key=lambda t: (round(t[0] / 150), t[1]))
    return [p for _, _, p in out]

def fit(img, maxside=512):
    s = min(1, maxside / max(img.size))
    return img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS) if s < 1 else img

jobs = {
    'icons': ('game-item-icon-sheet-for-a-stormy-lighthouse.png', False, ['Wood', 'Scrap', 'Oil', 'Fish', 'WhaleOil', 'LampFlame'], 256),
    'buttons': ('roblox-game-ui-button-kit-on-a-fully-transparent.png', True, ['Button', 'ButtonHover', 'ButtonPressed', 'RoundButton', 'KeyCap', 'PillButton'], 512),
    'banners': ('next-asset-same-style-and-transparent-background.png', False, ['Banner', 'BannerWarning', 'BannerGood'], 1024),
    'badges': ('next-asset-same-style-fully-transparent.png', True, ['TierBlessed', 'TierMild', 'TierModerate', 'TierSevere', 'TierCatastrophic'], 256),
    'emblems': ('last-asset-same-style-fully-transparent.png', True, ['EmblemVictory', 'EmblemDefeat'], 512),
}
import os
os.makedirs('cut', exist_ok=True)
for key, (f, checker, names, size) in jobs.items():
    im = Image.open(f)
    im = unchecker(im) if checker else im.convert('RGBA')
    if key == 'icons':
        im = demagenta(im)
    ps = pieces(im)
    print(key, len(ps), [p.size for p in ps])
    for n, p in zip(names, ps):
        fit(p, size).save(f'cut/{n}.png')
