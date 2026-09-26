"""
vidcommon.py -- shared constants & helpers for the CRATE demo video pipeline.

Used by cards.py, compose.py and assemble.py. Not a deliverable on its own,
just a place to keep the three tools' pixel specs (cream colour, codec
settings, Ken Burns math, rounded-corner/shadow rendering) from drifting
apart. Pure-Python + ffmpeg/ffprobe; no ffmpeg drawtext/libass anywhere.

Style reference: demo/ref/ref1.mp4 (Anthropic Claude demo film).
  cream bg   = (251, 248, 245)  sampled from ref frames, flat background
  ink text   = (27, 25, 21)     sampled from the headline glyphs
  CRATE org  = (250, 91, 28)    #FA5B1C, given by the brief
"""
import json
import math
import os
import subprocess
import sys
import hashlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------------------------------------------------------------- geometry --
CANVAS_W, CANVAS_H, FPS = 1920, 1080, 30

# ------------------------------------------------------------------ colour --
CREAM = (251, 248, 245)
INK = (27, 25, 21)
ORANGE = (0xFA, 0x5B, 0x1C)          # CRATE orange, #FA5B1C
GREY = (120, 114, 106)               # kicker / caption grey on cream

CREAM_HEX = "0xFBF8F5"

# ------------------------------------------------------------------- paths --
HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.abspath(os.path.join(HERE, "..", "..", "demo"))
CACHE = os.path.join(DEMO, ".cache")
CARDS_DIR = os.path.join(DEMO, "cards")
os.makedirs(CACHE, exist_ok=True)
os.makedirs(CARDS_DIR, exist_ok=True)

DOTO_BLACK = "/Users/shuhanzhang/crate-build/Resources/Fonts/Doto-w900.ttf"

_SERIF_CANDIDATES = [
    "/System/Library/Fonts/NewYork.ttf",
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
]
_SERIF_BOLD_CANDIDATES = [
    "/System/Library/Fonts/NewYork.ttf",
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
]
_SANS_CANDIDATES = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
]

_font_cache = {}


def _first_existing(paths):
    for p in paths:
        if os.path.exists(p):
            return p
    return paths[-1]


def serif_font(size, weight="Regular"):
    """New York (variable font) at the given named instance, falling back to
    Georgia (which only has Regular/Bold) if New York can't be loaded."""
    key = ("serif", size, weight)
    if key in _font_cache:
        return _font_cache[key]
    path = _first_existing(_SERIF_CANDIDATES if weight == "Regular" else _SERIF_BOLD_CANDIDATES)
    font = ImageFont.truetype(path, size)
    if path.endswith("NewYork.ttf"):
        try:
            names = [n.decode() for n in font.get_variation_names()]
            if weight in names:
                font.set_variation_by_name(weight)
            elif weight == "Bold" and "Semibold" in names:
                font.set_variation_by_name("Semibold")
        except Exception:
            pass
    _font_cache[key] = font
    return font


def sans_font(size, bold=False):
    key = ("sans", size, bold)
    if key in _font_cache:
        return _font_cache[key]
    path = _first_existing(_SANS_CANDIDATES)
    try:
        font = ImageFont.truetype(path, size)
        if path.endswith("SFNS.ttf"):
            try:
                names = [n.decode() for n in font.get_variation_names()]
                want = "Bold" if bold else "Regular"
                if want in names:
                    font.set_variation_by_name(want)
            except Exception:
                pass
    except Exception:
        font = ImageFont.load_default()
    _font_cache[key] = font
    return font


def doto_font(size):
    key = ("doto", size)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(DOTO_BLACK, size)
    return _font_cache[key]


# --------------------------------------------------------------- ffmpeg io --
def sh(cmd, quiet=True):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(" ".join(cmd) + "\n")
        sys.stderr.write(r.stderr[-4000:] + "\n")
        raise RuntimeError(f"command failed ({r.returncode}): {cmd[0]}")
    return r.stdout


