#!/usr/bin/env python3
"""
assemble.py -- shot list JSON (+ a music plan) -> final CRATE demo mp4
(H.264 High, 1920x1080@30, AAC 192k), a/v durations sample-accurate.

CLI:
  python assemble.py shotlist.json --out demo/test_render.mp4
  python assemble.py shotlist.json --music demo/music/plan.json --out out.mp4

shotlist.json:
{
  "w": 1920, "h": 1080, "fps": 30,
  "shots": [
    {"type":"image", "id":"title", "path":"cards/title.png", "dur":3.5,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5}]},

    {"type":"clip", "id":"pads", "clip":"clips/test_inner.mp4",
     "ss":5, "dur":6, "speed":1.0,
     "keys":[{"t":0,"zoom":1,"cx":0.5,"cy":0.5},{"t":4.5,"zoom":1.9,"cx":0.75,"cy":0.47}],
     "second": null,
     "audio":"app", "gain_db":0, "fade_in":0.08, "fade_out":0.08},

    {"type":"video", "id":"endtyped", "path":"cards/end_typed.mov"}
  ],
  "music": [
    {"file":"music/horn.wav", "at":0.0, "track_in":0.0, "dur":20.0,
     "gain_db":-14, "fade_in":0.3, "fade_out":1.5}
  ],
  "ducks": [ {"at":5.0, "dur":1.0, "gain_db":-100} ]
}

`shots[].id` is optional but lets other tools refer back to a shot's
timeline position; every shot's *own* `at` on the final timeline is
derived automatically from cumulative durations -- you never hand-enter
it (that's how vlogcut's render.py avoids drift too).

Every shot, regardless of type, is rendered to a cached silent-PCM
1920x1080@30 .mov of an exact frame count first (see vidcommon / compose
for why: silent audio everywhere means concat is a plain stream copy).
Real audio (song + each clip's own on-screen sound) is mixed back in as a
separate pass over the ORIGINAL source files, positioned by the timeline
this step computes -- never from the styled segment's own audio.
"""
import argparse
import csv
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc
import compose

SEG_CACHE = os.path.join(vc.CACHE, "shots")
os.makedirs(SEG_CACHE, exist_ok=True)


def resolve(here, path):
    if os.path.isabs(path):
        return path
    for base in (here, vc.DEMO):
        p = os.path.join(base, path)
        if os.path.exists(p):
            return p
    return os.path.join(here, path)


# ---------------------------------------------------------- per-shot render --
def render_image_or_video(shot, here, out_path):
    path = resolve(here, shot["path"])
    keys = shot.get("keys")
    dur = shot.get("dur")

    if dur is None:
        dur = vc.probe_duration(path)
    nframes = round(dur * vc.FPS)
    kb = vc.kenburns_filter(keys or [{"t": 0, "zoom": 1.0, "cx": 0.5, "cy": 0.5}], vc.CANVAS_W, vc.CANVAS_H)

    if shot["type"] == "image":
        in_args = ["-loop", "1", "-t", f"{dur + 0.5}", "-i", path]
    else:
        in_args = ["-t", f"{dur + 0.5}", "-i", path]

    vf = f"{kb},fps={vc.FPS},format=yuv420p,tpad=stop_mode=clone:stop_duration=2,trim=end_frame={nframes},setpts=PTS-STARTPTS"
    cmd = (["ffmpeg", "-v", "error", "-y"] + in_args + vc.silent_audio_args(dur) +
           ["-filter_complex", f"[0:v]{vf}[v]", "-map", "[v]", "-map", "1:a", "-r", str(vc.FPS)] +
           vc.VCODEC_MOV + vc.ACODEC_PCM + ["-shortest", out_path])
    vc.sh(cmd)
    return out_path


def render_clip(shot, here, out_path):
    keys = shot.get("keys")
    second = shot.get("second")
    compose.render(
        out_path,
        resolve(here, shot["clip"]),
        shot.get("ss", 0.0),
        shot["dur"],
        keys=keys,
        speed=shot.get("speed", 1.0),
        second=resolve(here, second) if second else None,
        second_ss=shot.get("second_ss"),
        second_dur=shot.get("second_dur"),
        second_speed=shot.get("second_speed"),
        second_keys=shot.get("second_keys"),
    )
    return out_path


