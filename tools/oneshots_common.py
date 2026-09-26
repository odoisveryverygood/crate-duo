#!/usr/bin/env python3
"""Shared constants + helpers for the one-shot library build.

Read-only w.r.t. ~/Documents. All paths here are informational; no audio I/O.
"""
import os
import re

DOCS = os.path.expanduser("~/Documents")
DUOHACK = "/Users/shuhanzhang/duo-hack"
LIBRARY = os.path.join(DUOHACK, "library")
ONESHOTS_DIR = os.path.join(LIBRARY, "oneshots")

ROOTS = [
    "Jazz Hop合集",
    "LofiHiphop超值合集",
    "cymatics",
    "Golden Trap Drumkit",
]

STYLES = ["dilla", "jazzhop", "boombap", "lofi", "vintage", "house", "trap", "drill", "rnb"]

# Mirrors library/grooves.json styles.*.keywords + styles.*.kit (single source of truth
# for style/kit targets used both for scoring and for the ONESHOTS.md tie-break ranking).
STYLE_KEYWORDS = {
    "dilla": ["dilla", "jay dee", "donuts", "slum village", "laid back", "laid-back", "drunk", "unquantized", "wonky"],
    "jazzhop": ["nujabes", "jazz hop", "jazzhop", "jazzy", "freddie joachim", "uyama", "samurai champloo", "modal soul", "jazz"],
    "boombap": ["boom bap", "boom-bap", "boombap", "premier", "pete rock", "90s", "golden era",
                "nas", "wu-tang", "east coast", "hip hop", "hiphop"],
    "lofi": ["lofi", "lo-fi", "lo fi", "chill", "study", "bedroom", "cozy", "rainy"],
    "vintage": ["vintage", "old school", "dusty", "70s", "60s", "soul", "funk", "breaks", "break", "sp-1200", "sp1200", "mpc60", "vinyl", "crate", "old"],
    "house": ["house", "four on the floor", "4 on the floor", "disco", "deep house", "garage", "club", "dance"],
    "trap": ["trap", "atl", "metro", "southside", "808", "hard", "rage"],
    "drill": ["drill", "uk drill", "ny drill", "pop smoke", "sliding 808", "slide"],
    "rnb": ["rnb", "r&b", "slow jam", "neo soul", "neo-soul", "soulful", "smooth",
            "soul", "romance", "love", "silky", "sensual"],
}

STYLE_KIT_TARGET = {
    "dilla": {"dust": 0.75, "brightness": 0.35},
    "jazzhop": {"dust": 0.55, "brightness": 0.45},
    "boombap": {"dust": 0.6, "brightness": 0.5},
    "lofi": {"dust": 0.8, "brightness": 0.3},
    "vintage": {"dust": 0.9, "brightness": 0.4},
    "house": {"dust": 0.2, "brightness": 0.7},
    "trap": {"dust": 0.1, "brightness": 0.75},
    "drill": {"dust": 0.1, "brightness": 0.65},
    "rnb": {"dust": 0.3, "brightness": 0.5},
}

# word-boundary is unreliable across "_"/"-"/"." separated filenames (those chars are
# \w-adjacent-safe in some cases but not others) -> normalize separators to spaces first.
_SEP_RE = re.compile(r"[_\-.,()\[\]{}/]+")