def ffprobe_json(path, extra):
    out = sh(["ffprobe", "-v", "error", "-of", "json"] + extra + [path])
    return json.loads(out)


def probe_size(path):
    d = ffprobe_json(path, ["-select_streams", "v:0", "-show_entries", "stream=width,height"])
    st = d["streams"][0]
    return int(st["width"]), int(st["height"])


def probe_duration(path):
    d = ffprobe_json(path, ["-show_entries", "format=duration"])
    return float(d["format"]["duration"])


def has_audio(path):
    d = ffprobe_json(path, ["-select_streams", "a", "-show_entries", "stream=codec_type"])
    return len(d.get("streams", [])) > 0


def even(x):
    return int(round(x / 2.0)) * 2


# -------------------------------------------------------- encode constants --
VCODEC_MOV = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "16",
              "-pix_fmt", "yuv420p"]
ACODEC_PCM = ["-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2"]

VCODEC_FINAL = ["-c:v", "libx264", "-profile:v", "high", "-preset", "medium",
                "-crf", "16", "-pix_fmt", "yuv420p"]
ACODEC_AAC = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000"]


def silent_audio_args(dur):
    return ["-f", "lavfi", "-i", f"anullsrc=r=48000:cl=stereo", "-t", f"{dur:.6f}"]


# ------------------------------------------------------- Ken Burns camera ---
def piecewise_expr(keys, field, t_var="t"):
    """ffmpeg eval expression: ease-in-out (smoothstep) interpolation of
    keys[i][field] across keys[i]['t'], holding the first/last value outside
    the given range. keys: list of dicts sorted or not, each with 't' and
    `field`."""
    ks = sorted(keys, key=lambda k: k["t"])
    if len(ks) == 1:
        return f"({ks[0][field]})"
    segs = []
    for i in range(len(ks) - 1):
        t0, t1 = ks[i]["t"], ks[i + 1]["t"]
        v0, v1 = ks[i][field], ks[i + 1][field]
        dt = (t1 - t0) or 1e-6
        p = f"clip(({t_var}-{t0})/{dt},0,1)"
        s = f"(({p})*({p})*(3-2*({p})))"
        segs.append((t1, f"({v0}+({v1}-{v0})*{s})"))
    expr = segs[-1][1]
    for t1, formula in reversed(segs[:-1]):
        expr = f"if(lt({t_var},{t1}),{formula},{expr})"
    return expr


def keys_are_static(keys):
    z0, x0, y0 = keys[0]["zoom"], keys[0]["cx"], keys[0]["cy"]
    return all(k["zoom"] == z0 and k["cx"] == x0 and k["cy"] == y0 for k in keys)


