#!/usr/bin/env python3
"""
duo_anim.py -- the iPhone Duo model with a MOVING hinge (the fold / snap-open
DROP), rendered frame by frame: every output frame re-poses the 3D model at
that frame's lid angle, re-projects it with that frame's camera (zoom/cx/cy
applied to the projection itself: exact float math, no resampling, no shake),
draws the body (Pillow, 3840x2160), warps the recording's lid/deck halves
onto the projected screen quads (numpy inverse-homography bilinear sampling,
rounded-corner masks, occlusion by the closing lid), then downsamples to
1920x1080. Chunks of frames render in parallel worker processes, each with its
own ffmpeg decoder and encoder; the chunks are concatenated.

Shot JSON (assemble.py "type":"device_anim"):
  {"type":"device_anim", "id":"fold", "device":{"pose":"laptop","view":"front","az":9},
   "clip":"clips/songB_inner_up.mov", "ss":40.0, "dur":16.6,
   "open_keys":[{"t":0,"deg":110},{"t":15.0,"deg":30},{"t":16.4,"deg":30},{"t":16.55,"deg":110}],
   "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":16.6,"zoom":1.25,"cx":0.5,"cy":0.55}],
   "screens":{"lid":{"crop":"lid"},"deck":{"crop":"deck"}}, "audio":"app"}
"""
import json
import math
import os
import subprocess
import sys
import tempfile
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc
import duo_model as dm

W4, H4 = 2880, 1620          # render canvas (1.5x the 1920x1080 output = antialiasing)


def smooth(keys, field, t, ease=True):
    ks = sorted(keys, key=lambda k: k["t"])
    if t <= ks[0]["t"]:
        return ks[0][field]
    for a, b in zip(ks, ks[1:]):
        if t <= b["t"]:
            p = (t - a["t"]) / max(1e-9, b["t"] - a["t"])
            s = p * p * (3 - 2 * p) if ease else p
            return a[field] + (b[field] - a[field]) * s
    return ks[-1][field]


def base_camera(spec):
    tgt = (0.0, 1.05, 0.85)
    ref = dm.laptop_device(spec.get("ref_open", 110.0))
    cam = dm.Cam(dm.orbit(tgt, 40, spec.get("el", 27), spec.get("az", 0)), tgt)
    cam.fit(ref["all_pts"], (0, 0, W4, H4), spec.get("fill", 0.84))
    return cam


def frame_camera(cam0, keys, t):
    z = smooth(keys, "zoom", t)
    cxn = smooth(keys, "cx", t)
    cyn = smooth(keys, "cy", t)
    x0 = min(max(cxn * W4 - W4 / (2 * z), 0), W4 - W4 / z)
    y0 = min(max(cyn * H4 - H4 / (2 * z), 0), H4 - H4 / z)
    cam = dm.Cam.__new__(dm.Cam)
    cam.C, cam.f, cam.r, cam.u = cam0.C, cam0.f, cam0.r, cam0.u
    cam.F = cam0.F * z
    cam.cx = (cam0.cx - x0) * z
    cam.cy = (cam0.cy - y0) * z
    return cam


def warp_into(canvas, mask, off, src, quad):
    """bilinear-sample src (h,w,3 uint8) through the homography unit-square->quad
    into canvas (H,W,3 uint8) inside the bbox at off=(x0,y0) where mask (bbox-sized
    float32 0..1) > 0"""
    x0, y0 = off
    H = dm.homography([(0, 0), (1, 0), (0, 1), (1, 1)], quad)
    Hi = np.linalg.inv(H)
    ys, xs = np.nonzero(mask > 0.002)
    if len(xs) == 0:
        return
    X = xs.astype(np.float32) + (x0 + 0.5)
    Y = ys.astype(np.float32) + (y0 + 0.5)
    den = Hi[2, 0] * X + Hi[2, 1] * Y + Hi[2, 2]
    u = (Hi[0, 0] * X + Hi[0, 1] * Y + Hi[0, 2]) / den
    v = (Hi[1, 0] * X + Hi[1, 1] * Y + Hi[1, 2]) / den
    sh, sw = src.shape[:2]
    fx = np.clip(u * sw - 0.5, 0, sw - 1.001)
    fy = np.clip(v * sh - 0.5, 0, sh - 1.001)
    ix = fx.astype(np.int32)
    iy = fy.astype(np.int32)
    ax = (fx - ix)[:, None]
    ay = (fy - iy)[:, None]
    c00 = src[iy, ix].astype(np.float32)
    c10 = src[iy, ix + 1].astype(np.float32)
    c01 = src[iy + 1, ix].astype(np.float32)
    c11 = src[iy + 1, ix + 1].astype(np.float32)
    col = (c00 * (1 - ax) + c10 * ax) * (1 - ay) + (c01 * (1 - ax) + c11 * ax) * ay
    a = mask[ys, xs][:, None]
    gy, gx = ys + y0, xs + x0
    base = canvas[gy, gx].astype(np.float32)
    canvas[gy, gx] = np.clip(base * (1 - a) + col * a, 0, 255).astype(np.uint8)


