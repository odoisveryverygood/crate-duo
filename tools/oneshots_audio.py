#!/usr/bin/env python3
"""Audio decode / process / analyze helpers for the one-shot library build.

Uses ffmpeg (subprocess) to decode any source format to a clean 44.1kHz PCM16 WAV,
then librosa/numpy/soundfile for trimming, capping, fading, normalizing and analysis.
"""
import os
import subprocess
import numpy as np
import soundfile as sf
import librosa

FFMPEG = "/opt/homebrew/bin/ffmpeg"
SR = 44100
SILENCE_DB = -50.0
FADE_MS = 10.0
TARGET_PEAK_DB = -1.0
FRAME = 256  # ~5.8ms at 44.1k, fine resolution for onset/offset on short one-shots


def db_to_amp(db):
    return 10.0 ** (db / 20.0)


def amp_to_db(a):
    return 20.0 * np.log10(max(a, 1e-9))


class DecodeError(Exception):
    pass


def decode(src_path: str, tmp_path: str) -> tuple:
    """ffmpeg-decode src_path to 44.1kHz PCM16 WAV at tmp_path, then load as float32.
    Returns (data, sr). data shape: (n,) mono or (n, ch)."""
    try:
        proc = subprocess.run(
            [FFMPEG, "-y", "-v", "error", "-i", src_path, "-ar", str(SR), "-c:a", "pcm_s16le", tmp_path],
            capture_output=True, timeout=60,
        )
    except subprocess.TimeoutExpired:
        raise DecodeError("ffmpeg timeout")
    if proc.returncode != 0 or not os.path.exists(tmp_path):
        raise DecodeError(proc.stderr.decode("utf-8", "replace")[:300])
    data, sr = sf.read(tmp_path, dtype="float32", always_2d=False)
    if data.size == 0:
        raise DecodeError("empty audio")
    return data, sr


def _mono(data):
    if data.ndim == 1:
        return data
    return data.mean(axis=1)


