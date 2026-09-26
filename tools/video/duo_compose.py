#!/usr/bin/env python3
"""
duo_compose.py -- map simulator footage onto the procedural iPhone Duo
(duo_model.py) and film it with a keyframed virtual camera.

Per frame (ffmpeg only, no OpenCV): each screen's source is cropped from its
recording (the inner display is split at the fold: lid half / deck half),
scaled to the screen's bounding box, warped with `perspective`
(sense=destination) onto the projected screen quad, alpha-masked with the
rounded screen shape (occlusion included), overlaid on the 4K body render,
then the glass sheen goes on top. The camera (zoom/cx/cy keys, smoothstep
eased) crops the 3840x2160 composite down to 1920x1080, so a 2.5x push-in
still samples ~1:1 source pixels.

Shot JSON (assemble.py "type":"device"):
  {"type":"device", "id":"pads", "device":{"pose":"laptop","view":"front"},
   "clip":"clips/take1_inner_up.mov", "ss":12.0, "dur":5.0,
   "screens":{"lid":{"crop":"lid"}, "deck":{"crop":"deck"},
              "outer":{"clip":"clips/take3_outer_up.mov","ss":0.4,"fit":"letterbox"}},
   "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},
           {"t":3,"zoom":2.2,"screen":"lid","u":0.84,"v":0.06}],
   "audio":"app"}
  keys may aim at a screen point: "screen" + "u","v" in 0..1 UI coords of that screen.
  screens[*]: clip/ss (default: the shot's), crop ("lid"|"deck"|"full"|[x,y,w,h]),
              rotate (0|90|-90|180), fit ("stretch"|"letterbox").
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc
import duo_model

_split_cache = {}


def split_rows(clip, t):
    """(lid_bottom, deck_top) rows of an upright laptop-layout inner recording.
    The 40 pt division is black; the deck's first non-black row marks its top."""
    key = (clip, round(t, 1))
    if key in _split_cache:
        return _split_cache[key]
    w, h = vc.probe_size(clip)
    gap = round(h * 120 / 2852)
    res = ((h - gap) // 2, (h + gap) // 2)
    try:
        raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t}", "-i", clip, "-frames:v", "1",
                              "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True).stdout
        a = np.frombuffer(raw, np.uint8).reshape(h, w)
        rowmax = np.percentile(a[:, 60:], 99.5, axis=1)
        mid = h // 2
        if rowmax[mid] < 24:
            r1 = mid
            while r1 < h and rowmax[r1] < 24:
                r1 += 1
            lid_bottom = r1 - gap
            if abs(lid_bottom - (h - r1)) <= 10:
                res = (lid_bottom, r1)
    except Exception:
        pass
    _split_cache[key] = res
    return res


def resolve_keys(keys, scene):
    out = []
    for k in keys or [{"t": 0, "zoom": 1.0, "cx": 0.5, "cy": 0.5}]:
        k = dict(k)
        if "screen" in k:
            X, Y = duo_model.ui_to_canvas(scene, k["screen"], k.get("u", 0.5), k.get("v", 0.5))
            k["cx"], k["cy"] = X / scene["w"], Y / scene["h"]
        k.setdefault("cx", 0.5)
        k.setdefault("cy", 0.5)
        out.append({"t": k["t"], "zoom": k["zoom"], "cx": round(k["cx"], 5), "cy": round(k["cy"], 5)})
    return out


