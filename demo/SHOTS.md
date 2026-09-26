# CRATE demo film — shot plan (target 75–85 s)

Style target: `demo/ref/ref1_sheet.jpg` / `ref/ref1.mp4` — cream background,
black serif cards, restraint. 12 cuts (13 shots), median shot ~4.5 s (a bit
longer than the reference's 3.3 s median because several shots have to
carry a feature demo; the one long continuous shot — the hinge fold — is
deliberately the reference's "long continuous camera move" move).

Everything below is a **starting point**. The numbers that are load-bearing
(and must not drift) are the two music sync points, marked **SYNC**. Every
other duration is a reasonable guess for footage nobody has recorded yet —
after the lead records the real clips, re-run `assemble.py`, open the
`*_timeline.csv` it writes next to the output, and copy each shot's real
`start` value into the music plan's `at` fields instead of trusting the
estimates here.

## The sync math (read this before recording shot 9/10)

`demo/music/beats.json["horn.wav"]` gives tempo 112.3 BPM, beat period
0.534 s. The brief's two anchors land almost exactly on that grid (126.4 s
is 9 ms from the beat at 126.409 s; 143.0 s is ~0.2 s from the beat at
143.221 s) — so 126.4 / 143.0 are the numbers to use verbatim, not the
grid.

The hinge starts folding the instant shot 9 begins, and must be **fully
closed the instant shot 10 (the snap-open) begins**, because shot 10's
first frame is where the song's `track_in=143.0` — "band re-enters HARD"
— has to land. That means:

  shot 9 duration == 143.0 - 126.4 == **16.6 s, exactly**.

If the real hinge-fold footage runs long or short, don't stretch it
(`--speed` on compose.py) rather than change this number — the fold has to
finish exactly when the drop hits.

## Shot table

