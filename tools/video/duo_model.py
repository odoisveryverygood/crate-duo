#!/usr/bin/env python3
"""
duo_model.py -- procedural iPhone Duo hardware renders for the CRATE film.

A small painter's-algorithm renderer (Pillow + numpy, no OpenCV): two thin
titanium slabs with rounded metal bands, black glass bezels and rounded
screens, joined by a hinge barrel, lit by a studio key/rim/top light, with a
soft contact + cast shadow on the cream table. Rendered at 2x of 3840x2160
and downsampled (antialiasing), cached under demo/.cache/duo/<hash>/:

  body.png      3840x2160 RGB: background, shadows, device with black screens
  glass.png     3840x2160 RGBA: subtle glass sheen, only inside the screens
  mask_<s>.png  per-screen L mask (rounded screen shape), cropped to its bbox
  scene.json    per screen: quad corners TL,TR,BL,BR (UI orientation, canvas
                px), bbox, UI size, homography UI(0..1) -> canvas

Poses / views (render(spec)):
  {"pose":"laptop","view":"front"}   lid ~110 deg + deck flat, camera front/up
  {"pose":"laptop","view":"back"}    same device from behind: the outer screen
  {"pose":"laptop","view":"front+back"}  two-view composition (three screens)
  {"pose":"book"}                    unfolded ~168 deg, fold vertical, tilted

Screens: "lid", "deck" (inner display halves, 2006x1366 each), "outer"
(back of the lid, 2034x1398), "left"/"right" (book pose, 1366x2006 each).

  python duo_model.py                 # renders the default views + previews
"""
import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc

W4, H4 = 3840, 2160
SS = 2
DUO_CACHE = os.path.join(vc.CACHE, "duo")
VERSION = 8

# ---------------------------------------------------------- physical model --
# inches; each inner half is 2006 x 1366 px (the simulator's inner display
# split at its 40 pt division), the outer display 2034 x 1398 px.
T = 0.20                    # thickness of each half
E = T / 2                   # radius of the rounded titanium band
BEZ = 0.07                  # black glass border around a screen
RS = 0.20                   # screen corner radius
SCR_W = 4.20
SCR_H = SCR_W * 1366 / 2006
PW = SCR_W + 2 * (BEZ + E)  # panel outer size in plan
PH = SCR_H + 2 * (BEZ + E)
PR = RS + BEZ + E
RB = 0.112                  # hinge barrel radius (a touch fatter than the halves)
HGAP = 0.03                 # clearance barrel <-> panel edge
OUT_PX = (2034, 1398)
IN_PX = (2006, 1366)

TITANIUM = np.array([178, 176, 172]) / 255.0
BARREL = np.array([150, 149, 147]) / 255.0
GRAPHITE = np.array([52, 52, 56]) / 255.0
BEZEL = np.array([7, 7, 9]) / 255.0

UP = np.array([0.0, 1.0, 0.0])
KEY = None
RIM = None
FILL = None


def norm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


KEY = norm((-0.45, 0.85, 0.55))
RIM = norm((0.7, 0.45, -0.55))
FILL = norm((0.8, 0.3, 0.6))


# ------------------------------------------------------------------ camera --
class Cam:
    def __init__(self, pos, target, up=(0, 1, 0)):
        self.C = np.asarray(pos, float)
        f = norm(np.asarray(target, float) - self.C)
        r = norm(np.cross(f, up))
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.F, self.cx, self.cy = 1.0, 0.0, 0.0

    def cam(self, P):
        d = np.asarray(P, float) - self.C
        return np.stack([d @ self.r, d @ self.u, d @ self.f], axis=-1)

    def norm_xy(self, P):
        c = self.cam(P)
        return c[..., 0] / c[..., 2], c[..., 1] / c[..., 2]

    def project(self, P):
        x, y = self.norm_xy(P)
        return np.stack([self.cx + self.F * x, self.cy - self.F * y], axis=-1)

    def fit(self, pts, rect, frac=0.84):
        """scale/shift so that the projected pts fill `frac` of rect (x,y,w,h) and are centred in it"""
        x, y = self.norm_xy(pts)
        x0, x1, y0, y1 = x.min(), x.max(), y.min(), y.max()
        rx, ry, rw, rh = rect
        self.F = min(frac * rh / (y1 - y0), 0.96 * rw / (x1 - x0))
        self.cx = rx + rw / 2 - self.F * (x0 + x1) / 2
        self.cy = ry + rh / 2 + self.F * (y0 + y1) / 2