def render_shot(shot, here):
    key = {k: v for k, v in shot.items() if k not in ("id", "audio", "gain_db", "fade_in", "fade_out")}
    out_path = vc.cache_path("shot", key, ".mov")
    if os.path.exists(out_path):
        return out_path
    tmp = out_path + ".tmp.mov"
    if shot["type"] == "clip":
        render_clip(shot, here, tmp)
    else:
        render_image_or_video(shot, here, tmp)
    ov = shot.get("overlay")
    if ov:
        # optional transparent overlay (e.g. the hinge-angle diagram), composited
        # onto the finished 1920x1080 segment; the segment keeps its exact length.
        tmp2 = out_path + ".tmp2.mov"
        vc.sh(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-i", resolve(here, ov["path"]),
               "-filter_complex", f"[1:v]format=rgba,setpts=PTS-STARTPTS[o];[0:v][o]overlay={ov.get('x', 0)}:{ov.get('y', 0)}:eof_action=pass,format=yuv420p[v]",
               "-map", "[v]", "-map", "0:a", "-r", str(vc.FPS)] + vc.VCODEC_MOV + ["-c:a", "copy", tmp2])
        os.replace(tmp2, tmp)
    fk = shot.get("frame_keys")
    if fk:
        # optional camera over the WHOLE composited frame (cream included), e.g. a
        # slow push on the two-screen layout; compose's own keys zoom inside the box.
        tmp3 = out_path + ".tmp3.mov"
        n = round(vc.probe_duration(tmp) * vc.FPS)
        kb = vc.kenburns_filter(fk, vc.CANVAS_W, vc.CANVAS_H)
        vc.sh(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-filter_complex",
               f"[0:v]{kb},fps={vc.FPS},format=yuv420p,trim=end_frame={n},setpts=PTS-STARTPTS[v]",
               "-map", "[v]", "-map", "0:a", "-r", str(vc.FPS)] + vc.VCODEC_MOV + ["-c:a", "copy", tmp3])
        os.replace(tmp3, tmp)
    os.replace(tmp, out_path)
    return out_path


# --------------------------------------------------------------- audio plan --
def atempo_chain(speed):
    parts, sp = [], speed
    while sp > 2.0:
        parts.append("atempo=2.0"); sp /= 2.0
    while sp < 0.5:
        parts.append("atempo=0.5"); sp *= 2.0
    if sp != 1.0:
        parts.append(f"atempo={sp}")
    return parts


def app_audio_chain(idx, shot, here, at, out_dur):
    src = resolve(here, shot["clip"])
    speed = shot.get("speed", 1.0)
    ss = shot.get("ss", 0.0)
    src_dur = out_dur * speed
    gain = shot.get("gain_db", 0.0)
    fi = shot.get("fade_in", 0.08)
    fo = shot.get("fade_out", 0.08)
    nsamp = round(out_dur * 48000)
    if not vc.has_audio(src):
        return None, None, None
    body = ["asetpts=PTS-STARTPTS"] + atempo_chain(speed) + [
        "apad", f"atrim=end_sample={nsamp}", "asetpts=PTS-STARTPTS",
        f"volume={gain}dB",
        f"afade=t=in:d={fi}", f"afade=t=out:st={max(0, out_dur - fo):.3f}:d={fo}",
        f"adelay={int(at * 1000)}|{int(at * 1000)}",
    ]
    label = f"app{idx}"
    return ["-ss", f"{ss}", "-t", f"{src_dur:.6f}", "-i", src], f"[{idx}:a]{','.join(body)}[{label}]", label