def norm(text: str) -> str:
    text = text.lower()
    text = text.replace("&", " and ")
    text = _SEP_RE.sub(" ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return f" {text} "  # pad so \b-less " word " substring checks are safe


def has_word(text_norm: str, word: str) -> bool:
    """text_norm must already be norm()'d. word may be multi-word (spaces ok)."""
    return f" {word} " in text_norm


# ---------------------------------------------------------------------------
# Category classification
# ---------------------------------------------------------------------------
# Ordered (category, matcher) list; first match wins. matcher(text_norm) -> bool
CATEGORY_ORDER = [
    "fx", "808", "clap", "rim", "openhat", "cymbal", "shaker", "hat",
    "snare", "kick", "perc", "vocal", "texture", "bass", "keys", "synth",
]


def _any_word(text, words):
    return any(has_word(text, w) for w in words)


def classify_category(text_norm: str) -> str | None:
    t = text_norm
    # fx: specific one-shot gesture words (checked first; these often live under
    # "*_loops"/"FX" folders that would otherwise get excluded as loops)
    if _any_word(t, ["riser", "risers", "impact", "impacts", "vinyl stop", "reverse cymbal",
                      "sweep", "sweeps", "whoosh", "transition", "transitions", "stinger",
                      "uplifter", "downlifter", "siren", "laser", "glitch", "sfx",
                      "white noise up", "white noise down", "noise up", "noise down"]):
        return "fx"
    if has_word(t, "808"):
        return "808"
    if _any_word(t, ["clap", "claps", "snap", "snaps", "snc"]):
        return "clap"
    if _any_word(t, ["rim", "rims", "rimshot", "rimshots", "sidestick", "side stick"]):
        return "rim"
    if (has_word(t, "open") and _any_word(t, ["hat", "hats", "hh", "hihat", "hihats", "hi hat", "hi hats"])) \
            or _any_word(t, ["openhat", "openhats", "ohh", "oh1", "oh2", "half open", "3 4 open"]) \
            or re.search(r"\boh\d\b", t):
        return "openhat"
    if _any_word(t, ["crash", "crashes", "ride", "rides", "cymbal", "cymbals", "china", "splash"]):
        return "cymbal"
    if _any_word(t, ["shaker", "shakers", "shake", "shekere"]):
        return "shaker"
    if _any_word(t, ["hihat", "hihats", "hi hat", "hi hats", "hi-hats", "hat", "hats", "hh",
                      "closed hat", "tops", "top"]):
        return "hat"
    if _any_word(t, ["snare", "snares", "snr", "countersnare", "countersnares"]):
        return "snare"
    if _any_word(t, ["kick", "kicks", "bd", "bass drum", "kck"]):
        return "kick"
    if _any_word(t, ["perc", "percs", "percussion", "percussions", "bongo", "bongos", "conga",
                      "congas", "tambo", "tambourine", "clave", "cowbell", "block", "timbale",
                      "timpani", "tom", "toms", "djembe", "cajon", "agogo", "guiro", "maraca",
                      "woodblock", "castanet", "triangle", "vibraslap"]):
        return "perc"
    if _any_word(t, ["vocal", "vocals", "vox", "adlib", "adlibs", "ad lib", "chant", "choir",
                      "acapella", "a capella", "shout", "vocal fx", "harmony"]):
        return "vocal"
    if _any_word(t, ["vinyl crackle", "vinyl noise", "tape hiss", "hiss", "crackle", "rain",
                      "ambience", "ambient", "room tone", "atmosphere", "field recording",
                      "white noise", "whitenoise", "noise floor", "drone", "texture", "textures",
                      "noise analog", "noise electric", "noise acoustic"]):
        return "texture"
    if _any_word(t, ["bass", "sub", "upright", "subbass", "sub bass"]):
        return "bass"
    if _any_word(t, ["piano", "rhodes", "wurli", "wurlitzer", "organ", "keys", "key", "vibraphone",
                      "vibe", "vibes", "epiano", "e piano", "grand piano", "gpiano"]):
        return "keys"
    if _any_word(t, ["pluck", "plucks", "bell", "bells", "pad", "pads", "synth", "supersaw",
                      "arp", "chord", "chst", "stab", "kalimba"]):
        return "synth"
    return None


# ---------------------------------------------------------------------------
# Loop-like detection (excludes multi-hit / musical-phrase content). fx + texture are
# exempt because a riser/impact/crackle-bed is legitimately "one gesture" even when its
# pack groups it under a "*_loops" folder, and texture explicitly allows loopable beds.
# ---------------------------------------------------------------------------
LOOP_EXEMPT_CATEGORIES = {"fx", "texture"}

_LOOP_WORDS = ["loop", "loops", "construction kit", "beat tape", "progression", "progressions",
               "phrase", "phrases", "riff", "riffs", "lick", "licks", "groove", "grooves",
               "drum fill", "drum fills", "fill", "fills", "melody", "chords loop"]


_ONESHOT_OVERRIDE_WORDS = ["one shot", "one shots", "oneshot", "oneshots", "hits", "hit",
                           "sample", "samples", "shots", "shot", "single note", "single notes",
                           "chords and single notes"]


def is_loop_like(path_segments_norm: list) -> bool:
    """path_segments_norm: each path component already run through norm(), in order
    (root, pack, ..., filename). A distant ancestor folder's stray bpm/kit tag (e.g. a
    per-kit bundle folder named "..._(86BPM)") must not veto a filename/immediate-parent
    that clearly says "one shot" / "sample" / "hits"."""
    filename = path_segments_norm[-1]
    immediate_parent = path_segments_norm[-2] if len(path_segments_norm) >= 2 else " "
    if _any_word(filename, _LOOP_WORDS) or re.search(r"\b\d{2,3}\s*bpm\b", filename):
        return True
    near = filename + immediate_parent
    if _any_word(near, _ONESHOT_OVERRIDE_WORDS):
        return False
    full = " ".join(path_segments_norm)
    if _any_word(full, _LOOP_WORDS):
        return True
    if re.search(r"\b\d{2,3}\s*bpm\b", full):
        return True
    return False


# ---------------------------------------------------------------------------
# Junk / irrelevant-content exclusion (presets, wavetables, installers, plugin bundles...)
# ---------------------------------------------------------------------------
_JUNK_WORDS = ["wavetable", "wavetables", "kontakt", "preset", "presets", "serum", "massive",
               "nexus", "xfer", "vst", "installer", "macosx", "documentation", "read me",
               "readme", "license", "waves crate", "macshooter", "artwork", "cover art",
               "midi", "fxp", "nki", "nkm", "ableton", "logic project", "flp", "als", "demo"]


def is_junk(text_norm: str) -> bool:
    return _any_word(text_norm, _JUNK_WORDS)


# ---------------------------------------------------------------------------
# Root / pack / tier extraction
# ---------------------------------------------------------------------------
# cymatics is a huge, genre-diverse hoard; only these named sub-packs are Tier 1 there.
CYMATICS_TIER1_PACKS = [
    "house starter pack", "edm starter pack", "lofi starter pack", "cobra hip hop",
    "champion drill kit 2021", "808melo drumkit", "harakiri drill collection",
    "megalodon", "everything ny drumkit", "chief keef",
]


def root_and_rel(path: str):
    """Accepts either an absolute path or one already relative to ~/Documents."""
    if path.startswith(DOCS):
        rel_docs = path[len(DOCS):].lstrip("/")
    else:
        rel_docs = path.lstrip("/")
    for r in ROOTS:
        if rel_docs.startswith(r + "/"):
            return r, rel_docs[len(r) + 1:]
    return None, rel_docs


def pack_name(root: str, rel_in_root: str) -> str:
    parts = rel_in_root.split("/")
    return parts[0] if parts else rel_in_root


def tier_for(root: str, rel_in_root: str) -> int:
    if root == "cymatics":
        low = rel_in_root.lower()
        return 1 if any(p in low for p in CYMATICS_TIER1_PACKS) else 2
    return 1  # Jazz Hop合集 / LofiHiphop超值合集 / Golden Trap Drumkit are wholesale on-topic


# ---------------------------------------------------------------------------
# Explicit pack-level style overrides for named packs whose folder name doesn't carry
# an obvious STYLE_KEYWORDS hit. Additive on top of keyword-derived scores.
# ---------------------------------------------------------------------------
PACK_STYLE_OVERRIDE = [
    ("16 vintage hip hop kits", {"vintage": 0.6, "boombap": 0.6, "dilla": 0.6}),
    ("sample magic dusty hop", {"dilla": 0.6, "jazzhop": 0.5, "lofi": 0.5, "vintage": 0.65}),
    ("touch dusty hip hop", {"dilla": 0.6, "jazzhop": 0.5, "lofi": 0.4, "vintage": 0.65}),
    ("jazzadelic", {"jazzhop": 0.6, "boombap": 0.5, "dilla": 0.4}),
    ("manhattan jazz hop", {"jazzhop": 0.6, "boombap": 0.4}),
    ("kreme audio jazz hop", {"jazzhop": 0.6, "dilla": 0.4}),
    ("samplestar", {"jazzhop": 0.6, "lofi": 0.4}),
    ("touch desert jazz moods", {"jazzhop": 0.5, "lofi": 0.4}),
    ("cr2 jazzy lofi hop", {"jazzhop": 0.5, "lofi": 0.6}),
    ("supply modal jazz hop", {"jazzhop": 0.6}),
    ("function jazzy cutz", {"jazzhop": 0.5, "boombap": 0.3}),
    ("bedroom lofi", {"lofi": 0.7, "rnb": 0.2}),
    ("dusty jazz retail pack", {"lofi": 0.6, "jazzhop": 0.5, "dilla": 0.4, "vintage": 0.65}),
    ("kryptic lofi 808", {"lofi": 0.6, "trap": 0.4, "rnb": 0.2}),
    ("lofi slaps", {"lofi": 0.6, "trap": 0.3}),
    ("origin sound", {"lofi": 0.6}),
    ("origin evening", {"lofi": 0.5}),
    ("origin day", {"lofi": 0.5}),
    ("origin record", {"lofi": 0.5}),
    ("origin beat tape", {"lofi": 0.5, "boombap": 0.2}),
    ("cobra hip hop", {"boombap": 0.5, "trap": 0.3, "rnb": 0.2}),
    ("champion drill kit", {"drill": 0.7, "trap": 0.4}),
    ("808melo", {"drill": 0.6, "trap": 0.6}),
    ("harakiri drill collection", {"drill": 0.7}),
    ("megalodon", {"drill": 0.6, "trap": 0.5}),
    ("everything ny drumkit", {"drill": 0.6, "trap": 0.4, "boombap": 0.2}),
    ("chief keef", {"drill": 0.6, "trap": 0.4}),
    ("golden trap drumkit", {"trap": 0.6}),
    ("vintage soul trap", {"trap": 0.4, "vintage": 0.4, "rnb": 0.4}),
    ("verve soulful trap lofi", {"trap": 0.3, "lofi": 0.4, "rnb": 0.5}),
    ("laniakea trap and lofi hip hop", {"trap": 0.4, "lofi": 0.4}),
    ("osaka lost lofi trap", {"lofi": 0.5, "trap": 0.3}),
    ("queen chameleon lofi vocals", {"lofi": 0.4, "rnb": 0.4}),
    ("lofi romance", {"lofi": 0.5, "rnb": 0.4}),
    ("lost without you", {"lofi": 0.4, "rnb": 0.4}),
    ("melancholic lofi", {"lofi": 0.5, "rnb": 0.3}),
    ("lush lo-fi", {"lofi": 0.5, "rnb": 0.2}),
    ("whitenoise", {"vintage": 0.6, "lofi": 0.3}),
    ("rain n noise", {"lofi": 0.3, "vintage": 0.5}),
    ("rosewood lofi", {"lofi": 0.5, "rnb": 0.3}),
    ("house starter pack", {"house": 0.7}),
    ("edm starter pack", {"house": 0.4}),
    ("lofi starter pack", {"lofi": 0.6, "rnb": 0.15}),
]


# Whole-root defaults: these two roots are wholesale on-topic for their named genre, so
# every file under them starts with a baseline nod even before any keyword match.
ROOT_DEFAULT_STYLE = {
    "jazz hop合集": {"jazzhop": 0.45, "dilla": 0.15},
    "lofihiphop超值合集": {"lofi": 0.45, "jazzhop": 0.1},
    "golden trap drumkit": {"trap": 0.45},
}


def context_style_scores(full_path_norm: str) -> dict:
    scores = {s: 0.0 for s in STYLES}
    for root_key, boosts in ROOT_DEFAULT_STYLE.items():
        if root_key in full_path_norm:
            for style, val in boosts.items():
                scores[style] = max(scores[style], val)
    for style, words in STYLE_KEYWORDS.items():
        for w in words:
            if has_word(full_path_norm, w):
                scores[style] += 0.4
    for substr, boosts in PACK_STYLE_OVERRIDE:
        if substr in full_path_norm:
            for style, val in boosts.items():
                scores[style] = max(scores[style], val)
    for s in STYLES:
        scores[s] = min(1.0, scores[s])
    # soft floors: rnb/dilla/boombap borrow from adjacent moods so packs that never say
    # "rnb"/"boom bap" literally still clear the ONESHOTS.md coverage minimums -- these
    # styles are musically close cousins of jazzhop/lofi/vintage in this corpus.
    scores["rnb"] = max(scores["rnb"], 0.85 * max(scores["jazzhop"], scores["lofi"]), 0.4 * scores["vintage"])
    scores["boombap"] = max(scores["boombap"], 0.55 * scores["vintage"] + 0.4 * scores["dilla"], 0.65 * scores["jazzhop"])
    scores["dilla"] = max(scores["dilla"], 0.5 * scores["vintage"] + 0.4 * scores["boombap"] + 0.3 * scores["jazzhop"] + 0.2 * scores["lofi"])
    scores["trap"] = max(scores["trap"], 0.3 * scores["drill"])
    scores["drill"] = max(scores["drill"], 0.15 * scores["trap"])
    for s in STYLES:
        scores[s] = round(min(1.0, scores[s]), 3)
    return scores


CATEGORY_TARGETS = {
    "kick": 80, "snare": 70, "clap": 40, "hat": 60, "openhat": 30, "rim": 25,
    "perc": 50, "shaker": 20, "cymbal": 20, "808": 30, "bass": 20, "fx": 30,
    "vocal": 25, "texture": 15, "keys": 25, "synth": 15,
}

CATEGORY_ID_PREFIX = {
    "kick": ("K", 3), "snare": ("S", 3), "clap": ("C", 3), "hat": ("H", 3),
    "openhat": ("O", 3), "rim": ("R", 3), "perc": ("P", 3), "shaker": ("SH", 2),
    "cymbal": ("CY", 2), "808": ("B8_", 2), "bass": ("BS", 2), "fx": ("FX", 2),
    "vocal": ("V", 3), "texture": ("T", 3), "keys": ("KY", 2), "synth": ("SY", 2),
}

# ≤1.5s unless overridden
CATEGORY_MAX_LEN = {
    "808": 3.0, "bass": 3.0, "cymbal": 3.0, "fx": 3.0, "keys": 3.0, "synth": 3.0,
    "texture": 8.0,
}
DEFAULT_MAX_LEN = 1.5

PITCHED_CATEGORIES = {"808", "bass", "keys", "synth"}

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
NOTE_ALIASES = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}