def render_frame(dev, cam, halves, outer_img=None):
    img = Image.new("RGB", (W4, H4), vc.CREAM)
    old_ss = dm.SS
    dm.SS = 1
    try:
        dm.draw_device(img, dev, cam, shadow=True)
    finally:
        dm.SS = old_ss
    canvas = np.array(img)
    for name, s in dev["screens"].items():
        src = halves.get(name) if name != "outer" else outer_img
        if src is None:
            continue
        view = cam.C - s["corners"].mean(axis=0)
        if s["normal"] @ view <= 0:
            continue
        quad = cam.project(s["corners"])
        outline = cam.project(s["outline"])
        bx0 = max(0, int(math.floor(outline[:, 0].min())) - 1)
        by0 = max(0, int(math.floor(outline[:, 1].min())) - 1)
        bx1 = min(W4, int(math.ceil(outline[:, 0].max())) + 1)
        by1 = min(H4, int(math.ceil(outline[:, 1].max())) + 1)
        if bx1 <= bx0 or by1 <= by0:
            continue
        bw, bh = bx1 - bx0, by1 - by0
        m = Image.new("L", (bw, bh), 0)
        ImageDraw.Draw(m).polygon([(p[0] - bx0, p[1] - by0) for p in outline], fill=255)
        sdepth = np.linalg.norm(view)
        occ = None
        for f in dev["faces"]:
            if f.part == s.get("part"):
                continue
            c = f.pts.mean(axis=0)
            if f.normal @ (cam.C - c) <= 0 or np.linalg.norm(cam.C - c) >= sdepth:
                continue
            pp = cam.project(f.pts)
            if pp[:, 0].max() < bx0 or pp[:, 0].min() > bx1 or pp[:, 1].max() < by0 or pp[:, 1].min() > by1:
                continue
            if occ is None:
                occ = Image.new("L", (bw, bh), 0)
                od = ImageDraw.Draw(occ)
            od.polygon([(q[0] - bx0, q[1] - by0) for q in pp], fill=255)
        ma = np.asarray(m, np.float32) / 255.0
        if occ is not None:
            ma = ma * (1 - np.asarray(occ, np.float32) / 255.0)
        warp_into(canvas, ma, (bx0, by0), src, quad)
    return Image.fromarray(canvas).resize((vc.CANVAS_W, vc.CANVAS_H), Image.LANCZOS)