def kenburns_filter(keys, target_w, target_h, t_var="t"):
    """Build an ffmpeg video-filter string implementing a keyframed virtual
    camera: `keys` is [{"t":sec,"zoom":1.0,"cx":0.5,"cy":0.5}, ...] with cx/cy
    normalized focus point in the SOURCE frame. Output is always exactly
    target_w x target_h.

    Implementation note: zoom is realised by progressively up-scaling the
    source (scale filter, eval=frame) and pan by cropping a fixed target_w x
    target_h window out of that scaled frame (crop x/y, which ffmpeg *does*
    evaluate per-frame). The crop's pixel offsets are computed analytically
    from the same zoom(t) formula rather than read back from the upstream
    frame size (crop's in_w/in_h were found NOT to track a dynamically
    resized upstream `scale` -- they stay pinned at the size negotiated at
    graph init, which silently breaks the pan). Verified empirically before
    relying on it (see scratch tests during development).
    """
    if not keys:
        keys = [{"t": 0, "zoom": 1.0, "cx": 0.5, "cy": 0.5}]
    if keys_are_static(keys):
        z, cx, cy = keys[0]["zoom"], keys[0]["cx"], keys[0]["cy"]
        sw, sh_ = even(target_w * z), even(target_h * z)
        x = min(max(cx * sw - target_w / 2, 0), max(sw - target_w, 0))
        y = min(max(cy * sh_ - target_h / 2, 0), max(sh_ - target_h, 0))
        if z == 1.0:
            return f"scale={target_w}:{target_h}:flags=bicubic"
        return (f"scale={sw}:{sh_}:flags=bicubic,"
                f"crop={target_w}:{target_h}:{int(x)}:{int(y)}")

    zoom_e = piecewise_expr(keys, "zoom", t_var)
    cx_e = piecewise_expr(keys, "cx", t_var)
    cy_e = piecewise_expr(keys, "cy", t_var)
    sw = f"({target_w}*({zoom_e}))"
    sh_ = f"({target_h}*({zoom_e}))"
    scale_w = f"trunc(({sw})/2)*2"
    scale_h = f"trunc(({sh_})/2)*2"
    crop_x = f"clip(({cx_e})*({sw})-{target_w}/2,0,({sw})-{target_w})"
    crop_y = f"clip(({cy_e})*({sh_})-{target_h}/2,0,({sh_})-{target_h})"
    return (f"scale=w='{scale_w}':h='{scale_h}':eval=frame:flags=bicubic,"
            f"crop=w={target_w}:h={target_h}:x='{crop_x}':y='{crop_y}'")


# ------------------------------------------------------- rounded rect etc. --
def _rounded_mask(w, h, radius, ss=4):
    """Antialiased rounded-rect ALPHA mask (L mode), opaque(255) inside the
    rounded rect, 0 outside. Supersampled then downsized for smooth edges."""
    W, H, R = w * ss, h * ss, radius * ss
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=R, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def corner_mask_png(w, h, radius, bg=CREAM, cache_key=None):
    """RGBA image, size w x h: `bg` colour OPAQUE at the four corners outside
    the rounded rect, fully TRANSPARENT inside it (antialiased transition).
    Overlaying this exactly on top of a sharp-cornered device video punches
    its corners back to rounded, revealing the cream canvas underneath."""
    key = cache_key or f"corner_{w}_{h}_{radius}_{bg}"
    path = os.path.join(CACHE, key + ".png")
    if os.path.exists(path):
        return path
    inside = _rounded_mask(w, h, radius)
    alpha = Image.eval(inside, lambda v: 255 - v)
    img = Image.new("RGBA", (w, h), bg + (255,))
    img.putalpha(alpha)
    img.save(path)
    return path


def drop_shadow_png(w, h, radius, blur=None, dy=None, alpha=100, cache_key=None):
    """RGBA image, padded canvas containing a blurred black rounded-rect the
    same shape as the device, offset down by `dy` -- meant to sit UNDER the
    device layer so only the halo around it (mostly the bottom edge) shows."""
    blur = blur if blur is not None else max(8, round(w * 0.02))
    dy = dy if dy is not None else max(6, round(h * 0.02))
    pad = blur * 3 + abs(dy) + 4
    key = cache_key or f"shadow_{w}_{h}_{radius}_{blur}_{dy}_{alpha}"
    path = os.path.join(CACHE, key + ".png")
    if os.path.exists(path):
        return path, pad
    W, H = w + pad * 2, h + pad * 2
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shape = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shape).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=alpha)
    base.paste((0, 0, 0, alpha), (pad, pad + dy), shape.resize((w, h)))
    base = base.filter(ImageFilter.GaussianBlur(blur))
    base.save(path)
    return path, pad


def fit_box(iw, ih, box_w, box_h):
    """Largest (w,h) with source aspect that fits inside box_w x box_h,
    rounded to even pixels."""
    scale = min(box_w / iw, box_h / ih)
    return even(iw * scale), even(ih * scale)


def cache_path(kind, params, ext):
    key = hashlib.md5(json.dumps(params, sort_keys=True).encode()).hexdigest()[:16]
    return os.path.join(CACHE, f"{kind}_{key}{ext}")