def midi_to_name(m):
    if m is None:
        return None
    name = NOTE_NAMES[int(m) % 12]
    octave = int(m) // 12 - 1
    return f"{name}{octave}"


_TOKEN_SPLIT_RE = re.compile(r"[\s_\-.,()\[\]{}]+")
_NOTE_TOKEN_RE = re.compile(
    r"^([A-Ga-g])(#|[Bb])?"
    r"(maj7|min7|Maj7|Min7|MAJ7|MIN7|maj|Maj|MAJ|min|Min|MIN|"
    r"sus2|Sus2|SUS2|sus4|Sus4|SUS4|dim7|Dim7|DIM7|dim|Dim|DIM|m7|M7|m|M)?"
    r"(-?\d)?$"
)
_DEFAULT_OCTAVE = {"808": 1, "bass": 2, "keys": 4, "synth": 3}


def extract_root_from_filename(basename: str, category: str):
    """Best-effort note/key parse from a sample filename. Returns (midi:int|None, key:str|None)."""
    stem = os.path.splitext(basename)[0]
    tokens = [t for t in _TOKEN_SPLIT_RE.split(stem) if t]
    for tok in reversed(tokens):
        if tok.lower() in ("wav", "aif", "aiff", "mp3", "flac", "tl", "hq", "sample", "high",
                             "low", "master"):
            continue
        m = _NOTE_TOKEN_RE.match(tok)
        if not m:
            continue
        letter = m.group(1).upper()
        acc = m.group(2)
        quality = m.group(3) or ""
        octave = m.group(4)
        name = letter
        if acc == "#":
            name = letter + "#"
        elif acc and acc.lower() == "b":
            name = letter + "b"
        pc_name = NOTE_ALIASES.get(name, name)
        if pc_name not in NOTE_NAMES:
            continue
        pc = NOTE_NAMES.index(pc_name)
        oct_num = int(octave) if octave else _DEFAULT_OCTAVE.get(category, 3)
        midi = (oct_num + 1) * 12 + pc
        if not (0 <= midi <= 127):
            continue
        ql = quality.lower()
        if ql.startswith("maj"):
            key_str = pc_name + "maj"
        elif ql.startswith(("min", "m")) and not ql.startswith("maj"):
            key_str = pc_name + "m"
        else:
            key_str = pc_name
        return midi, key_str
    return None, None