def _chunk(args):
    (i0, i1, shot, clip, crops, outer_clip, outer_ss, outer_fit, path) = args
    fps = vc.FPS
    spec = shot.get("device", {"pose": "laptop", "view": "front"})
    cam0 = base_camera(spec)
    keys = shot.get("keys") or [{"t": 0, "zoom": 1.0, "cx": 0.5, "cy": 0.5}]
    okeys = shot.get("open_keys") or [{"t": 0, "deg": 110}]
    ss = float(shot.get("ss", 0.0))
    sw, sh = vc.probe_size(clip)
    n = i1 - i0
    dec = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", f"{ss + i0 / fps:.4f}", "-i", clip, "-frames:v", str(n + 2),
                            "-vf", f"fps={fps}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    odec = None
    if outer_clip:
        ow, oh = vc.probe_size(outer_clip)
        pw, ph = dm.OUT_PX
        vf = f"fps={fps}"
        if outer_fit == "letterbox":
            vf += f",scale={pw}:{ph}:force_original_aspect_ratio=decrease,pad={pw}:{ph}:(ow-iw)/2:(oh-ih)/2:black"
        else:
            vf += f",scale={pw}:{ph}"
        odec = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", f"{outer_ss + i0 / fps:.4f}", "-i", outer_clip,
                                 "-frames:v", str(n + 2), "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                                stdout=subprocess.PIPE)
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s",
                            f"{vc.CANVAS_W}x{vc.CANVAS_H}", "-framerate", str(fps), "-i", "-"] + vc.VCODEC_MOV + ["-an", path],
                           stdin=subprocess.PIPE)
    fsz = sw * sh * 3
    last = None
    olast = None
    for i in range(i0, i1):
        buf = dec.stdout.read(fsz)
        if len(buf) == fsz:
            last = np.frombuffer(buf, np.uint8).reshape(sh, sw, 3)
        fr = last
        halves = {}
        if fr is not None:
            for name, (x, y, w, h) in crops.items():
                halves[name] = fr[y:y + h, x:x + w]
        oimg = None
        if odec:
            pw, ph = dm.OUT_PX
            ob = odec.stdout.read(pw * ph * 3)
            if len(ob) == pw * ph * 3:
                olast = np.frombuffer(ob, np.uint8).reshape(ph, pw, 3)
            oimg = olast
        t = i / fps
        dev = dm.laptop_device(smooth(okeys, "deg", t, ease=shot.get("open_ease", True)))
        cam = frame_camera(cam0, keys, t)
        enc.stdin.write(render_frame(dev, cam, halves, oimg).tobytes())
    enc.stdin.close()
    enc.wait()
    dec.kill()
    if odec:
        odec.kill()
    return path


def render(out, shot, resolve, workers=None):
    import duo_compose
    clip = resolve(shot["clip"])
    dur = float(shot["dur"])
    nf = round(dur * vc.FPS)
    ss = float(shot.get("ss", 0.0))
    sw, sh = vc.probe_size(clip)
    crops = {}
    for name, sc in (shot.get("screens") or {"lid": {"crop": "lid"}, "deck": {"crop": "deck"}}).items():
        if name == "outer":
            continue
        c = sc.get("crop", "full")
        if c in ("lid", "deck"):
            lb, dt = duo_compose.split_rows(clip, ss + min(dur, 6.0) / 2)
            c = [0, 0, sw, lb] if c == "lid" else [0, dt, sw, sh - dt]
        elif c == "full":
            c = [0, 0, sw, sh]
        crops[name] = c
    osc = (shot.get("screens") or {}).get("outer")
    outer_clip = resolve(osc["clip"]) if osc else None
    outer_ss = float(osc.get("ss", 0.0)) if osc else 0.0
    outer_fit = osc.get("fit", "stretch") if osc else None
    workers = workers or max(2, min(10, (os.cpu_count() or 8) - 2))
    step = math.ceil(nf / workers)
    tmp = tempfile.mkdtemp(prefix="duoanim_")
    jobs = []
    for k, i0 in enumerate(range(0, nf, step)):
        jobs.append((i0, min(nf, i0 + step), shot, clip, crops, outer_clip, outer_ss, outer_fit,
                     os.path.join(tmp, f"c{k:03d}.mov")))
    with Pool(len(jobs)) as pool:
        parts = pool.map(_chunk, jobs)
    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w") as f:
        for p in parts:
            f.write(f"file '{p}'\n")
    joined = os.path.join(tmp, "joined.mov")
    vc.sh(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined])
    vc.sh(["ffmpeg", "-v", "error", "-y", "-i", joined] + vc.silent_audio_args(dur) +
          ["-map", "0:v", "-map", "1:a", "-vf", f"fps={vc.FPS},format=yuv420p,tpad=stop_mode=clone:stop_duration=2,"
           f"trim=end_frame={nf},setpts=PTS-STARTPTS", "-r", str(vc.FPS)] + vc.VCODEC_MOV + vc.ACODEC_PCM + ["-shortest", out])
    return out


if __name__ == "__main__":
    shot = json.loads(sys.argv[1])
    render(sys.argv[2], shot, lambda p: p if os.path.isabs(p) else os.path.join(vc.DEMO, p))
    print("wrote", sys.argv[2])