def _frame_peak_db(mono, frame=FRAME):
    n = len(mono)
    nframes = max(1, n // frame)
    peaks = np.zeros(nframes, dtype=np.float64)
    for i in range(nframes):
        seg = mono[i * frame:(i + 1) * frame]
        p = np.max(np.abs(seg)) if seg.size else 0.0
        peaks[i] = amp_to_db(p) if p > 0 else -120.0
    return peaks


def trim_and_cap(data, sr, max_len_sec):
    """Trim leading/trailing silence at SILENCE_DB, then hard-cap total length."""
    mono = _mono(data)
    peaks = _frame_peak_db(mono)
    above = np.where(peaks >= SILENCE_DB)[0]
    if len(above) == 0:
        # nothing above threshold -- keep a short slice from the start rather than drop
        start_f, end_f = 0, min(len(peaks), 1)
    else:
        start_f = max(0, above[0] - 2)  # ~11.6ms pre-roll so sharp transients aren't clipped
        end_f = min(len(peaks), above[-1] + 6)  # ~+35ms release tail past last active frame
    start = start_f * FRAME
    end = min(len(mono), end_f * FRAME)
    if end <= start:
        end = min(len(mono), start + FRAME)
    max_len_samples = int(max_len_sec * sr)
    if end - start > max_len_samples:
        end = start + max_len_samples
    if data.ndim == 1:
        return data[start:end]
    return data[start:end, :]


def fade_out(data, sr, fade_ms=FADE_MS):
    fade_len = int(sr * fade_ms / 1000.0)
    n = data.shape[0]
    if n <= 1:
        return data
    fade_len = min(fade_len, n)
    ramp = np.linspace(1.0, 0.0, fade_len, dtype=np.float32)
    out = data.copy()
    if out.ndim == 1:
        out[n - fade_len:] *= ramp
    else:
        out[n - fade_len:, :] *= ramp[:, None]
    return out


def normalize_peak(data, target_db=TARGET_PEAK_DB):
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    if peak <= 1e-6:
        return data, False
    gain = db_to_amp(target_db) / peak
    return data * gain, True


def process(data, sr, max_len_sec):
    trimmed = trim_and_cap(data, sr, max_len_sec)
    normed, ok = normalize_peak(trimmed)
    faded = fade_out(normed, sr)
    return faded, ok


def analyze(data, sr):
    """Returns raw (pre category-normalization) feature dict from the FINAL processed audio."""
    mono = np.ascontiguousarray(_mono(data), dtype=np.float32)
    duration = len(mono) / sr
    peaks = _frame_peak_db(mono)
    peak_amp = float(np.max(np.abs(mono))) if mono.size else 0.0
    peak_db = amp_to_db(peak_amp)
    rms = float(np.sqrt(np.mean(mono.astype(np.float64) ** 2))) if mono.size else 0.0
    rms_db = amp_to_db(rms)
    crest_db = peak_db - rms_db

    # decay: time from peak frame to first later frame 40dB below peak
    if len(peaks):
        peak_frame = int(np.argmax(peaks))
        thresh = peaks[peak_frame] - 40.0
        decay_sec = duration - (peak_frame * FRAME / sr)
        for i in range(peak_frame + 1, len(peaks)):
            if peaks[i] <= thresh:
                decay_sec = (i * FRAME - peak_frame * FRAME) / sr
                break
    else:
        decay_sec = duration

    # attack sharpness: samples from 10% to 90% of peak amplitude (first crossing)
    attack_ms = 5.0
    if peak_amp > 1e-6:
        absmono = np.abs(mono)
        lo = 0.1 * peak_amp
        hi = 0.9 * peak_amp
        idx_lo = np.argmax(absmono >= lo) if np.any(absmono >= lo) else 0
        idx_hi = np.argmax(absmono >= hi) if np.any(absmono >= hi) else idx_lo
        attack_ms = max(0.0, (idx_hi - idx_lo) / sr * 1000.0)

    n_fft = 2048 if len(mono) >= 2048 else max(64, 2 ** int(np.floor(np.log2(max(2, len(mono))))))
    hop = max(1, n_fft // 4)
    try:
        centroid = float(np.mean(librosa.feature.spectral_centroid(y=mono, sr=sr, n_fft=n_fft, hop_length=hop)))
    except Exception:
        centroid = 0.0
    try:
        rolloff = float(np.mean(librosa.feature.spectral_rolloff(y=mono, sr=sr, n_fft=n_fft, hop_length=hop, roll_percent=0.85)))
    except Exception:
        rolloff = sr / 4
    try:
        flatness = float(np.mean(librosa.feature.spectral_flatness(y=mono, n_fft=n_fft, hop_length=hop)))
    except Exception:
        flatness = 0.0

    # loopability heuristic (used for texture): compare RMS of first vs last 15% of clip
    n = len(mono)
    seg = max(1, int(n * 0.15))
    head_rms = float(np.sqrt(np.mean(mono[:seg].astype(np.float64) ** 2))) if seg else 0.0
    tail_rms = float(np.sqrt(np.mean(mono[-seg:].astype(np.float64) ** 2))) if seg else 0.0
    head_db = amp_to_db(head_rms)
    tail_db = amp_to_db(tail_rms)
    sustained = bool(abs(head_db - tail_db) < 6.0 and duration > 1.2)

    return {
        "durationSec": round(duration, 4),
        "decaySec": round(max(0.0, decay_sec), 4),
        "centroid_hz": centroid,
        "rolloff_hz": rolloff,
        "flatness": flatness,
        "crest_db": crest_db,
        "attack_ms": attack_ms,
        "sustained": sustained,
    }


def pitch_from_audio(data, sr, window_sec=0.3):
    mono = _mono(data)
    n = min(len(mono), int(window_sec * sr))
    if n < int(0.02 * sr):
        return None
    seg = np.ascontiguousarray(mono[:n], dtype=np.float32)
    try:
        f0, voiced_flag, voiced_prob = librosa.pyin(
            seg, fmin=librosa.note_to_hz("C1"), fmax=librosa.note_to_hz("C6"), sr=sr,
        )
    except Exception:
        return None
    if f0 is None:
        return None
    valid = f0[~np.isnan(f0)]
    if valid.size == 0:
        return None
    f0_med = float(np.median(valid))
    if f0_med <= 0:
        return None
    midi = 69 + 12 * np.log2(f0_med / 440.0)
    return int(round(midi))