def orbit(target, dist, el_deg, az_deg):
    el, az = math.radians(el_deg), math.radians(az_deg)
    t = np.asarray(target, float)
    return t + dist * np.array([math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el)])


# ------------------------------------------------------------------- faces --
class Face:
    __slots__ = ("pts", "normal", "mat", "two_sided", "part")

    def __init__(self, pts, normal, mat, two_sided=False, part="x"):
        self.pts = np.asarray(pts, float)
        self.normal = norm(normal)
        self.mat = mat
        self.two_sided = two_sided
        self.part = part


def rrect(hw, hh, r, n=12):
    """rounded rect outline in (a,b), CCW, with outward normals. r: one radius or
    four, for the corners (+a,+b), (-a,+b), (-a,-b), (+a,-b)."""
    rs = r if isinstance(r, (tuple, list)) else (r, r, r, r)
    pts, nrm = [], []
    for (sx, sy, a0), rr in zip(((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)), rs):
        cx, cy = sx * (hw - rr), sy * (hh - rr)
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
            nrm.append((math.cos(a), math.sin(a)))
    return np.array(pts), np.array(nrm)


class Panel:
    """A slab: mid-plane centre c, in-plane axes u (UI +x) and v (UI +y, i.e.
    down the screen), screen normal n; plan half-extents hw (along u), hh."""

    def __init__(self, c, u, v, n, hw, hh, radii=None, part="p"):
        self.c, self.u, self.v, self.n = (np.asarray(x, float) for x in (c, u, v, n))
        self.hw, self.hh = hw, hh
        self.radii = radii or (PR, PR, PR, PR)
        self.part = part

    def faces(self, back_mat="graphite"):
        out = []
        pl, nl = rrect(self.hw - E, self.hh - E, tuple(max(0.004, r - E) for r in self.radii), n=14)
        prof = np.radians(np.linspace(90, -90, 11))
        K = len(pl)
        ring = []
        for j, th in enumerate(prof):
            row = []
            for k in range(K):
                m = nl[k, 0] * self.u + nl[k, 1] * self.v
                p = self.c + pl[k, 0] * self.u + pl[k, 1] * self.v + E * (math.cos(th) * m + math.sin(th) * self.n)
                row.append((p, math.cos(th) * m + math.sin(th) * self.n))
            ring.append(row)
        for j in range(len(prof) - 1):
            for k in range(K):
                k2 = (k + 1) % K
                a, b, c, d = ring[j][k], ring[j][k2], ring[j + 1][k2], ring[j + 1][k]
                nrm = a[1] + b[1] + c[1] + d[1]
                out.append(Face([a[0], b[0], c[0], d[0]], nrm, "titanium", part=self.part))
        top = [self.c + pl[k, 0] * self.u + pl[k, 1] * self.v + E * self.n for k in range(K)]
        bot = [self.c + pl[k, 0] * self.u + pl[k, 1] * self.v - E * self.n for k in range(K)]
        out.append(Face(top, self.n, "bezel", part=self.part))
        out.append(Face(bot, -self.n, back_mat, part=self.part))
        return out

    def screen(self, w, h, r, side=+1, flip_u=False, lift=0.002):
        """3D corners (TL,TR,BL,BR in UI orientation) + rounded outline of a screen
        centred on the front (side=+1) or back (side=-1) face."""
        u = -self.u if flip_u else self.u
        hgt = side * (E + lift)
        c = self.c + hgt * self.n
        corners = [c + sa * w / 2 * u + sb * h / 2 * self.v for sa, sb in ((-1, -1), (1, -1), (-1, 1), (1, 1))]
        pl, _ = rrect(w / 2, h / 2, r, n=16)
        outline = [c + a * u + b * self.v for a, b in pl]
        return np.array(corners), np.array(outline), side * self.n


