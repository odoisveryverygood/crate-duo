#!/usr/bin/env python3
"""Build the melodic-loop library: trim/normalize audio, analyze, write JSON index.

Usage:
    .venv/bin/python pipeline.py [--limit N] [--start N]

Reads from ~/Documents (read-only). Writes:
  /Users/shuhanzhang/duo-hack/library/loops/<instrument>/<id>.wav
  /Users/shuhanzhang/duo-hack/library/loops.json
  /Users/shuhanzhang/duo-hack/library/LOOPS.md
"""
import os
import re
import sys
import json
import argparse
import subprocess
import numpy as np
import soundfile as sf
import librosa

sys.path.insert(0, os.path.dirname(__file__))
from selection import SELECTION, PACK_STYLE_PRIOR

DOCS = os.path.expanduser("~/Documents")
LIB = "/Users/shuhanzhang/duo-hack/library"
LOOPS_DIR = os.path.join(LIB, "loops")
SCRATCH = "/private/tmp/claude-503/-Users-shuhanzhang/e4350d56-7646-49d3-90c7-6512aef4989d/scratchpad"
FFMPEG = "/opt/homebrew/bin/ffmpeg"
FFPROBE = "/opt/homebrew/bin/ffprobe"

STYLE_NAMES = ["dilla", "jazzhop", "boombap", "lofi", "vintage", "house", "trap", "drill", "rnb"]
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
INSTR_ABBR = {
    "piano": "PNO", "rhodes": "RHD", "keys": "KEY", "guitar": "GTR",
    "strings": "STR", "pad": "PAD", "vibes": "VIB", "horns": "HRN",
    "sax": "SAX", "flute": "FLT", "break": "BRK", "bass": "BAS",
    "vocal": "VOX", "full": "FUL",
}

MOOD_LIST = ["melancholic", "warm", "dreamy", "rainy", "nostalgic", "uplifting",
             "dark", "smooth", "sad", "hopeful", "groovy", "tense"]

NAME_STOP = set("""
loop loops melodic melody key keys piano pianos rhodes electric elec guitar guitars
ac acoustic sax saxophone saxophones trumpet tenor alto flute string strings pad pads
chord chords drum drums full mix arrangement lofi hifi wav bpm major maj minor min
kit kits one shot shots the and of a v1 v2 v3 stems stem loop1 solo chops chopped
grouped back note notes lo fi
fj hhp tsj jh jhb jhb2 sns mh bbl pmdh mhtn mthn kkjh vhh cym cymatics
starter pack samplemagic jhj vintage hip hop jazz jazzhop nu rv sample magic
""".split())

KEY_LIKE = re.compile(r"^[A-Ga-g](#|b)?(m|min|maj|major|minor)?$")

FADE_SEC = 0.005
TARGET_I = -14.0
TARGET_TP = -1.0


def normalize_key(raw):
    if raw is None:
        return None
    s = raw.strip().replace(" ", "")
    m = re.match(r"^([A-Ga-g])(#|b)?(maj|major|min|minor|m)?$", s, re.I)
    if not m:
        return None
    letter = m.group(1).upper()
    acc = m.group(2) or ""
    acc = "#" if acc == "#" else ("b" if acc.lower() == "b" else "")
    qual = (m.group(3) or "").lower()
    minor = qual in ("min", "minor", "m")
    return f"{letter}{acc}{'m' if minor else ''}"


def resolve_bars(duration, bpm):
    """Return (final_bpm, bars) or (None, None) if no fit within tolerance."""
    for adj_bpm in (bpm, bpm / 2.0, bpm * 2.0):
        ratio = duration * adj_bpm / 240.0
        bars = round(ratio)
        if bars in (1, 2, 4, 8) and abs(ratio - bars) <= 0.03:
            return adj_bpm, bars
    return None, None


def ffprobe_duration(path):
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return float(out)