def render(out, shot, resolve):
    """resolve: callable(path) -> absolute path (assemble's resolver)"""
    spec = shot.get("device", {"pose": "laptop", "view": "front"})
    ddir, scene = duo_model.render(spec)
    dur = float(shot["dur"])
    nf = round(dur * vc.FPS)
    screens = shot.get("screens", {"lid": {"crop": "lid"}, "deck": {"crop": "deck"}})

    inputs = ["-framerate", str(vc.FPS), "-i", os.path.join(ddir, "body.png"),
              "-framerate", str(vc.FPS), "-i", os.path.join(ddir, "glass.png")]
    filt = [f"[0:v]loop=loop=-1:size=1:start=0,setpts=N/{vc.FPS}/TB,format=yuv444p[base0]",
            f"[1:v]loop=loop=-1:size=1:start=0,setpts=N/{vc.FPS}/TB,format=rgba[glass]"]
    idx = 2
    # distinct sources
    plan = []
    for name, sc in screens.items():
        if name not in scene["screens"]:
            continue
        clip = resolve(sc.get("clip", shot["clip"]))
        ss = float(sc.get("ss", shot.get("ss", 0.0)))
        plan.append((name, sc, clip, ss))
    srcs = {}
    for name, sc, clip, ss in plan:
        srcs.setdefault((clip, ss), []).append(name)
    src_label = {}
    for (clip, ss), names in srcs.items():
        inputs += ["-ss", f"{ss}", "-t", f"{dur + 0.6}", "-i", clip]
        labels = [f"s{idx}_{i}" for i in range(len(names))]
        filt.append(f"[{idx}:v]setpts=PTS-STARTPTS,fps={vc.FPS},format=yuv444p,split={len(names)}" + "".join(f"[{l}]" for l in labels))
        for n_, l in zip(names, labels):
            src_label[n_] = l
        idx += 1

    base = "base0"
    for k, (name, sc, clip, ss) in enumerate(plan):
        info = scene["screens"][name]
        x0, y0, bw, bh = info["bbox"]
        pw, ph = info["px"]
        sw, sh = vc.probe_size(clip)
        crop = sc.get("crop", "full")
        if crop in ("lid", "deck"):
            lb, dt = split_rows(clip, ss + min(dur, 6.0) / 2)
            crop = [0, 0, sw, lb] if crop == "lid" else [0, dt, sw, sh - dt]
        elif crop == "full":
            crop = [0, 0, sw, sh]
        cx_, cy_, cw, ch = crop
        chain = [f"crop={cw}:{ch}:{cx_}:{cy_}"]
        rot = sc.get("rotate", 0)
        if rot == 90:
            chain.append("transpose=1")
        elif rot == -90:
            chain.append("transpose=2")
        elif rot == 180:
            chain.append("hflip,vflip")
        if sc.get("fit") == "letterbox":
            chain.append(f"scale={pw}:{ph}:force_original_aspect_ratio=decrease:flags=lanczos")
            chain.append(f"pad={pw}:{ph}:(ow-iw)/2:(oh-ih)/2:black")
        q = [(px - x0, py - y0) for px, py in info["quad"]]
        chain.append(f"scale={bw}:{bh}:flags=lanczos")
        chain.append("format=yuv444p")
        chain.append("perspective=" + ":".join(f"{v:.3f}" for p in q for v in p) + ":interpolation=linear:sense=destination")
        chain.append("format=yuva444p")
        filt.append(f"[{src_label[name]}]{','.join(chain)}[w{k}]")
        inputs += ["-framerate", str(vc.FPS), "-i", info["mask"]]
        filt.append(f"[{idx}:v]loop=loop=-1:size=1:start=0,setpts=N/{vc.FPS}/TB,format=gray[m{k}]")
        idx += 1
        filt.append(f"[w{k}][m{k}]alphamerge[a{k}]")
        filt.append(f"[{base}][a{k}]overlay={x0}:{y0}:format=yuv444:eof_action=repeat[b{k}]")
        base = f"b{k}"

    keys = resolve_keys(shot.get("keys"), scene)
    cam = vc.camera_filter(keys, vc.CANVAS_W, vc.CANVAS_H, work=2.0)   # composite is 3840x2160
    filt.append(f"[{base}][glass]overlay=0:0:format=yuv444,{cam},fps={vc.FPS},format=yuv420p,"
                f"tpad=stop_mode=clone:stop_duration=2,trim=end_frame={nf},setpts=PTS-STARTPTS[vout]")
    inputs += vc.silent_audio_args(dur)
    cmd = ["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(filt),
                                                     "-map", "[vout]", "-map", f"{idx}:a", "-r", str(vc.FPS)] + \
        vc.VCODEC_MOV + vc.ACODEC_PCM + ["-shortest", out]
    vc.sh(cmd)
    return out


if __name__ == "__main__":
    shot = json.loads(sys.argv[1])
    here = os.path.join(vc.DEMO)
    render(sys.argv[2], shot, lambda p: p if os.path.isabs(p) else os.path.join(vc.DEMO, p))
    print("wrote", sys.argv[2])