def barrel_faces(a0, a1, axis_pt, axis, ref, rad, n=40):
    """cylinder along `axis` from a0 to a1 (scalars along axis) through axis_pt; ref = a unit vector perpendicular to axis"""
    axis = norm(axis)
    ref = norm(ref)
    oth = np.cross(axis, ref)
    out = []
    angs = np.linspace(0, 2 * math.pi, n + 1)
    for i in range(n):
        t0, t1 = angs[i], angs[i + 1]
        d0 = math.cos(t0) * ref + math.sin(t0) * oth
        d1 = math.cos(t1) * ref + math.sin(t1) * oth
        p = [axis_pt + a0 * axis + rad * d0, axis_pt + a1 * axis + rad * d0,
             axis_pt + a1 * axis + rad * d1, axis_pt + a0 * axis + rad * d1]
        out.append(Face(p, d0 + d1, "barrel"))
    for a, s in ((a0, -1), (a1, 1)):
        cap = [axis_pt + a * axis + rad * 0.93 * (math.cos(t) * ref + math.sin(t) * oth) for t in angs[:-1]]
        out.append(Face(cap, s * axis, "cap"))
        ring = []
        for i in range(n):
            t0, t1 = angs[i], angs[i + 1]
            d0 = math.cos(t0) * ref + math.sin(t0) * oth
            d1 = math.cos(t1) * ref + math.sin(t1) * oth
            ring.append(Face([axis_pt + a * axis + rad * d0, axis_pt + a * axis + rad * d1,
                              axis_pt + a * axis + rad * 0.93 * d1, axis_pt + a * axis + rad * 0.93 * d0],
                             s * axis * 0.6 + (d0 + d1) * 0.4, "barrel"))
        out.extend(ring)
    return out


# ------------------------------------------------------------------ device --
def laptop_device(open_deg=110.0):
    al = math.radians(open_deg)
    A = np.array([0.0, RB, 0.0])
    x = np.array([1.0, 0, 0])
    # deck: resting on the table, UI top edge at the hinge
    deck_c = np.array([0.0, E, RB + HGAP + PH / 2])
    HR = 0.07
    deck = Panel(deck_c, x, (0, 0, 1), (0, 1, 0), PW / 2, PH / 2, radii=(PR, PR, HR, HR), part="deck")
    d = np.array([0.0, math.sin(al), math.cos(al)])          # hinge -> lid top
    n = np.array([0.0, -math.cos(al), math.sin(al)])         # lid screen normal (front/up)
    lid = Panel(A + (RB + HGAP + PH / 2) * d, x, -d, n, PW / 2, PH / 2, radii=(HR, HR, PR, PR), part="lid")
    faces = deck.faces() + lid.faces() + barrel_faces(-PW / 2 + 0.05, PW / 2 - 0.05, A, x, (0, 0, 1), RB)
    screens = {}
    for name, p in (("lid", lid), ("deck", deck)):
        corners, outline, nrm = p.screen(SCR_W, SCR_H, RS)
        screens[name] = {"corners": corners, "outline": outline, "normal": nrm, "px": IN_PX, "part": p.part}
    ow = min(SCR_W - 0.02, (SCR_H - 0.04) * OUT_PX[0] / OUT_PX[1])
    oh = ow * OUT_PX[1] / OUT_PX[0]
    corners, outline, nrm = lid.screen(ow, oh, RS * 0.9, side=-1, flip_u=True)
    screens["outer"] = {"corners": corners, "outline": outline, "normal": nrm, "px": OUT_PX, "part": "lid"}
    # contact footprint (deck + barrel on the table) and the lid for the cast shadow
    fp, _ = rrect(PW / 2, PH / 2, PR, n=10)
    footprint = [deck_c + a * x + b * np.array([0, 0, 1.0]) - np.array([0, E, 0]) for a, b in fp]
    lid_outline = [lid.c + a * lid.u + b * lid.v for a, b in fp]
    return {"faces": faces, "screens": screens, "footprint": footprint, "caster": lid_outline,
            "all_pts": np.array([p for f in faces for p in f.pts])}