def music_chain(idx, m, here, total_dur, ducks):
    dur = m.get("dur")
    at = m.get("at", 0.0)
    if dur is None:
        dur = total_dur - at
    dur = min(dur, total_dur - at)
    gain = m.get("gain_db", -14.0)
    fi = m.get("fade_in", 0.5)
    fo = m.get("fade_out", 1.5)
    body = [f"atrim=start={m.get('track_in', 0.0)}:duration={dur:.6f}", "asetpts=PTS-STARTPTS",
            f"volume={gain}dB", f"afade=t=in:d={fi}", f"afade=t=out:st={max(0, dur - fo):.3f}:d={fo}"]
    for dk in ducks:
        d_at = dk["at"] - at
        body.append(f"volume={dk.get('gain_db', -100)}dB:enable='between(t,{d_at:.3f},{d_at + dk['dur']:.3f})'")
    body.append(f"adelay={int(at * 1000)}|{int(at * 1000)}")
    label = f"music{idx}"
    return ["-i", resolve(here, m["file"])], f"[{idx}:a]{','.join(body)}[{label}]", label


# -------------------------------------------------------------------- main --
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("shotlist")
    ap.add_argument("--out", required=True)
    ap.add_argument("--music", default=None, help="optional separate music-plan JSON (list, or {'music':[...]})")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(args.shotlist))
    cfg = json.load(open(args.shotlist))
    cfg.setdefault("w", vc.CANVAS_W); cfg.setdefault("h", vc.CANVAS_H); cfg.setdefault("fps", vc.FPS)

    if args.music:
        mcfg = json.load(open(args.music))
        cfg["music"] = mcfg["music"] if isinstance(mcfg, dict) and "music" in mcfg else mcfg

    # 1. render every shot to a cached, frame-exact, silent-PCM segment ------
    segs, timeline, t = [], [], 0.0
    for i, shot in enumerate(cfg["shots"]):
        p = render_shot(shot, here)
        d = vc.probe_duration(p)
        timeline.append({"i": i, "id": shot.get("id", ""), "type": shot["type"],
                          "start": round(t, 6), "dur": round(d, 6), "shot": shot})
        segs.append(p)
        t += d
    total_dur = round(t, 6)
    total_frames = round(total_dur * vc.FPS)
    print(f"{len(segs)} shots, {total_dur:.3f}s total ({total_frames} frames @ {vc.FPS}fps)")

    # 2. concat (all segments share one exact codec spec -> plain stream copy)
    list_path = os.path.join(SEG_CACHE, "concat_list.txt")
    with open(list_path, "w") as f:
        for p in segs:
            f.write(f"file '{p}'\n")
    base = os.path.join(SEG_CACHE, "base.mov")
    vc.sh(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy", base])

    # 3. audio: silent base (exact-duration anchor) + music + per-shot "app" -
    inputs = ["-i", base]
    fc = []
    amix_in = ["[0:a]"]
    idx = 1
    for tl in timeline:
        shot = tl["shot"]
        if shot.get("audio") == "app":
            in_args, chain, label = app_audio_chain(idx, shot, here, tl["start"], tl["dur"])
            if chain is None:
                print(f"warning: shot {tl['id'] or tl['i']} wants app audio but its clip has no audio track")
                continue
            inputs += in_args
            fc.append(chain)
            amix_in.append(f"[{label}]")
            idx += 1

    ducks = cfg.get("ducks", [])
    for m in cfg.get("music", []):
        in_args, chain, label = music_chain(idx, m, here, total_dur, ducks)
        inputs += in_args
        fc.append(chain)
        amix_in.append(f"[{label}]")
        idx += 1

    fc.append("".join(amix_in) + f"amix=inputs={len(amix_in)}:duration=first:normalize=0,alimiter=limit=0.95[aout]")

    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    cmd = (["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(fc),
           "-map", "0:v", "-map", "[aout]", "-t", f"{total_dur:.6f}"] +
           vc.VCODEC_FINAL + vc.ACODEC_AAC + ["-movflags", "+faststart", out])
    vc.sh(cmd)

    # 4. sidecar timeline, handy while iterating on SHOTS.md ------------------
    csv_path = os.path.splitext(out)[0] + "_timeline.csv"
    with open(csv_path, "w") as f:
        wr = csv.DictWriter(f, fieldnames=["i", "id", "type", "start", "dur"])
        wr.writeheader()
        for tl in timeline:
            wr.writerow({k: tl[k] for k in ("i", "id", "type", "start", "dur")})

    vdur = vc.probe_duration(out)
    print(f"wrote {out}  (video+audio duration {vdur:.3f}s, target {total_dur:.3f}s)")


if __name__ == "__main__":
    main()