| # | Beat | Record (device / pose / action) | Dur | Camera keys (compose.py `--keys`, cx/cy = guesses, refine on real footage) | Audio |
|---|------|----------------------------------|-----|------------------------------------------------------------------------|-------|
| 1 | Cold open, title card | *(no recording — `cards/title.png` via assemble.py)* | 4.0 s | `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":4.0,"zoom":1.05,"cx":0.5,"cy":0.46}]` (slow push, ref-style) | song L1 fades in |
| 2 | Type the prompt — *"4 bar loop, j dilla laid back drums and a killer nujabes piano sample"* | **outer** display, prompt chip (per DEMO.md step 2); real on-screen typing, no synthetic text | 4.5 s | `[{"t":0,"zoom":1.05,"cx":0.5,"cy":0.35},{"t":4.5,"zoom":1.3,"cx":0.5,"cy":0.3}]` — slow push on the text field | song L1 |
| 3 | Pads fill instantly + `JEV ~140ms` readout | **inner** display, deck view right after submit | 3.5 s | `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":3.0,"zoom":2.0,"cx":0.82,"cy":0.12},{"t":3.5,"zoom":2.0,"cx":0.82,"cy":0.12}]` — hard push into the readout corner (guess: top-right; move to wherever `JEV` actually renders) | song L1 |
| 4 | GPT line lands — `GPT 3.8s ✓ walking bass under Am9–Dm9` | **inner** display, same readout area, new line appears | 3.5 s | `[{"t":0,"zoom":2.0,"cx":0.82,"cy":0.12},{"t":2.0,"zoom":1.4,"cx":0.6,"cy":0.2},{"t":3.5,"zoom":1.4,"cx":0.6,"cy":0.2}]` — ease back out to reveal the whole line | song L1 → **crossfade starts** |
| 5 | Unfold to laptop pose (~110° hinge) | **inner** display, lead drags simulated hinge angle from closed to ~110° | 3.5 s | `[{"t":0,"zoom":1.3,"cx":0.5,"cy":0.5},{"t":3.5,"zoom":1.0,"cx":0.5,"cy":0.5}]` — pull back to reveal both halves | **app audio fades in (crossfade)** |
| 6 | Finger-drumming the pads | **inner** display, laptop pose, pads grid | 7.0 s | `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.55},{"t":3.5,"zoom":1.5,"cx":0.4,"cy":0.6},{"t":7.0,"zoom":1.15,"cx":0.5,"cy":0.55}]` — drift between pad hits | app |
| 7 | KEYS mode, scale-locked 808 across a keyboard, lid shows notes | **inner** display, mode switched to KEYS | 6.0 s | `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":6.0,"zoom":1.3,"cx":0.5,"cy":0.42}]` — slow single push | app |
| 8 | **"Two screens, one instrument"** — outer (crowd/back) view floating beside the inner deck | **inner** *and* **outer**, same moment, two separate recordings → `compose.py --second` | 7.0 s | main: `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5}]`; `--second-keys` same (both static — let the side-by-side layout itself be the reveal, ref-style restraint) | app (from inner clip only — `--second`'s own audio is never mixed, see note below) |
| 9 | **Hinge fold** — filter closes, reverb swells into the breakdown | **inner** display, lead slowly folds the simulated hinge toward closed | **16.6 s (SYNC — see math above)** | `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":16.6,"zoom":1.3,"cx":0.5,"cy":0.5}]` — slow creep in, building tension into the cut | app (ducked, −4 dB) **+ song L2** (`track_in=126.4`) fades up |
| 10 | **Snap open — DROP** | **inner** display, hinge snapped fully open, hard cut | 2.6 s | `[{"t":0,"zoom":1.7,"cx":0.5,"cy":0.5},{"t":2.6,"zoom":1.3,"cx":0.5,"cy":0.5}]` — camera already punched in at frame 1 (this is one of the few *hard* cuts, ref-style) | app (back to 0 dB, unfiltered) **+ song L3** (`track_in=143.0`, **SYNC**) |
| 11 | *"fill up the pads with some house drums"* — only the drum bank swaps, loop never stops | **outer or inner**, new prompt typed, drum bank changes live | 6.5 s | `[{"t":0,"zoom":1.3,"cx":0.5,"cy":0.5},{"t":6.5,"zoom":1.0,"cx":0.5,"cy":0.5}]` | song L3 fades out, **app fades in (crossfade)** |
| 12 | Typed closing line — *"AI digs it. You flip it."* | *(no recording — `cards/end_typed.mov`)* | 2.5 s (natural) | n/a (already rendered by cards.py) | song L4 fades in under it |
| 13 | End card — CRATE wordmark | *(no recording — `cards/end_card.png`)* | 8.0 s | `[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":8.0,"zoom":1.04,"cx":0.5,"cy":0.48}]` | song L4 |

Running total: **75.2 s.**

Note on shot 8: `compose.py --second` only *composites the picture* of the
second recording; `assemble.py`'s `audio: "app"` always pulls sound from
the shot's primary `clip`, never from `second`. If the outer-screen take
is the one with the better audio (e.g. a room-tone / crowd mic), swap
which file is `clip` vs `second`.

## Shot list JSON skeleton (durations/keys above, ready to fill in real `clip`/`ss`)

```json
{
  "shots": [
    {"type":"image","id":"title","path":"cards/title.png","dur":4.0,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":4.0,"zoom":1.05,"cx":0.5,"cy":0.46}]},
    {"type":"clip","id":"type_prompt","clip":"clips/REPLACE.mp4","ss":0,"dur":4.5,
     "keys":[{"t":0,"zoom":1.05,"cx":0.5,"cy":0.35},{"t":4.5,"zoom":1.3,"cx":0.5,"cy":0.3}],
     "audio":"silent"},
    {"type":"clip","id":"pads_jev","clip":"clips/REPLACE.mp4","ss":0,"dur":3.5,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":3.0,"zoom":2.0,"cx":0.82,"cy":0.12},{"t":3.5,"zoom":2.0,"cx":0.82,"cy":0.12}],
     "audio":"silent"},
    {"type":"clip","id":"gpt_line","clip":"clips/REPLACE.mp4","ss":0,"dur":3.5,
     "keys":[{"t":0,"zoom":2.0,"cx":0.82,"cy":0.12},{"t":2.0,"zoom":1.4,"cx":0.6,"cy":0.2},{"t":3.5,"zoom":1.4,"cx":0.6,"cy":0.2}],
     "audio":"silent"},
    {"type":"clip","id":"unfold","clip":"clips/REPLACE.mp4","ss":0,"dur":3.5,
     "keys":[{"t":0,"zoom":1.3,"cx":0.5,"cy":0.5},{"t":3.5,"zoom":1.0,"cx":0.5,"cy":0.5}],
     "audio":"app","gain_db":0,"fade_in":2.0,"fade_out":0.1},
    {"type":"clip","id":"finger_drum","clip":"clips/REPLACE.mp4","ss":0,"dur":7.0,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.55},{"t":3.5,"zoom":1.5,"cx":0.4,"cy":0.6},{"t":7.0,"zoom":1.15,"cx":0.5,"cy":0.55}],
     "audio":"app","gain_db":0,"fade_in":0.1,"fade_out":0.1},
    {"type":"clip","id":"keys_mode","clip":"clips/REPLACE.mp4","ss":0,"dur":6.0,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":6.0,"zoom":1.3,"cx":0.5,"cy":0.42}],
     "audio":"app","gain_db":0,"fade_in":0.1,"fade_out":0.1},
    {"type":"clip","id":"two_screens","clip":"clips/REPLACE_inner.mp4","ss":0,"dur":7.0,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5}],
     "second":"clips/REPLACE_outer.mp4","second_keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5}],
     "audio":"app","gain_db":0,"fade_in":0.1,"fade_out":0.1},
    {"type":"clip","id":"hinge_fold","clip":"clips/REPLACE.mp4","ss":0,"dur":16.6,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":16.6,"zoom":1.3,"cx":0.5,"cy":0.5}],
     "audio":"app","gain_db":-4,"fade_in":0.2,"fade_out":0.2},
    {"type":"clip","id":"snap_open","clip":"clips/REPLACE.mp4","ss":0,"dur":2.6,
     "keys":[{"t":0,"zoom":1.7,"cx":0.5,"cy":0.5},{"t":2.6,"zoom":1.3,"cx":0.5,"cy":0.5}],
     "audio":"app","gain_db":0,"fade_in":0.0,"fade_out":0.1},
    {"type":"clip","id":"house_drums","clip":"clips/REPLACE.mp4","ss":0,"dur":6.5,
     "keys":[{"t":0,"zoom":1.3,"cx":0.5,"cy":0.5},{"t":6.5,"zoom":1.0,"cx":0.5,"cy":0.5}],
     "audio":"app","gain_db":0,"fade_in":2.0,"fade_out":0.2},
    {"type":"video","id":"end_typed","path":"cards/end_typed.mov"},
    {"type":"image","id":"end_card","path":"cards/end_card.png","dur":8.0,
     "keys":[{"t":0,"zoom":1.0,"cx":0.5,"cy":0.5},{"t":8.0,"zoom":1.04,"cx":0.5,"cy":0.48}]}
  ],
  "music": [
    {"file":"music/horn.wav","at":0.0,"track_in":0.0,"dur":19.0,
     "gain_db":-14,"fade_in":0.4,"fade_out":2.5},
    {"file":"music/horn.wav","at":39.0,"track_in":126.4,"dur":16.6,
     "gain_db":-9,"fade_in":1.5,"fade_out":0.0},
    {"file":"music/horn.wav","at":55.6,"track_in":143.0,"dur":8.4,
     "gain_db":-6,"fade_in":0.0,"fade_out":2.0},
    {"file":"music/horn.wav","at":65.0,"track_in":8.0,"dur":10.2,
     "gain_db":-17,"fade_in":1.5,"fade_out":3.0}
  ]
}
```

`at` for the two SYNC layers (rows 2–3 of `music`) is currently the
*estimated* start time of shot 9 / shot 10 (39.0 s, 55.6 s = sum of shots
1–8's estimated durations). **Once real clips are recorded**, re-run
`assemble.py`, read shot 9's and shot 10's actual `start` from the
`*_timeline.csv`, and use those instead — the two `track_in` values
(126.4, 143.0) never change, only `at` does.

The 4th music layer's `track_in: 8.0` (a quiet reprise under the end card)
is an unverified guess — nobody has listened to that part of the song
against picture yet. Pick whatever passage actually sounds good there by
ear; it's not sync-critical like the other two.

## Production notes

- Record each raw clip with `xcrun simctl io <udid> recordVideo --codec=h264 --force clips/<name>.mp4`,
  start it in the background and stop with SIGINT once the beat is done —
  same pattern as the test render (see below). Over-record a couple of
  seconds of padding on both ends of every clip; trim precisely with
  `compose.py --ss`.
- `compose.py` doesn't care whether a clip is the inner or outer display —
  it fits whatever aspect ratio ffprobe reports into the ~78%-of-frame box
  (or the paired layout for shot 8). Feed it the real recording and it
  reflows automatically.
- Gains above assume the app's own audio and the song are both roughly
  "normal" loudness masters; ffmpeg's `volumedetect` filter
  (`ffmpeg -i seg.mov -af volumedetect -f null -`) is the fastest way to
  check a layer isn't silent or clipping before trusting a gain number.
- If any shot's real footage runs a different length than planned, prefer
  changing that shot's own `dur`/`ss` over stretching it with `--speed`
  (speed changes are for stylistic effect — e.g. a fast-forward through
  a long finger-drumming take — not for hitting a duration target).