def book_device(open_deg=168.0, lift=0.35):
    half = math.radians((180 - open_deg) / 2)
    y_c = lift + PW / 2
    A = np.array([0.0, y_c, 0.0])
    dL = np.array([-math.cos(half), 0, math.sin(half)])
    dR = np.array([math.cos(half), 0, math.sin(half)])
    nL = np.array([math.sin(half), 0, math.cos(half)])
    nR = np.array([-math.sin(half), 0, math.cos(half)])
    v = np.array([0, -1.0, 0])
    off = RB + 0.012 + PH / 2
    HR = 0.07
    left = Panel(A + off * dL, -dL, v, nL, PH / 2, PW / 2, radii=(HR, PR, PR, HR), part="left")
    right = Panel(A + off * dR, dR, v, nR, PH / 2, PW / 2, radii=(PR, HR, HR, PR), part="right")
    faces = left.faces() + right.faces() + barrel_faces(-PW / 2 + 0.05, PW / 2 - 0.05, A, (0, 1, 0), (0, 0, 1), RB)
    screens = {}
    for name, p in (("left", left), ("right", right)):
        corners, outline, nrm = p.screen(SCR_H, SCR_W, RS)
        screens[name] = {"corners": corners, "outline": outline, "normal": nrm, "px": (IN_PX[1], IN_PX[0]), "part": p.part}
    fp = []
    for p in (left, right):
        for a in np.linspace(-p.hw, p.hw, 8):
            fp.append(p.c + a * p.u + p.hh * p.v)
    fp = [np.array([q[0], 0.0, q[2]]) for q in fp]
    ell = [np.array([0, 0, 0.0]) + np.array([2.9 * math.cos(t), 0, 0.55 * math.sin(t) + 0.2]) for t in np.linspace(0, 2 * math.pi, 40)]
    return {"faces": faces, "screens": screens, "footprint": ell, "caster": None,
            "all_pts": np.array([p for f in faces for p in f.pts])}


# --------------------------------------------------------------- rendering --
def shade(face, cam):
    c = face.pts.mean(axis=0)
    view = norm(cam.C - c)
    n = face.normal
    if face.mat == "bezel":
        refl = 2 * (n @ view) * n - view
        s = 0.10 * max(0, refl @ KEY) ** 20 + 0.03 * max(0, refl @ UP) ** 4
        col = BEZEL + s
    else:
        base = {"titanium": TITANIUM, "barrel": BARREL, "cap": BARREL * 0.8, "graphite": GRAPHITE}[face.mat]
        gloss = {"titanium": 38, "barrel": 26, "cap": 12, "graphite": 18}[face.mat]
        diff = 0.26 + 0.52 * max(0, n @ KEY) + 0.22 * max(0, n @ UP) + 0.14 * max(0, n @ FILL) + 0.10 * max(0, n @ RIM)
        refl = 2 * (n @ view) * n - view
        spec = 0.75 * max(0, refl @ KEY) ** gloss + 0.30 * max(0, refl @ UP) ** 5 + 0.35 * max(0, refl @ RIM) ** 24
        k = 1.0 if face.mat != "graphite" else 0.35
        col = base * diff + k * spec
    return tuple(int(255 * min(1.0, max(0.0, v))) for v in col)


