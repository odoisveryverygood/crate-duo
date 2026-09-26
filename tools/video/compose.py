#!/usr/bin/env python3
"""
compose.py -- turn one (or two) simulator screen-recording clips into a
styled 1920x1080@30fps segment for the CRATE demo video: the recording
scaled to fit ~78% of the frame, rounded corners, a soft drop shadow,
centred on the cream canvas, with a keyframed virtual camera (push-in /
pan / ease back out). Output is a PCM-audio .mov (silent audio track) so
segments concat cleanly in assemble.py.

CLI:
  python compose.py --in clip.mp4 --out seg.mov --ss 2 --dur 5 \
      --keys '[{"t":0,"zoom":1,"cx":0.5,"cy":0.5},{"t":3,"zoom":2.2,"cx":0.8,"cy":0.1}]'

  # two screens at once (inner + outer, both floating side by side):
  python compose.py --in inner.mp4 --out seg.mov --ss 0 --dur 4 \
      --keys '[{"t":0,"zoom":1,"cx":0.5,"cy":0.5}]' --second outer.mp4

Also importable: `render(...)` is what assemble.py calls directly so the
real shot list never has to shell out to this script.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc

SOLO_BOX_FRAC = 0.78          # single device fits inside this much of the canvas
PAIR_BOX_W_FRAC = 0.92        # two devices side by side...
PAIR_BOX_H_FRAC = 0.72        # ...fit inside this box
PAIR_GAP_FRAC = 0.035         # gap between the two, as a fraction of canvas width
CORNER_FRAC = 0.025           # rounded-corner radius, as a fraction of device width


def default_keys():
    return [{"t": 0.0, "zoom": 1.0, "cx": 0.5, "cy": 0.5}]


def _device_layer(idx, src, ss, dur, speed, keys, target_w, target_h, crop=None):
    """Return (input_args, filter_lines, out_label) for one recording: trim,
    retime for speed, apply the Ken Burns camera, land on target_w x
    target_h with sharp corners (rounding happens later via the corner
    mask, composited once per device onto the canvas). Ken Burns zoom is
    expressed relative to target_w/target_h (not the source's own pixel
    size), so no ffprobe of `src` is needed here -- see render()'s layout
    step for where the source aspect ratio is actually read."""
    src_dur = dur * speed + 0.5   # small safety pad, trimmed off precisely below
    nframes = round(dur * vc.FPS)
    cam = vc.camera_filter(keys, target_w, target_h, work=2.0)

    chain = ["setpts=PTS-STARTPTS"]
    if crop:
        chain.append(f"crop={crop[2]}:{crop[3]}:{crop[0]}:{crop[1]}")
    if speed != 1.0:
        chain.append(f"setpts=PTS/{speed}")
    chain.append(f"fps={vc.FPS}")            # CFR before the camera: its clock is the frame index
    chain.append(f"scale={2 * target_w}:{2 * target_h}:flags=lanczos")
    chain.append(cam)
    chain.append("format=yuv420p")
    chain.append(f"tpad=stop_mode=clone:stop_duration=2")
    chain.append(f"trim=end_frame={nframes}")
    chain.append("setpts=PTS-STARTPTS")

    in_args = ["-ss", f"{ss}", "-t", f"{src_dur}", "-i", src]
    label = f"dev{idx}"
    filt = f"[{idx}:v]{','.join(chain)}[{label}]"
    return in_args, filt, label


def resolve_crop(clip, crop, t):
    """crop: None | [x,y,w,h] | "lid" | "deck" (inner laptop recording split at the fold)"""
    if crop in ("lid", "deck"):
        import duo_compose
        w, h = vc.probe_size(clip)
        lb, dt = duo_compose.split_rows(clip, t)
        return [0, 0, w, lb] if crop == "lid" else [0, dt, w, h - dt]
    return crop


def render(out, clip, ss, dur, keys=None, speed=1.0, second=None,
           second_ss=None, second_dur=None, second_speed=None, second_keys=None,
           crop=None, second_crop=None, box=None, radius=None):
    """Render one styled segment to `out` (.mov, PCM audio, silent).
    crop: source region ([x,y,w,h] or "lid"/"deck"); box: solo box fraction
    of the canvas (default 0.78; 0.9 = the big legible v3 treatment)."""
    keys = keys or default_keys()
    crop = resolve_crop(clip, crop, ss + dur / 2)
    second_crop = resolve_crop(second, second_crop, ss + dur / 2) if second else None
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)

    devices = []  # (input_args, filter_line, label, (iw, ih))
    if second:
        second_ss = ss if second_ss is None else second_ss
        second_dur = dur if second_dur is None else second_dur
        second_speed = speed if second_speed is None else second_speed
        second_keys = second_keys or default_keys()

    # --- layout: compute each device's on-canvas box size -------------------
    iw0, ih0 = (crop[2], crop[3]) if crop else vc.probe_size(clip)
    if second:
        iw1, ih1 = (second_crop[2], second_crop[3]) if second_crop else vc.probe_size(second)
        pair_w = vc.CANVAS_W * PAIR_BOX_W_FRAC
        pair_h = vc.CANVAS_H * PAIR_BOX_H_FRAC
        gap = vc.CANVAS_W * PAIR_GAP_FRAC
        # fit both to a common height, then shrink uniformly if too wide
        h = pair_h
        w0, w1 = h * iw0 / ih0, h * iw1 / ih1
        total_w = w0 + gap + w1
        if total_w > pair_w:
            s = pair_w / total_w
            h *= s; w0 *= s; w1 *= s; gap *= s
        w0, h0 = vc.even(w0), vc.even(h)
        w1, h1 = vc.even(w1), vc.even(h)
        group_w = w0 + gap + w1
        x0 = (vc.CANVAS_W - group_w) / 2
        x1 = x0 + w0 + gap
        y0 = (vc.CANVAS_H - h0) / 2
        y1 = (vc.CANVAS_H - h1) / 2
        boxes = [(clip, ss, dur, speed, keys, w0, h0, x0, y0, crop),
                 (second, second_ss, second_dur, second_speed, second_keys, w1, h1, x1, y1, second_crop)]
    else:
        box_w = vc.CANVAS_W * (box or SOLO_BOX_FRAC)
        box_h = vc.CANVAS_H * (box or SOLO_BOX_FRAC)
        w0, h0 = vc.fit_box(iw0, ih0, box_w, box_h)
        x0 = (vc.CANVAS_W - w0) / 2
        y0 = (vc.CANVAS_H - h0) / 2
        boxes = [(clip, ss, dur, speed, keys, w0, h0, x0, y0, crop)]

    # --- ffmpeg graph --------------------------------------------------------
    inputs = ["-f", "lavfi", "-i", f"color=c={vc.CREAM_HEX}:s={vc.CANVAS_W}x{vc.CANVAS_H}:r={vc.FPS}:d={dur}"]
    filt = []
    overlay_chain = "[0:v]"
    next_idx = 1
    for src, s_ss, s_dur, s_speed, s_keys, w, h, x, y, s_crop in boxes:
        in_args, dfilt, label = _device_layer(next_idx, src, s_ss, s_dur, s_speed, s_keys, int(w), int(h), crop=s_crop)
        inputs += in_args
        filt.append(dfilt)
        next_idx += 1

        rad = max(2, round((radius or CORNER_FRAC) * w))
        shadow_path, pad = vc.drop_shadow_png(int(w), int(h), rad, cache_key=f"shadow_{int(w)}x{int(h)}_{rad}")
        mask_path = vc.corner_mask_png(int(w), int(h), rad, cache_key=f"corner_{int(w)}x{int(h)}_{rad}")

        inputs += ["-loop", "1", "-t", f"{dur}", "-i", shadow_path]
        shadow_idx = next_idx; next_idx += 1
        inputs += ["-loop", "1", "-t", f"{dur}", "-i", mask_path]
        mask_idx = next_idx; next_idx += 1

        sx, sy = int(x - pad), int(y - pad)
        ox, oy = int(x), int(y)
        shadow_lbl = f"shbg{shadow_idx}"
        dev_lbl = f"devbg{shadow_idx}"
        mask_lbl = f"maskbg{shadow_idx}"
        filt.append(f"[{shadow_idx}:v]format=rgba,fps={vc.FPS}[{shadow_lbl}]")
        filt.append(f"[{mask_idx}:v]format=rgba,fps={vc.FPS}[{mask_lbl}]")
        filt.append(f"{overlay_chain}[{shadow_lbl}]overlay={sx}:{sy}:shortest=0[{dev_lbl}a]")
        filt.append(f"[{dev_lbl}a][{label}]overlay={ox}:{oy}:shortest=0[{dev_lbl}b]")
        filt.append(f"[{dev_lbl}b][{mask_lbl}]overlay={ox}:{oy}:shortest=0[{dev_lbl}]")
        overlay_chain = f"[{dev_lbl}]"

    final_v = "vout"
    filt.append(f"{overlay_chain}format=yuv420p[{final_v}]")

    inputs += vc.silent_audio_args(dur)

    cmd = ["ffmpeg", "-v", "error", "-y"] + inputs + [
        "-filter_complex", ";".join(filt),
        "-map", f"[{final_v}]", "-map", f"{next_idx}:a",
        "-r", str(vc.FPS),
    ] + vc.VCODEC_MOV + vc.ACODEC_PCM + ["-shortest", out]
    vc.sh(cmd)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--in", dest="clip", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ss", type=float, default=0.0)
    ap.add_argument("--dur", type=float, required=True)
    ap.add_argument("--to", type=float, default=None, help="alternative to --dur: absolute out point in the source")
    ap.add_argument("--speed", type=float, default=1.0)
    ap.add_argument("--keys", type=str, default=None, help="JSON list of {t,zoom,cx,cy}")
    ap.add_argument("--second", type=str, default=None, help="optional 2nd recording, shown side by side")
    ap.add_argument("--second-ss", type=float, default=None)
    ap.add_argument("--second-dur", type=float, default=None)
    ap.add_argument("--second-speed", type=float, default=None)
    ap.add_argument("--second-keys", type=str, default=None)
    args = ap.parse_args()

    dur = args.dur if args.to is None else (args.to - args.ss) / args.speed
    keys = json.loads(args.keys) if args.keys else None
    second_keys = json.loads(args.second_keys) if args.second_keys else None

    render(args.out, args.clip, args.ss, dur, keys=keys, speed=args.speed,
           second=args.second, second_ss=args.second_ss, second_dur=args.second_dur,
           second_speed=args.second_speed, second_keys=second_keys)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