def loudnorm_two_pass(in_path, out_path, sr=44100):
    cmd1 = [FFMPEG, "-hide_banner", "-nostats", "-y", "-i", in_path,
            "-af", f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:print_format=json",
            "-f", "null", "-"]
    p1 = subprocess.run(cmd1, capture_output=True, text=True)
    stderr = p1.stderr
    start = stderr.rfind("{")
    end = stderr.rfind("}")
    try:
        meas = json.loads(stderr[start:end + 1])
        mi, mtp, mlra, mth = (meas["input_i"], meas["input_tp"],
                              meas["input_lra"], meas["input_thresh"])
        offset = meas.get("target_offset", "0.0")
        if float(mi) == float("-inf") or mi.lower() == "-inf":
            raise ValueError("silence")
        filt = (f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:measured_I={mi}:"
                f"measured_TP={mtp}:measured_LRA={mlra}:measured_thresh={mth}:"
                f"offset={offset}:linear=true")
    except Exception:
        filt = f"loudnorm=I={TARGET_I}:TP={TARGET_TP}"
    cmd2 = [FFMPEG, "-hide_banner", "-nostats", "-y", "-i", in_path,
            "-af", filt, "-ar", str(sr), "-ac", "2", "-sample_fmt", "s16", out_path]
    subprocess.run(cmd2, capture_output=True, text=True, check=True)