def draw_device(img, dev, cam, shadow=True):
    """paint one device (faces, painter's algorithm) onto img (SS-scaled canvas)"""
    Wc, Hc = img.size
    if shadow:
        lo = 8
        sh = Image.new("L", (Wc // lo, Hc // lo), 0)
        d = ImageDraw.Draw(sh)
        fp = cam.project(np.array(dev["footprint"])) / lo
        d.polygon([tuple(p) for p in fp], fill=190)
        contact = sh.filter(ImageFilter.GaussianBlur(2.2 * SS))
        if dev.get("caster") is not None:
            L = norm((0.12, -1.0, -0.42))
            cast = []
            for P in dev["caster"]:
                P = np.asarray(P)
                t = -P[1] / L[1]
                cast.append(P + t * L)
            cast = np.array(cast + list(dev["footprint"]))
            cs = Image.new("L", sh.size, 0)
            ImageDraw.Draw(cs).polygon([tuple(p) for p in (cam.project(cast) / lo)], fill=46)
            # convex-ish hull is fine: blur hides it
            cs = cs.filter(ImageFilter.GaussianBlur(16.0 * SS))
            contact = Image.fromarray(np.maximum(np.asarray(contact), np.asarray(cs)))
        amb = sh.filter(ImageFilter.GaussianBlur(10.0 * SS)).point(lambda v: int(v * 0.55))
        m = Image.fromarray(np.maximum(np.asarray(contact), np.asarray(amb))).resize((Wc, Hc), Image.BILINEAR)
        dark = Image.new("RGB", (Wc, Hc), (118, 108, 98))
        img.paste(Image.composite(dark, img, m.point(lambda v: int(v * 0.62))), (0, 0))
    draw = ImageDraw.Draw(img)
    items = []
    for f in dev["faces"]:
        c = f.pts.mean(axis=0)
        view = cam.C - c
        if (f.normal @ view) <= 0 and not f.two_sided:
            continue
        depth = np.linalg.norm(view)
        items.append((depth, f))
    items.sort(key=lambda x: -x[0])
    for _, f in items:
        pts = cam.project(f.pts)
        draw.polygon([tuple(p) for p in pts], fill=shade(f, cam))
        if f.mat == "bezel":
            draw.line([tuple(p) for p in pts] + [tuple(pts[0])], fill=(58, 58, 62), width=max(1, SS))


def homography(src, dst):
    """3x3 H with dst ~ H @ src (4 point pairs)"""
    A, bvec = [], []
    for (x, y), (X, Y) in zip(src, dst):
        A.append([x, y, 1, 0, 0, 0, -X * x, -X * y]); bvec.append(X)
        A.append([0, 0, 0, x, y, 1, -Y * x, -Y * y]); bvec.append(Y)
    h = np.linalg.solve(np.array(A, float), np.array(bvec, float))
    return np.append(h, 1.0).reshape(3, 3)


def spec_key(spec):
    return hashlib.md5(json.dumps({"spec": spec, "v": VERSION}, sort_keys=True).encode()).hexdigest()[:12]


def views_for(spec):
    """[(device, cam, screen-name prefix)] for a render spec"""
    pose = spec.get("pose", "laptop")
    view = spec.get("view", "front")
    out = []
    if pose == "laptop":
        dev = laptop_device(spec.get("open", 110.0))
        tgt = (0.0, 1.05, 0.85)
        if view == "front":
            cam = Cam(orbit(tgt, 40, spec.get("el", 27), spec.get("az", 0)), tgt)
            cam.fit(dev["all_pts"], (0, 0, W4 * SS, H4 * SS), spec.get("fill", 0.84))
            out.append((dev, cam, ""))
        elif view == "back":
            cam = Cam(orbit(tgt, 40, spec.get("el", 14), spec.get("az", 205)), tgt)
            cam.fit(dev["all_pts"], (0, 0, W4 * SS, H4 * SS), spec.get("fill", 0.84))
            out.append((dev, cam, ""))
        elif view == "front+back":
            camA = Cam(orbit(tgt, 40, spec.get("el", 27), spec.get("az", 0)), tgt)
            camA.fit(dev["all_pts"], (int(0.02 * W4 * SS), 0, int(0.56 * W4 * SS), H4 * SS), spec.get("fill", 0.80))
            dev2 = laptop_device(spec.get("open", 110.0))
            camB = Cam(orbit(tgt, 40, spec.get("el_back", 13), spec.get("az_back", 212)), tgt)
            camB.fit(dev2["all_pts"], (int(0.585 * W4 * SS), 0, int(0.40 * W4 * SS), H4 * SS), spec.get("fill_back", 0.62))
            out.append((dev, camA, ""))
            out.append((dev2, camB, "back_"))
    elif pose == "book":
        dev = book_device(spec.get("open", 168.0))
        tgt = (0.0, 0.35 + PW / 2, 0.0)
        cam = Cam(orbit(tgt, 40, spec.get("el", 9), spec.get("az", 16)), tgt)
        cam.fit(dev["all_pts"], (0, 0, W4 * SS, H4 * SS), spec.get("fill", 0.84))
        out.append((dev, cam, ""))
    return out


def render(spec):
    """render (or reuse) the static layers for `spec`; returns (dir, scene dict)"""
    key = spec_key(spec)
    out_dir = os.path.join(DUO_CACHE, key)
    scene_path = os.path.join(out_dir, "scene.json")
    if os.path.exists(scene_path):
        return out_dir, json.load(open(scene_path))
    os.makedirs(out_dir, exist_ok=True)
    img = Image.new("RGB", (W4 * SS, H4 * SS), vc.CREAM)
    glass = Image.new("RGBA", (W4, H4), (255, 255, 255, 0))
    scene = {"spec": spec, "w": W4, "h": H4, "screens": {}}
    views = views_for(spec)
    for dev, cam, prefix in views:
        draw_device(img, dev, cam)
    for dev, cam, prefix in views:
        for name, s in dev["screens"].items():
            view = cam.C - s["corners"].mean(axis=0)
            if s["normal"] @ view <= 0:
                continue
            quad = cam.project(s["corners"]) / SS
            outline = cam.project(s["outline"]) / SS
            x0 = int(math.floor(outline[:, 0].min())) - 2
            y0 = int(math.floor(outline[:, 1].min())) - 2
            x1 = int(math.ceil(outline[:, 0].max())) + 2
            y1 = int(math.ceil(outline[:, 1].max())) + 2
            x0, y0 = max(0, x0), max(0, y0)
            x1, y1 = min(W4, x1), min(H4, y1)
            bw, bh = (x1 - x0) // 2 * 2, (y1 - y0) // 2 * 2
            m = Image.new("L", (bw * SS, bh * SS), 0)
            ImageDraw.Draw(m).polygon([((p[0] - x0) * SS, (p[1] - y0) * SS) for p in outline], fill=255)
            # occlusion: faces of other parts that sit in front of this screen
            sdepth = np.linalg.norm(cam.C - s["corners"].mean(axis=0))
            occ = Image.new("L", m.size, 0)
            od = ImageDraw.Draw(occ)
            n_occ = 0
            for f in dev["faces"]:
                if f.part == s.get("part"):
                    continue
                c = f.pts.mean(axis=0)
                if f.normal @ (cam.C - c) <= 0 or np.linalg.norm(cam.C - c) >= sdepth:
                    continue
                pp = cam.project(f.pts) / SS
                od.polygon([((q[0] - x0) * SS, (q[1] - y0) * SS) for q in pp], fill=255)
                n_occ += 1
            if n_occ:
                m = Image.fromarray(np.minimum(np.asarray(m), 255 - np.asarray(occ)))
            m = m.resize((bw, bh), Image.LANCZOS)
            sname = prefix + name
            mpath = os.path.join(out_dir, f"mask_{sname}.png")
            m.save(mpath)
            H = homography([(0, 0), (1, 0), (0, 1), (1, 1)], quad)
            # glass sheen: a soft diagonal band + faint top glow, only inside the screen
            yy, xx = np.mgrid[0:bh, 0:bw].astype(np.float32)
            Hi = np.linalg.inv(H)
            X, Y = xx + x0, yy + y0
            den = Hi[2, 0] * X + Hi[2, 1] * Y + Hi[2, 2]
            su = (Hi[0, 0] * X + Hi[0, 1] * Y + Hi[0, 2]) / den
            sv = (Hi[1, 0] * X + Hi[1, 1] * Y + Hi[1, 2]) / den
            band = np.exp(-((0.62 * su + 0.78 * sv - 0.30) / 0.16) ** 2) * 0.055
            glow = np.clip(1 - sv, 0, 1) ** 3 * 0.025
            a = (band + glow) * (np.asarray(m, np.float32) / 255.0)
            layer = np.zeros((bh, bw, 4), np.uint8)
            layer[..., :3] = 255
            layer[..., 3] = np.clip(a * 255, 0, 255).astype(np.uint8)
            glass.alpha_composite(Image.fromarray(layer, "RGBA"), (x0, y0))
            scene["screens"][sname] = {
                "quad": quad.round(3).tolist(), "bbox": [x0, y0, bw, bh], "mask": mpath,
                "px": list(s["px"]), "H": H.tolist(),
            }
    img = img.resize((W4, H4), Image.LANCZOS)
    img.save(os.path.join(out_dir, "body.png"))
    glass.save(os.path.join(out_dir, "glass.png"))
    json.dump(scene, open(scene_path, "w"), indent=1)
    return out_dir, scene


def ui_to_canvas(scene, screen, u, v):
    H = np.array(scene["screens"][screen]["H"])
    p = H @ np.array([u, v, 1.0])
    return p[0] / p[2], p[1] / p[2]


if __name__ == "__main__":
    for spec in ({"pose": "laptop", "view": "front"}, {"pose": "laptop", "view": "front+back"}, {"pose": "book"}):
        d, sc = render(spec)
        print(spec, "->", d, list(sc["screens"]))