def trim_and_fade(src_path, target_dur):
    data, sr = sf.read(src_path, always_2d=True)
    n = data.shape[0]
    target_n = int(round(target_dur * sr))
    if target_n > n:
        if (target_n - n) <= 0.02 * sr:
            target_n = n
        else:
            pad = np.zeros((target_n - n, data.shape[1]), dtype=data.dtype)
            data = np.concatenate([data, pad], axis=0)
    trimmed = data[:target_n, :].astype(np.float64)
    fade_n = max(1, int(round(FADE_SEC * sr)))
    fade_n = min(fade_n, trimmed.shape[0] // 2)
    ramp_in = np.linspace(0.0, 1.0, fade_n)
    ramp_out = np.linspace(1.0, 0.0, fade_n)
    trimmed[:fade_n, :] *= ramp_in[:, None]
    trimmed[-fade_n:, :] *= ramp_out[:, None]
    return trimmed, sr


def krumhansl_key(mono, sr):
    chroma = librosa.feature.chroma_cqt(y=mono, sr=sr)
    mean_chroma = chroma.mean(axis=1)
    major = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
    minor = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
    best = (-2.0, None, None)
    for shift in range(12):
        maj_p = np.roll(major, shift)
        min_p = np.roll(minor, shift)
        c_maj = np.corrcoef(mean_chroma, maj_p)[0, 1]
        c_min = np.corrcoef(mean_chroma, min_p)[0, 1]
        if c_maj > best[0]:
            best = (c_maj, shift, False)
        if c_min > best[0]:
            best = (c_min, shift, True)
    corr, shift, minor_flag = best
    key = f"{NOTE_NAMES[shift]}{'m' if minor_flag else ''}"
    conf = float(np.clip((corr + 1.0) / 2.0, 0.0, 1.0))
    return key, conf


def guess_chord(chroma_col):
    if chroma_col.max() < 1e-6:
        return None
    v = chroma_col / (chroma_col.max() + 1e-9)
    if v.max() < 0.35:
        return None
    root = int(np.argmax(v))
    maj3 = v[(root + 4) % 12]
    min3 = v[(root + 3) % 12]
    fifth = v[(root + 7) % 12]
    if fifth < 0.15 and maj3 < 0.2 and min3 < 0.2:
        return None
    minor = min3 >= maj3
    sym = NOTE_NAMES[root] + ("m" if minor else "")
    seventh_minor = v[(root + 10) % 12]
    seventh_major = v[(root + 11) % 12]
    ninth = v[(root + 2) % 12]
    if minor and seventh_minor > 0.35:
        sym += "9" if ninth > 0.4 else "7"
    elif (not minor) and seventh_major > 0.35:
        sym += "maj9" if ninth > 0.4 else "maj7"
    elif (not minor) and seventh_minor > 0.4:
        sym += "9" if ninth > 0.4 else "7"
    return sym


def bass_midi_for_pc(pc, prefer=44):
    cands = [pc + 12 * k for k in range(0, 6) if 36 <= pc + 12 * k <= 52]
    if not cands:
        return None
    return min(cands, key=lambda m: abs(m - prefer))


def spectral_features(mono, sr):
    cent = float(np.mean(librosa.feature.spectral_centroid(y=mono, sr=sr)))
    roll = float(np.mean(librosa.feature.spectral_rolloff(y=mono, sr=sr, roll_percent=0.85)))
    flat = float(np.mean(librosa.feature.spectral_flatness(y=mono)))
    return cent, roll, flat


def make_name(instrument, filename, used_names):
    abbr = INSTR_ABBR.get(instrument, instrument[:3].upper())
    max_desc = 8 - 1 - len(abbr)
    base = os.path.splitext(os.path.basename(filename))[0]
    tokens = re.split(r"[^A-Za-z]+", base)
    cands = []
    for t in tokens:
        tl = t.lower()
        if len(t) < 3 or tl in NAME_STOP:
            continue
        if KEY_LIKE.match(t):
            continue
        cands.append(t.upper())
    # prefer longer, more distinctive words (e.g. "Ethereal"/"Junonator") over
    # short residual tokens; ties keep original left-to-right order.
    cands.sort(key=lambda c: -len(c))
    if not cands:
        digits = re.findall(r"\d+", base)
        cands = [f"N{digits[-1]}"] if digits else ["LOOP"]
    for c in cands:
        for length in range(min(len(c), max_desc), 1, -1):
            name = f"{c[:length]} {abbr}"
            if len(name) <= 8 and name not in used_names:
                return name
    idx = 1
    while True:
        name = f"{abbr}{idx:02d}"[:8]
        if name not in used_names:
            return name
        idx += 1


def compute_moods(key, dust, brightness, bpm, styles, instrument):
    scores = {}
    def add(k, v):
        scores[k] = scores.get(k, 0.0) + v
    is_minor = bool(key) and key.endswith("m")
    is_major = bool(key) and not key.endswith("m")
    if is_minor:
        add("melancholic", 0.8); add("sad", 0.4); add("nostalgic", 0.5); add("dark", 0.25)
    elif is_major:
        add("warm", 0.6); add("uplifting", 0.4); add("hopeful", 0.3)
    else:
        add("groovy", 0.3); add("dark", 0.2)
    if dust > 0.55:
        add("nostalgic", 0.4); add("rainy", 0.3); add("warm", 0.15)
    if dust > 0.75:
        add("dark", 0.15)
    if brightness < 0.35:
        add("dreamy", 0.4); add("sad", 0.15)
    if brightness > 0.65:
        add("uplifting", 0.3); add("hopeful", 0.2)
    if bpm >= 122:
        add("groovy", 0.5)
    if styles.get("trap", 0) > 0.5 or styles.get("drill", 0) > 0.4:
        add("tense", 0.5); add("dark", 0.4)
    if styles.get("house", 0) > 0.5:
        add("uplifting", 0.4); add("groovy", 0.35)
    if instrument == "break":
        add("groovy", 0.3)
    if styles.get("jazzhop", 0) > 0.6 or styles.get("dilla", 0) > 0.5:
        add("smooth", 0.4); add("warm", 0.15)
    scores = {k: v for k, v in scores.items() if k in MOOD_LIST}
    ranked = sorted(scores.items(), key=lambda kv: -kv[1])
    picked = [k for k, v in ranked if v >= 0.15][:4]
    if len(picked) < 2:
        for fallback in ("smooth", "warm", "groovy", "nostalgic"):
            if fallback not in picked:
                picked.append(fallback)
            if len(picked) >= 2:
                break
    return picked[:4]


def process_one(idx, rel_path, instrument, pack, bpm_hint, key_hint, name_override, used_names, log):
    src = os.path.join(DOCS, rel_path)
    dur = ffprobe_duration(src)
    final_bpm, bars = resolve_bars(dur, bpm_hint)
    if final_bpm is None:
        log.append(f"SKIP (no clean bar fit) {rel_path} dur={dur:.3f} bpm_hint={bpm_hint}")
        return None
    target_dur = bars * 240.0 / final_bpm
    trimmed, sr_native = trim_and_fade(src, target_dur)

    tmp_path = os.path.join(SCRATCH, f"trim_{idx:03d}.wav")
    sf.write(tmp_path, trimmed, sr_native, subtype="PCM_24")

    loop_id = f"L{idx:03d}"
    out_dir = os.path.join(LOOPS_DIR, instrument)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{loop_id}.wav")
    loudnorm_two_pass(tmp_path, out_path, sr=44100)
    os.remove(tmp_path)

    y, sr = sf.read(out_path, always_2d=True)
    mono = y.mean(axis=1).astype(np.float32)
    real_dur = y.shape[0] / sr

    beats_per_bar = 4
    n_beats = bars * beats_per_bar
    beatsSec = [round(i * 60.0 / final_bpm, 5) for i in range(n_beats)]

    onsets = librosa.onset.onset_detect(y=mono, sr=sr, backtrack=True, units="time")
    onsets = [float(o) for o in onsets if o <= real_dur + 0.01]

    slices16 = []
    for k in range(16):
        eq = k * target_dur / 16.0
        near = min(onsets, key=lambda o: abs(o - eq)) if onsets else None
        if near is not None and abs(near - eq) <= 0.04:
            slices16.append(round(near, 5))
        else:
            slices16.append(round(eq, 5))

    is_break = instrument == "break"

    if key_hint is not None:
        key = normalize_key(key_hint)
        key_conf = 1.0
        key_source = "filename"
    elif is_break:
        key = None
        key_conf = None
        key_source = None
    else:
        key, key_conf = krumhansl_key(mono, sr)
        key_source = "detected"

    chordsPerBar = None
    bassPerBeat = None
    if not is_break:
        hop = 512
        chroma = librosa.feature.chroma_cqt(y=mono, sr=sr, hop_length=hop)
        n_frames = chroma.shape[1]
        bar_dur = target_dur / bars
        chordsPerBar = []
        for b in range(bars):
            t0, t1 = b * bar_dur, (b + 1) * bar_dur
            f0 = int(t0 * sr / hop)
            f1 = max(f0 + 1, int(t1 * sr / hop))
            f1 = min(f1, n_frames)
            if f0 >= f1:
                chordsPerBar.append(None)
                continue
            col = chroma[:, f0:f1].mean(axis=1)
            chordsPerBar.append(guess_chord(col))

        stft = np.abs(librosa.stft(mono, n_fft=2048, hop_length=hop))
        freqs = librosa.fft_frequencies(sr=sr, n_fft=2048)
        low_mask = freqs <= 260.0
        total_energy_per_frame = stft.sum(axis=0) + 1e-9
        bassPerBeat = []
        prev = 44
        for bi in range(n_beats):
            bar_idx = min(bars - 1, bi // beats_per_bar)
            chord_root_pc = None
            sym = chordsPerBar[bar_idx] if chordsPerBar else None
            if sym:
                letter = sym[0]
                acc = "#" if len(sym) > 1 and sym[1] == "#" else ""
                chord_root_pc = NOTE_NAMES.index(letter + acc)
            t0 = bi * 60.0 / final_bpm
            t1 = t0 + 60.0 / final_bpm
            f0 = int(t0 * sr / hop)
            f1 = max(f0 + 1, int(t1 * sr / hop))
            f1 = min(f1, stft.shape[1])
            m = None
            if f0 < f1:
                spec = stft[low_mask, f0:f1]
                frame_total = total_energy_per_frame[f0:f1]
                low_ratio = spec.sum(axis=0) / frame_total
                if spec.size and spec.max() > 1e-6 and float(np.mean(low_ratio)) > 0.12:
                    band_freqs = freqs[low_mask]
                    energy = spec.mean(axis=1)
                    peak_freq = max(float(band_freqs[int(np.argmax(energy))]), 20.0)
                    midi_est = 69 + 12 * np.log2(peak_freq / 440.0)
                    pc = int(round(midi_est)) % 12
                    m = bass_midi_for_pc(pc, prefer=prev)
            if m is None and chord_root_pc is not None:
                m = bass_midi_for_pc(chord_root_pc, prefer=prev)
            if m is not None:
                prev = m
            bassPerBeat.append(m)

    cent, roll, flat = spectral_features(mono, sr)

    if name_override:
        name = name_override
    else:
        name = make_name(instrument, rel_path, used_names)
    used_names.add(name)

    entry = {
        "id": loop_id,
        "file": f"loops/{instrument}/{loop_id}.wav",
        "name": name,
        "instrument": instrument,
        "bpm": final_bpm if final_bpm == int(final_bpm) else round(final_bpm, 3),
        "bars": bars,
        "beatsPerBar": 4,
        "durationSec": round(real_dur, 5),
        "key": key,
        "keyConfidence": key_conf,
        "keySource": key_source,
        "pack": pack,
        "sourceRelBpm": bpm_hint,
        "beatsSec": beatsSec,
        "onsetsSec": [round(o, 5) for o in onsets][:200],
        "slices16Sec": slices16,
        "chordsPerBar": chordsPerBar,
        "bassPerBeat": bassPerBeat,
        "notes": None,
        "_raw_centroid": cent,
        "_raw_rolloff": roll,
        "_raw_flatness": flat,
        "source": rel_path,
    }
    return entry


def finalize_styles_and_moods(entry, pack):
    prior = dict(PACK_STYLE_PRIOR[pack])
    bpm = entry["bpm"]
    dust_prior = min(1.0, 0.6 * (prior["lofi"] + prior["vintage"]))
    return prior, dust_prior


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--start", type=int, default=0)
    args = ap.parse_args()

    os.makedirs(LOOPS_DIR, exist_ok=True)
    subset = SELECTION[args.start:]
    if args.limit:
        subset = subset[: args.limit]

    log = []
    entries = []
    used_names = set()
    for i, (rel_path, instrument, pack, bpm_hint, key_hint, name_override) in enumerate(subset, start=args.start + 1):
        try:
            entry = process_one(i, rel_path, instrument, pack, bpm_hint, key_hint, name_override, used_names, log)
            if entry is None:
                continue
            entries.append((entry, pack))
            print(f"[{i:03d}] OK {entry['id']} {entry['name']:>9} {instrument:8} bpm={entry['bpm']:.2f} bars={entry['bars']} key={entry['key']}")
        except Exception as e:
            log.append(f"ERROR {rel_path}: {type(e).__name__}: {e}")
            print(f"[{i:03d}] ERROR {rel_path}: {e}")

    if not entries:
        print("no entries processed")
        return

    centroids = np.array([e["_raw_centroid"] for e, _ in entries])
    rolloffs = np.array([e["_raw_rolloff"] for e, _ in entries])
    flatnesses = np.array([e["_raw_flatness"] for e, _ in entries])

    def minmax(a):
        lo, hi = a.min(), a.max()
        if hi - lo < 1e-9:
            return np.full_like(a, 0.5)
        return (a - lo) / (hi - lo)

    norm_cent = minmax(centroids)
    norm_roll = minmax(rolloffs)
    norm_flat = minmax(flatnesses)

    final_loops = []
    for i, (entry, pack) in enumerate(entries):
        prior, dust_prior = finalize_styles_and_moods(entry, pack)
        brightness = float(norm_cent[i])
        dust = float(np.clip(0.5 * (1 - norm_roll[i]) + 0.3 * norm_flat[i] + 0.2 * dust_prior, 0, 1))

        styles = dict(prior)
        bpm = entry["bpm"]
        if bpm > 135:
            styles["trap"] = min(1, styles["trap"] + 0.15)
            styles["drill"] = min(1, styles["drill"] + 0.15)
        if bpm > 150:
            styles["drill"] = min(1, styles["drill"] + 0.10)
        if dust > 0.6:
            styles["lofi"] = min(1, styles["lofi"] + 0.10)
            styles["vintage"] = min(1, styles["vintage"] + 0.10)
            styles["dilla"] = min(1, styles["dilla"] + 0.05)
        if brightness > 0.7:
            styles["house"] = min(1, styles["house"] + 0.10)
            styles["trap"] = min(1, styles["trap"] + 0.05)
            styles["jazzhop"] = max(0, styles["jazzhop"] - 0.05)
            styles["vintage"] = max(0, styles["vintage"] - 0.05)
        if brightness < 0.3:
            styles["vintage"] = min(1, styles["vintage"] + 0.05)
            styles["lofi"] = min(1, styles["lofi"] + 0.05)
        styles = {k: round(float(np.clip(v, 0, 1)), 2) for k, v in styles.items()}

        moods = compute_moods(entry["key"], dust, brightness, bpm, styles, entry["instrument"])

        entry["styles"] = styles
        entry["moods"] = moods
        entry["brightness"] = round(brightness, 3)
        entry["dust"] = round(dust, 3)
        for k in ("_raw_centroid", "_raw_rolloff", "_raw_flatness", "sourceRelBpm", "pack"):
            entry.pop(k, None)
        final_loops.append(entry)

    index = {
        "version": 1,
        "styles": STYLE_NAMES,
        "loops": final_loops,
    }
    with open(os.path.join(LIB, "loops.json"), "w") as f:
        json.dump(index, f, indent=1)

    print(f"\nWrote {len(final_loops)} loops to loops.json")
    if log:
        print(f"\n{len(log)} skipped/errors:")
        for l in log:
            print(" -", l)

    with open(os.path.join(SCRATCH, "pipeline_log.txt"), "w") as f:
        f.write("\n".join(log))


if __name__ == "__main__":
    main()
