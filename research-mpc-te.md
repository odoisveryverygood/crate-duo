# Research: MPC Sample + TE workflow/aesthetic for the iPhone Duo sampler/groovebox

Research for Bitrig Hacks, 2026-09-26 (hacking 11:30am-3:30pm). This is a research + design-spec document only — no Swift/app code. Companion files in this directory: `PLAN.md` (hackathon plan), `duo-api-cheatsheet.md` (confirmed Duo SDK APIs), `audio-ai-stack.md` (audio engine + AI stack research).

Confidence key (same convention as `duo-api-cheatsheet.md`): **[A]** = confirmed from an official/primary source (Akai/inMusic, Teenage Engineering, Apple). **[T]** = confirmed from reputable third-party coverage (Sound on Sound, MusicTech, established YouTube reviewers, Reddit consensus). **[U]** = unverified/inferred — flagged, do not treat as fact.

---

## A. Akai MPC Sample — workflow

Akai MPC Sample: a $399 compact standalone sampler released March 2026, positioned below MPC One/Live in Akai's lineup. **[T]** (MusicTech/MusicRadar reviews); primary sourcing below is Akai's own online guide (akaipro.com/guides/mpc-sample/*.htm) and the official manual excerpted via ManualsLib, cross-checked against reviews and Akai's support FAQ.

### A1. Hardware layout
- **16 RGB-backlit velocity-sensitive pads** with poly aftertouch, organized into **8 PAD BANKs lettered A–H** (128 sounds addressable total). **[A]** [akaipro.com/guides/mpc-sample/features.htm](https://www.akaipro.com/guides/mpc-sample/features.htm)
- **2.4" full-color LCD** with waveform display — small but high-res, **not a touchscreen**. **[T]** MusicTech, MusicRadar reviews
- Controls: **SHIFT**, **ENCODER** + **-/+**, **B1 / B2 / B3** function buttons (cycle display pages — context-sensitive, not fixed labels), **K1 / K2 / K3** knobs (plain pots, not endless/motorized), one **FADER**, **MAIN VOLUME** knob, built-in mic, built-in 3W speaker.
- **Mode buttons**: **SAMPLE, SEQ, PAD FX, KNOB FX**. **Pad-play/transport buttons**: **CHOP, LOOP, MUTE, 16 LEVELS, SAMPLE RECORD, SEQ RECORD, PLAY, STOP, SAMPLE SELECT, TAP TEMPO, NOTE REPEAT, ERASE.** **[A]** (same features.htm source) — these are the exact names to reuse verbatim for UI-label authenticity.
- Rear I/O: POWER, USB-C, REC GAIN knob, 2× 1/4" TRS in, 2× 1/4" TRS out, MIDI in/out, SYNC OUT (CV/gate), headphone out, microSD (up to 1TB). 8GB onboard storage / 2GB RAM, 32-voice polyphony, ~900g, 236×194×50mm.
- Battery life: reviews say 5h, Akai's own FAQ says "up to 6 hours" — **unresolved minor conflict, not important for our purposes.**

### A2. Sampling workflow (exact button flow)
- **SAMPLE RECORD** button → **K1** picks input source (**Mic / Rear line-in / "Resample"**) → **K3** sets record **Threshold** (a waveform icon lights up when incoming audio crosses the threshold — this is the literal arm/threshold mechanism) → tap the destination pad to start recording, tap again to stop.
- **Resample** = records the device's own internal mix back onto a pad ("record a sequence onto a single pad, freeing up other pads" — i.e. bake a whole beat down to free up voices/pads, same concept as "bounce").
- **SHIFT+SAMPLE RECORD = "Recall"** — grabs the last 25 seconds from the currently selected input source onto the next open pad, as a rolling capture buffer (useful for "oh that take was good, catch it retroactively").
- **[A]** [akaipro.com/guides/mpc-sample/sample_record_mode.htm](https://www.akaipro.com/guides/mpc-sample/sample_record_mode.htm)

### A3. Chopping workflow (exact chop types — this is the single most important section for our CHOP mode)
- **CHOP** button → **K3** selects **Chop Type**, with three named modes:
  1. **"Threshold"** (default) — auto-slices on transients/level, i.e. auto-chop by detecting hits.
  2. **"Regions 4/8/16"** — even/equal slicing into a fixed number of equal-length pieces (4, 8, or 16).
  3. **"Manual"** — tap-to-slice live while the sample plays, up to 16 slices.
- **K1/K2** = adjust slice **Start/End** (0–100%) for the selected slice. Per-slice **"Extract"** exports a slice as its own new sample; **"Split"** divides further; **"Trim Sample"** permanently shortens the whole sample to the current Start/End.
- Slices **auto-map one-per-pad** once chopped — this confirms the "chop to pads" behavior the brief asked about is automatic, not a separate manual assignment step.
- **[A]** ManualsLib manual excerpt (Pad Play section); [akaipro.com/guides/mpc-sample/pad_play.htm](https://www.akaipro.com/guides/mpc-sample/pad_play.htm)

### A4. Pad assignment
- **SAMPLE mode** is described as the device's "main mode... trigger your samples, view and edit their parameters" — one sample per pad, per bank.
- Per-pad parameters: **Mute Group** (Off, 1–16), **Pad Link** (Off, 1–16 — two pads fire together), **Offset** (0–100% trigger delay). **[A]** ManualsLib excerpt, Sample Mode section.

### A5. Pad modes
- Confirmed present: **16 LEVELS** (copies one sample across all 16 pads with a ramped parameter — e.g. velocity or pitch ramp across the bank, the classic MPC "16 Levels" concept), **MUTE** (SHIFT+MUTE = unmute all), **LOOP** (SHIFT+LOOP = "Reverse"), **"Note On"** (SHIFT+CHOP — plays only while held, i.e. gate mode), **Mono/Poly** polyphony setting.
- **NOTE REPEAT** exists as a named physical button (confirmed on the Features page) but its exact time-division behavior on this specific model is **UNVERIFIED** — the manual's detail page for it 404'd.
- **"Full Level" and "Roll" were NOT found anywhere** in the accessible MPC Sample documentation (Features / Pad Play / Sample Mode pages), despite targeted searching — **likely cut from this simplified/entry model** vs. bigger MPCs. Flagged as unverified-by-absence, not a confirmed negative.

### A6. Sequencer
- Pad-per-sequence selection with queueing (pad lit green = has recorded events, blinking = queued to play next).
- **BPM**: SHIFT+B1+ENCODER, or **TAP TEMPO** button. **B2** toggles **"SEQ"** (per-sequence BPM) vs **"GBL"** (global BPM) — i.e. each sequence can carry its own tempo or follow a global one.
- **Quantize**: **K2** = **"Time Correct" Q value** (e.g. 1/16); **B3** toggles record-quantize on/off.
- **Swing**: **K3** = **"RT Swing"** — exact numeric range **UNVERIFIED**.
- **Sequence length**: **K1** = 1 / 2 / 4 / 8 / 16 / 32 / 64 / 128 bars; **SHIFT+K1** = custom length, 1–128 bars.
- **Count-in**: SHIFT+PAD4 ("COUNT-IN").
- **ERASE** button removes samples/sequences/events (exact live-vs-stopped erase behavior not detailed the way EP-133's was).
- **Step Edit** (SHIFT+SEQ, a.k.a. "STEP EDIT" — ENCODER moves between steps) and **Song Mode** ("create a list of sequences... export as audio file or new sequence") are both confirmed present in the manual's table of contents.
- **[A]** [akaipro.com/guides/mpc-sample/sequence_mode.htm](https://www.akaipro.com/guides/mpc-sample/sequence_mode.htm); ManualsLib TOC pp.43-44
- Claims sourced only from search synthesis, not a direct manual quote (lower confidence): "automatic overdub on loop repeat," "undo erases current pass."

### A7. Track/pad FX
Four separate FX engines — an important structural detail for our FX mode design:
1. **Pad FX** (PAD FX button) — pads 1–16 double as 16 different effect selections; pressure-sensitive wet amount via aftertouch; up to 4 simultaneous; **B1 = "Latch"** (keep the effect on without holding).
2. **Flex Beat** — 16 time-warping effects (pitch/time/volume glitches, scratches, trance-gate).
3. **Knob FX** (KNOB FX button) — K1–K3 control one effect applied across many pads at once.
4. A standalone **Compressor**.
- Akai's own FAQ claims "28 different effects" (Knob FX) + "16 selectable" (Pad FX) + "16 Flex Beat" ≈ **60 total effects**, matching review claims of "60 effect types." Individual names only partially confirmed (Half Speed, Chorus, Compressor, Granulator, Ring Mod, Reverb, Beat Repeat, Color-Compressor, Lo-Fi) — the full 60-item list is **unverified**.
- **Important limitation, per MusicTech**: "effects cannot be applied per-track or recorded into sequences" — the workaround is resampling (bake the effect in by resampling), which is the same non-destructive-vs-live tension we saw on the EP-133 (B3/B6).

### A8. Chromatic/keyboard mode — CONFIRMED ABSENT on MPC Sample
- MusicRadar, directly: the device "doesn't have a track-based structure like its bigger siblings," "is a purely sample-based instrument" with "one sample per pad" — closer to a Roland SP-404 than a modern full MPC. No Keygroup/chromatic mention anywhere in the accessible MPC Sample docs.
- **Keygroup/chromatic-across-pads is a real, named feature on bigger MPCs** (One, Live, X, 5000) — it is explicitly cut from MPC Sample. **For our hackathon spec, KEYS mode should be modeled on the EP-133's mechanism (see B2) and the bigger-MPC Keygroup concept, not on MPC Sample, since Sample itself doesn't have it.**

### A9. AI / stem-separation features — CONFIRMED ABSENT on MPC Sample
- **"MPC Stems"** (a real, zPlane-powered AI stem-splitting feature that separates a track into Vocals/Bass/Drums/Other) is documented across ~6 independent Akai announcement articles, but **only** for MPC desktop software and the standalone MPC One/Live/X. MPC Sample is never named in any of them, and its own guide/FAQ never mentions stems or AI.
- This is an inference from consistent omission across sources, not an explicit "MPC Sample does not have this" statement from Akai — but it's a strong inference given how thoroughly the feature is documented elsewhere and never once mentioned for Sample.
- **Implication for our pitch**: our app's "AI-native" angle (Claude driving the groovebox, and/or AI stem-splitting a reference track into pads) is not just aesthetic borrowing — it's a real capability gap in the actual hardware we're referencing, which is a legitimate differentiator to say out loud in the demo ("MPC Sample can't do this; we can").

### A10. What distinguishes MPC Sample from MPC One / Live
| | **MPC Sample** | **MPC One / Live** |
|---|---|---|
| Structure | Single-track / one Drum Program at a time (can't load a second kit alongside the first) | Full track-based "MPC OS," multitrack |
| Plugins/VST | None | Full plugin/VST instrument support |
| Screen | 2.4", non-touch, small LCD | Large touchscreen |
| Chromatic/Keygroup | Absent (A8) | Present |
| AI stems | Absent (A9) | Present ("MPC Stems") |
| Portability | Battery + built-in mic + built-in speaker — fully self-contained/portable | Desktop/mains-oriented (Live has battery, but design intent is studio/stage rig, not pocket sketchpad) |
| Positioning | Explicitly marketed as a beginner "sketchpad" for quick ideas — export to a full MPC/DAW recommended for serious mixing | Complete standalone production system |
| Price | $399 | $700+ |

This distinction is directly useful for pitching our app: we're deliberately building **MPC Sample's constrained, immediate, "sketchpad" workflow** (not MPC One/Live's full DAW-replacement complexity) — matching the hackathon's 4-hour reality — while adding the one thing Sample structurally lacks (AI) as our wedge.

### A11. Research gaps (MPC Sample)
Battery life (5h vs. 6h, minor); NOTE REPEAT's exact time-division behavior; whether Full Level/Roll are truly absent vs. just undocumented; RT Swing's numeric range; the complete 60-effect name list; "automatic overdub on loop repeat" and "undo erases current pass" (search-synthesis sourced, not a direct manual quote); MPC Stems' absence on Sample is inferential (strong, but not an explicit denial from Akai).

## B. Teenage Engineering EP-133 K.O. II — workflow

### B1. Hardware layout
- **12 pressure- and velocity-sensitive pads** (keypad layout, like a phone dial pad) — one fewer than the traditional MPC 16. Screen is TE's "world's first super segment hybrid display" — a combined segment + dot-matrix readout, small alphanumeric (~3 characters). **[A]** [teenage.engineering/products/ep-133](https://teenage.engineering/products/ep-133); **[T]** [Sound on Sound](https://www.soundonsound.com/reviews/teenage-engineering-ep-133-ko-ii)
- **4 knobs**, unlabeled/assignable (FX levels, tempo, swing, compressor speed). On-unit **KNOB X / KNOB Y** are the two primary assignable data knobs; SHIFT+knob = fine adjustment. **One physical slide FADER** — default is group volume/FX send, hold FADER for alternate assignable functions. **[A]** [teenage.engineering/guides/ep-133](https://teenage.engineering/guides/ep-133/buttons-and-combos)
- **GROUP A / B / C / D** buttons: each group is its own bank of **12 sounds + 99 patterns** + its own FX send — i.e. "group" = bank in MPC terms. **[A]** [teenage.engineering/guides/ep-133/buttons-and-combos](https://teenage.engineering/guides/ep-133/buttons-and-combos)
- Central **MINUS / PLUS** buttons navigate scenes/patterns/steps/bars/FX/tempo/sound-select (one shared nav pair, not per-menu buttons). **SHIFT** unlocks secondary functions on every button (e.g. SHIFT+SOUND = Sound Edit). Confirmed exact dedicated mode/button names: **SAMPLE, KEYS, SOUND, MAIN, TEMPO, FX, TIMING, RECORD, PLAY, ERASE.** **[A]** [teenage.engineering/guides/ep-133/modes](https://teenage.engineering/guides/ep-133/modes)
- Specs: 128MB memory, 999 sample slots, 9 projects × 80,000 notes, 46.875kHz/16-bit sampling (32-bit float internal chain), 12 stereo/16 mono voices, built-in mic + speaker, 4×AAA (~20h) + USB-C, MIDI I/O, Sync I/O, 240×176×16mm, 620g. **[A]** [teenage.engineering/products/ep-133](https://teenage.engineering/products/ep-133); **[T]** [MusicTech](https://musictech.com/reviews/hardware-instruments/teenage-engineering-ep-133-ko-ii-review/)
- Visual character: "Game Boy-inspired grey plastic," iPad-ish footprint, described by reviewers as a "retro aesthetic inspired by '80s calculators and early Akai MPCs." **[T]** MusicTech, Sound on Sound (same URLs as above)

### B2. SAMPLE mode vs KEYS mode (exact mechanism)
- **SAMPLE mode**: press **SAMPLE** — receiving pads blink; cycle input source (mic / line-in mono / line-in stereo / resample / USB) via MINUS/PLUS; **hold a pad to record, release to stop** — recording is bound directly to the physical pad hold, not a separate transport button. SHIFT+pad latches hands-free record. Gearnews hands-on: "press the sample button, set the recording level and threshold, press one of the illuminated pads, and release the button as soon as the recording is finished." **[A]/[T]** [gabrielroth.com/ko2](https://gabrielroth.com/ko2/); [Gearnews](https://www.gearnews.com/teenage-engineering-ep-133-k-o-ii-review-better-than-an-mpc/)
- **CHOP mode** = SHIFT+SAMPLE. Two paths: **Auto-Chop** (beat-tracking "lazy chop" that auto-divides a breakbeat across pads, with "equal length" and "attack mode" sub-options) vs **Live/manual chop** (place chop points manually while audio plays; refine start/end with KNOB X / KNOB Y). **[A]** [teenage.engineering/guides/ep-133/functions](https://teenage.engineering/guides/ep-133/functions); **[T]** Gearnews (above)
- **KEYS mode**: select the pad holding the sample, press **KEYS** — the same 12-pad grid becomes a chromatic mini-keyboard for that one sample. Hold KEYS+MINUS/PLUS = octave shift (wraps at range limits); hold KEYS+pad = set a new root note. Recording/step-record/erase work identically in KEYS mode as in SAMPLE mode. **Mode switching is one dedicated physical button each — no menu diving**, which is the single most important authenticity detail for our UI. **[A]** [teenage.engineering/guides/ep-133/play-and-record](https://teenage.engineering/guides/ep-133/play-and-record)

### B3. Punch-in FX ("Punch-In FX 2.0™")
- Mechanism: **hold FX + press pad(s)** while the sequence plays → live effect fires; effects are **pressure-sensitive** (harder press = more intense filter sweep / faster stutter / etc.); multiple FX pads are stackable simultaneously. While FX is held, GROUP A–D buttons become momentary/stackable solos; the FADER keeps whatever it's currently assigned to. **[A]** [teenage.engineering/guides/ep-133/effects](https://teenage.engineering/guides/ep-133/effects)
- **Two distinct FX layers — do not conflate them:**
  (a) **6 send/group effects** (one active per group at a time), TE's own descriptions: Delay ("like a valley or a fish bowl"), Reverb ("massive church or a tiny room"), Distortion ("beat up your beat and punch it down"), Chorus ("get wavy"), Filter, Compressor — plus a master compressor. **[A]** (same URL)
  (b) **12 punch-in/performance effects**, one per pad while FX is held. UNVERIFIED: could not confirm the complete exact list of all 12 names from TE's own page (likely JS-rendered content not fully captured); secondary synthesis suggests lowpass/highpass filter, bitcrusher, beat-repeat/stutter, FX-send boost, pitch warp, sample-replace are among them. **Tape-stop is commonly associated with TE gear in general but is NOT confirmed specifically for K.O. II — mark UNVERIFIED.**
- Reviewer-flagged limitation, useful for us to know: MusicTech — punch-in FX "can't be recorded as part of a pattern" (it's a live-only performance overlay, not baked into the sequence by default). Sound on Sound flags "lack of a way to individually treat sounds with effects" (FX apply per-group, not per-sample). **[T]** [MusicTech](https://musictech.com/reviews/hardware-instruments/teenage-engineering-ep-133-ko-ii-review/); [Sound on Sound](https://www.soundonsound.com/reviews/teenage-engineering-ep-133-ko-ii)

### B4. Main fader behaviour
- Physical slide fader (not touch/capacitive). Default assignment = group volume/send level; reassignable via hold-FADER for alternate functions. No source confirms spring/snap-back — treat as a standard manual slider (no auto-return). **[T]**
- **"Fadergate"**: a real QC incident — early units shipped with unresponsive faders from inadequate packaging. TE co-founder David Eriksson on the fix: redesigned packaging + automated drop-testing. Also reported on early units: dead speakers, boot failures, pattern-deleting bugs. **[T]** [MusicTech interview](https://musictech.com/features/interviews/teenage-engineerings-ep-133-ko-ii-limitations-fadergate/)
- Design-philosophy quote worth stealing for our own pitch: Eriksson argues deliberate constraints (small memory, ~20s max sample time, 12-voice polyphony) create character like vintage gear, and reduce decision fatigue — producer Ricky Tinez concurs in the same piece. **[T]** (same URL)

### B5. Sequencer (verbatim mechanics from TE's own guide)
- **Record with count-in**: press-and-release RECORD, then press PLAY → 4-beat count-in, then recording starts. **Without count-in**: press RECORD and PLAY together. **Stop**: PLAY again pauses; RECORD drops out of record but keeps playing.
- **Overdub**: press PLAY to start the pattern, then hold RECORD and hit pads to add notes into the existing beat.
- **Step record**: hold RECORD and press a pad to place that pad on the currently-selected step.
- **Erase**: hold ERASE+pad *live* = clears that pad's notes in real time as you hold; hold ERASE+pad *while stopped* until "TRK blinks" = wipes all notes on that pad; ERASE+FADER = removes fader automation.
- **Quantize**: TIMING button, MINUS/PLUS toggles snap-to-grid vs free-time; SHIFT+TIMING = "Timing Correct" (selectively nudge/quantize individual already-recorded notes after the fact, not just live). **Swing**: TIMING+KNOB Y, applies to 1/8 and 1/16 resolutions only. Resolutions available: 1/1, 1/2, 1/4, 1/8, 1/8T, 1/16, 1/16T, 1/32. **Note Repeat**: hold TIMING+pad = retrigger at the current grid interval, and it's pressure-sensitive.
- **Pattern length**: up to 99 bars. Song mode is a point of source conflict: MusicTech's review says "no song mode for chaining patterns," while TE's own spec sheet claims Song Mode "chains 99 scenes up to 9,801 bars total." Likely reconciled as: there is no traditional linear pattern-list, but COMMIT-based scene-chaining (see B6) achieves the same result — flagged as not fully resolved.
- **[A]** [teenage.engineering/guides/ep-133/play-and-record](https://teenage.engineering/guides/ep-133/play-and-record); [teenage.engineering/guides/ep-133/buttons-and-combos](https://teenage.engineering/guides/ep-133/buttons-and-combos)

### B6. COMMIT — precise mechanism
Verbatim quotes from TE's own workflow guide, **[A]** [teenage.engineering/guides/ep-133/workflow](https://teenage.engineering/guides/ep-133/workflow):
> "use commit to create an arrangement of patterns then 'commit' this arrangement as a scene."
> "commit is also a great way of duplicating the current scene so you can add variations to your patterns."
> "use the instant commit feature to experiment with variations without ever having to stop the music."
> "commit before punching in new sounds to quickly build up the structure of your song!"

Mechanism: COMMIT **duplicates/freezes the current live scene** (the 4 groups' pattern arrangement) into a checkpoint — non-destructively, without stopping playback — then lets you keep punching in new changes to build the *next* section. It's a live, non-linear way to arrange a song by **checkpointing states** rather than programming a song list. It operates at the **scene/pattern-arrangement level**, not the audio-render level — it does **not** bake live punch-in FX permanently into the sample (those remain a separate, unrecorded live performance layer per MusicTech, consistent with B3). The exact button combo (reportedly SHIFT+MAIN) is corroborated only by a fan reference and a YouTube short, not restated verbatim on the official page text retrieved — **mark the specific combo UNVERIFIED-against-primary**, though the mechanism itself is primary-confirmed.

### B7. Sampling in / resampling
- Input sources: mic, line-in mono, line-in stereo, **resample (internal)**, USB. TE's own definition of resample: "take multiple samples and combine them into one longer sample" / "stack and time stretch whole sections." **[A]** [teenage.engineering/guides/ep-133/functions](https://teenage.engineering/guides/ep-133/functions)
- CONFLICT noted: Sound on Sound's review lists "cannot sample during playback or resample internally" as a limitation, contradicting the current official resample-source claim — most likely explained by a post-review OS update (MusicTech separately references "K.O.II's first major OS update"). Treat the **current/official state as resample-capable**.
- **No AI or stem-separation features anywhere** on this device — confirmed absent across the official functions page and every review consulted.

### B8. What makes it "feel good" / fast (reviewer language, useful for our copy/tone)
- Gearnews: sampling is "a fast and immediate process." Sound on Sound: "once you've learned the basics it's just so quick to create on, and it lends itself to jamming out ideas through organic play rather than fine programming." MusicTech: "fun factor" is central — "a creative, energising groove box" (7/10) that "shines in personality and design" but "lacks deep sculpting tools and seamless DAW integration" vs. SP-404 MkII/Push/Move, and is criticized for "awkward feature navigation, a steep learning curve, and tiny storage."
- Gearnews frames the philosophical contrast with MPC directly, which is gold for our part E prioritization: EP-133 users "primarily play the individual parts in real-time" (quantize/shuffle optional, on top) **vs. MPC's step-sequencer-first paradigm**; 12 pads vs. MPC's traditional 16.
- **[T]** [Sound on Sound](https://www.soundonsound.com/reviews/teenage-engineering-ep-133-ko-ii); [MusicTech](https://musictech.com/reviews/hardware-instruments/teenage-engineering-ep-133-ko-ii-review/); [Gearnews](https://www.gearnews.com/teenage-engineering-ep-133-k-o-ii-review-better-than-an-mpc/); [MusicTech Fadergate interview](https://musictech.com/features/interviews/teenage-engineerings-ep-133-ko-ii-limitations-fadergate/)

### B9. Research gaps (EP-133)
- Official B&H-hosted PDF manual returned HTTP 403; TE's own live guide site (teenage.engineering/guides/ep-133/*) was used instead and is the current primary source anyway.
- Could not surface Reddit r/teenageengineering threads or a Loopop review transcript in this pass (tool/retrieval limitation, not absence of discussion).
- Weakest-verified item: the complete exact list of all 12 individual punch-in/performance-FX names — the mechanism is primary-confirmed, the full name list is secondary-source-only.

## C. TE visual language

**Important correction to the brief's premise:** EP-133 K.O. II's 4 GROUP A–D buttons are **not** differently colored physically — multiple sources confirm they're uniformly light grey, and the 12 pads are uniformly dark grey. The hardware is close to pure greyscale; group differentiation (e.g. A=drums, B=bass, C=melodic, D=blank) is a software/content convention, not a color cue on the case. **[T]** Sound on Sound review; soundtech.co.uk guide (via search synthesis). Any group color-coding in our app should live on-screen, matching the OP-1 pattern below (screen color tied to a control), not imitate a nonexistent physical color code on the EP-133 itself.

### C1. Color palette
**No official TE brand-guideline hex codes were found anywhere** (official site, press kit, Brandfetch all came up empty or blocked). Everything below is fan-estimated or read off product photos — treat as **[U]** unless noted otherwise, and pick-and-commit rather than treat as solved fact:
- Fan palettes disagree on the orange itself: one design essay asserts `#ff6600` (blakecrosley.com, unsourced); community palettes on color-hex.com give `#fa5b1c` / `#ff106a`-adjacent sets (lower confidence — pulled via search snippet, not direct fetch). **Recommendation: use `#FA5B1C`** (safety-orange, "TE orange" zone) as our one accent — it's the most-repeated value across fan sources.
- **Best-grounded grey ramp** — a 9-step fan-extracted monochrome ramp from actual OP-XY product graphics (lospec.com/palette-list/teenageengineering-op-xy), indirectly corroborated by TE's own TX-6 product page stating its knobs/sliders use "scales of gray to match OP–XY":
  `#F6F4F4` (near-white) · `#AFAFB3` · `#95959A` · `#797982` · `#606069` · `#484850` · `#2F2F36` · `#16161D` · `#000000` (near-black)
  **Recommendation for our UI**: body background `#16161D`, panel/card `#2F2F36`, borders/dividers `#484850`, secondary text `#95959A`, primary text `#F6F4F4`.
- **OP-1 Field DOES have real color accents** (unlike EP-133): its 4 rotary knobs are colored blue / ochre / grey / orange, matching color-coded on-screen labels next to each knob — muted "field" tones, not bright primary colors (the original 2011 OP-1 had brighter blue/green/white/orange; OP-1 Field's 2022 palette is more desaturated). No exact hex published; **[U]** for exact values.
- TX-6 is essentially colorless: anodized aluminum, grey encoders matching OP-XY, a darker "Field System Black" variant exists.
- **Pattern to steal**: color accents concentrate on the OP-1 line (knob + matching screen icon) and on branding (the orange logo); the sampler/utility line (EP-133, TX-6, OP-XY) is near-pure greyscale hardware with any color living on-screen. For our app: keep the deck (hardware-analog chrome) greyscale, and put the one TE-orange accent only on-screen for active/armed state — this is more authentic than color-coding physical-looking group buttons.

### C2. Typography
- TE's own website ships custom-subset **Univers** webfonts ("UniversTE20T"/"UniversTE40L") — Univers is Adrian Frutiger's 1957 grotesque (a Helvetica/Akzidenz cousin), **proportional, not monospace**. **[T]** typ.io/s/4ozt.
- Conflicting claim: one design essay (blakecrosley.com) asserts TE uses "exclusively monospaced font throughout all products." This conflicts with the Univers finding above; likely the essay is reading TE's tabular/aligned spec numerals (and the hardware's own segment-digit glyphs, which aren't a distributable font) as "monospace" when the actual web/print face is proportional. No primary source resolves the conflict — flagged, not resolved.
- No verified proprietary TE typeface beyond the Univers license; fans hunt for an "OP-1 font" recreation on dafont.com forums, but nothing confirms one exists as a distributable file.
- **Recommended pairing for our app**, from the requested candidate set (Doto, Space Mono, JetBrains Mono, Departure Mono, IBM Plex Mono, Inter) — this is the fork's synthesis, reasoned from the display-style findings in C3, and is the most actionable part of this section:
  - **Hero numeric readouts** (BPM, bar:step counter, pad number, big transport digits): **Doto**, heavy weight. Its dot-matrix construction is the closest free match to EP-133's segment/icon hybrid display and to Pocket Operator-style LCD numerals — reads as "device screen," not "app UI."
  - **Secondary numeric/telemetry** (knob value pop-ups, ms/dB, timestamps): **JetBrains Mono** or **IBM Plex Mono** — both have true tabular figures. Plex Mono is rounder/warmer (closer to Univers' warmth); JetBrains Mono reads more geometric/technical. Pick JetBrains Mono if leaning technical, Plex Mono if leaning warm/analog.
  - **Small uppercase case labels** (mode names, button labels, group tags — "SAMPLE," "CHOP," "KEYS"): **Space Mono**, tracked-out uppercase. Its slab-ish quirk at small sizes reads like a silkscreened case label. (Departure Mono is a rawer pixel/terminal alternative but less legible at very small sizes — reserve it for a decorative flourish only, not primary labels.)
  - **Body/help text** (anything longer than a label): **Inter** — the only proportional face in the set; use it where mono would slow reading (help text, onboarding copy). Keep it out of anything that should feel like "the machine," i.e. never on transport/pad labels.
  - **Time-constrained fallback if we only load two fonts**: **Doto** for the hero counter + **JetBrains Mono** (uppercase/letterspaced for labels, regular case for values) for everything else.
  - All six candidate fonts are free/OFL on Google Fonts.

### C3. Display style
- **OP-1 / OP-1 Field**: AMOLED screen, minimal vector line-art icons on black, flat single-color fills, no gradients. Icons are witty reduced pictograms rather than literal/skeuomorphic — cited example: the "punch" tape-stop/filter effect is illustrated as a line-art boxer (a visual pun), not a filter-curve icon. **Screen graphics are color-coded to match the physical knob that controls that parameter.** OP-1 won a 2012 Swedish Design S Award; committee quote: "a clever colour scheme and fantastic graphics is intuitive, easily accessible and incredibly inviting." **[A/T]** en.wikipedia.org/wiki/Teenage_Engineering_OP-1 (design-award citation sourced on that page).
- **EP-133 K.O. II**: marketed explicitly as the "world's first super segment hybrid display" — classic segment-digit numerals (calculator/clock style) plus a fixed surrounding bank of **66 custom backlit icon indicators** — explicitly **not** a full bitmap/dot-matrix screen. Reviewer description: "a basic three-character read-out with a bank of backlit indicators," styled to evoke "1980s handheld games / old Casio calculators... a miniaturised MPC-60." Monochrome backlight, not full color. **[A]** teenage.engineering/products/ep-133, teenage.engineering/guides/ep-133; **[T]** Sound on Sound.
- **Synthesis for us**: OP-1's language is an "illustrated dashboard" (vector icons, full-screen per-mode takeover, color tied to hardware); EP-133's language is a "calculator readout" (segment numerals + icon lamps, no bitmap graphics). Since our app needs MPC Sample's real waveform/touchscreen workflow wearing TE's skin, the recommended split is: render the actual waveform/step-grid content in the **OP-1 manner** (flat vector line art, black background, no gradients, one flat color per element), and reserve **segment-digit styling** for numeric readouts only (BPM, bar:beat, pad number) to sell the "hybrid display" illusion without pretending the whole screen is a 1980s calculator.

### C4. Labels / icon style
- Confirmed exact official EP-133 mode/button names — directly reusable as authentic UI label text: **MAIN** (home screen), **SOUND** (pad/sample edit, with sub-tabs Sound / Trim / Envelope / Time / MIDI / Mute Group), **TEMPO** (40–399 BPM range), **SHIFT** ("gateway to other functions or menus"), **GROUP A/B/C/D**, **PLUS/MINUS**, pads doubling as a numeric keypad, **Fader**, **Knob X** / **Knob Y**. **[A]** teenage.engineering/guides/ep-133/modes, /buttons-and-combos.
- Small uppercase sans labels silkscreened directly on the case beside each control, printed numbers next to knobs/ports/pads — consistent across every TE product checked (OP-1, EP-133, TX-6). Described independently as a "brutalist grid system" with exposed, spec-sheet-like labeling.
- Icon style avoids skeuomorphic DAW icons in favor of witty reduced line-art pictograms (the boxer/"punch" example); on EP-133 specifically, icons are a fixed bank of small backlit glyphs rather than freeform screen icons.
- Negative space / restraint carries into packaging too (OP-1's pressed-paper box + rubber-band closure) — same minimal-parts philosophy end to end.
- Caveat: no leaked/official brand-guideline PDF with exact type sizes/tracking/grid rules was found — all of this is triangulated from product pages, reviews, and design essays, not a style guide.

### C5. Button shapes and shadows
- **EP-133 K.O. II**: 12 pads are dark grey, square-ish, pressure- and velocity-sensitive (PA66 polyamide housing over a pressure-sensitive film layer). Reviewers compare the feel/look to a "miniaturised MPC-60" and "old Casio calculator" keys — squared-off, low-profile, matte, **not** tall glossy MPC-style pads. **[A/T]**
- **OP-1/OP-1 Field**: circular knobs (small diameter, colored caps per C1); low-profile aluminum body with soft-touch back cover.
- **TX-6**: CNC aluminum with 2K molding, custom encoders/faders; knobs are small/tightly spaced enough that reviewers note they can be fiddly for thicker fingers.
- **Flat vs. shadow**: convergent picture across all sources — flat design, hard edges, no gradients/bevels/drop-shadows anywhere, on the case silkscreen or on-screen graphics. One blogger's stronger formulation ("zero border-radius... angular, never rounded") is consistent with the product photos reviewed but is that blogger's characterization, not an independently pixel-verified spec — treat the "never rounded" absolutism as **[U]**, but "flat, no shadow" as well-supported.
- **Recommendation for our UI**: flat fills, 1px hairline borders instead of shadows, sharp or very slightly rounded corners (2-4px, not pill-shaped), no drop shadows anywhere except perhaps a single subtle inset line to fake "pressed" state on pads.

### C6. Animation feel — UNVERIFIED, flagged clearly
No source (official or third-party) explicitly discusses OP-1/EP-133 on-screen UI animation timing, easing, or transition style. Given the documented "flat, minimal, no ornamentation, full-screen per-mode takeover" pattern, a reasonable **inference** (not a citable fact) is: fast/near-instant transitions, little or no easing curve, hard-cut mode switches rather than crossfades or slides. **Recommendation: animate state changes in ≤100ms with linear or a very slight ease-out, never bouncy/spring easing** — springy motion reads as "consumer app," not "instrument."

### C7. Reference image URLs
(Thumbnails below are 128px srcset images from TE's asset CDN — open the product page for full-res hero art rather than hotlinking for anything presentation-quality.)
- OP-1 Field, front view — page: https://teenage.engineering/products/op-1 — thumbnail: https://assets.teenage.engineering/_img/627ca7d80e44b900044f3c06_128.png
- EP-133 K.O. II, front view (display + 12 pads) — page: https://teenage.engineering/products/ep-133 — thumbnails: https://assets.teenage.engineering/_img/654e36ff255502e470bf1e4e_128.webp and https://assets.teenage.engineering/_img/652d23740b4176bcaf401fd2_128.webp (pad close-up)
- TX-6, top view — page: https://teenage.engineering/products/tx-6 — thumbnail: https://assets.teenage.engineering/_img/66e88d84451b14e0fd01dbb0_128.webp
- EP-40 Riddim — page: https://teenage.engineering/products/ep-40 — thumbnail: https://assets.teenage.engineering/_img/6903d117566ca728d1bf2c05_128.webp
- TE product lineup / press shots (index; click through for hi-res downloads): https://teenage.engineering/press/teenageengineering
- Bonus reference (fan-vectorized OP-1 icon set — useful for exact icon vocabulary, not an official asset): https://www.figma.com/community/file/1108269080565562838/op-1-field-screen-graphics

## D. Design spec: our app on iPhone Duo

### D0. Governing choices, stated up front
- **Workflow skeleton = MPC Sample** (16 pads/banks/SAMPLE→CHOP→SEQ loop). **Chromatic KEYS mode = EP-133/bigger-MPC Keygroup** (borrowed, since MPC Sample itself lacks this — A8). **Visual skin = TE** (greyscale body + one orange accent, flat/no-shadow, Doto/JetBrains/Space Mono/Inter type stack — C1/C2/C5). **AI = our wedge**, filling the real capability gap MPC Sample has (A9).
- Two-display layout is grounded in `/Users/shuhanzhang/duo-hack/duo-api-cheatsheet.md`: `ArrangementView` with `.split` (top = primary, bottom = secondary) for laptop pose, `reservedRegions(kind: .division)` to keep controls clear of the fold, `.onHingeChange`/`hinge.angle` for the FX mapping only — **never for layout**, per Apple's own explicit guidance already flagged in that file.

### D1. Pad grid: 4×4 (16 pads), not a 12-key keypad — recommendation and reasoning
**Recommend 16 pads in a 4×4 grid.** Reasoning:
1. **Workflow fidelity**: the device we're told to mimic literally has 16 pads in 8 lettered banks (A1), and its own chop system is built around the number 16 — "Regions 4/8/16" and "16 LEVELS" (A3, A5). A 12-key layout would fight the workflow at every turn.
2. **Legibility at demo distance**: 16 pads in a square reads unambiguously as "MPC/groovebox" to judges; a 12-key phone-style pad (EP-133's actual choice, B1) reads as "dial pad" unless you already know EP-133. Since our aesthetic is TE but our *workflow* claim is MPC, the grid shape should say "MPC" at a glance.
3. **Ergonomics favor bigger pads, not more pads**: the inner display is ~1878×2670px (duo-api-cheatsheet.md §1); in laptop pose the bottom half is a roomy landscape region even after the hinge gap. A 4×4 grid gives large, satisfying touch targets with room to spare — there's no space pressure pushing toward a denser 12-key layout.
4. **Banks simplify state**: reusing one fixed 16-pad layout across banks (we recommend **A–D**, 4 banks — splitting the difference between MPC's 8 and EP-133's 4, and matching TE's own GROUP A–D naming from B1) is a simpler state model for a 4-hour build than juggling different physical-layout overlays.
- Standard MPC pad numbering (bottom-left = 1, increasing right then up, so pad 16 is top-right) is the authentic numbering to use.

### D2. Top display layout — laptop pose (landscape region above the fold)
```
┌────────────────────────────────────────────────────────────┐
│ A · 03 · KICK_808                     CLAUDE: LISTENING ●  │  <- current bank·pad·name (left) / AI status (right)
│                                                              │
│   ╱╲    ╱╲╱╲          ╱╲                      ╱╲            │
│  ╱  ╲  ╱    ╲╱╲      ╱  ╲    ╱╲╱╲           ╱    ╲          │  <- waveform: flat vector line art, black bg (C3)
│ ╱    ╲╱        ╲    ╱    ╲  ╱    ╲         ╱      ╲         │
│   ┆      ┆    ┆      ┆   ┆      ┆    ┆    ┆    ...  ┆       │  <- chop markers: thin TE-orange vertical ticks
│   1      2    3      4   5      6    7    8         16      │     numbered underneath, small Space Mono uppercase
├────────────────────────────────────────────────────────────┤
│ ■ ■ □ □  ■ □ □ □  ■ ■ □ □  □ □ ■ □                           │  <- 16-step grid strip for the SELECTED pad (D6 note)
├────────────────────────────────────────────────────────────┤
│ 120.0 BPM        SWG 54%        BAR 03/08                   │  <- Doto numerals, JetBrains Mono uppercase unit labels
└────────────────────────────────────────────────────────────┘
```
- **Waveform + chop markers**: OP-1-manner flat vector line, one color, black background, no gradient (C3). Chop markers are thin ticks in the TE-orange accent (`#FA5B1C`, C1) with small numbers below in tracked-out **Space Mono** uppercase (C2). This is also where **CHOP mode's** Threshold/Regions-4-8-16/Manual controls live (mirrors A3 exactly).
- **16-step grid strip**: a single-row, 16-box strip showing which steps trigger the *currently selected pad* in the current bar — this doubles as MPC Sample's confirmed **Step Edit** mode (A6): tap a box to toggle a step directly, in addition to live pad-tap recording. Playhead lights the current step as it plays.
- **BPM/swing/bar readout**: big numerals in **Doto** (dot-matrix, reads as "device screen" per C2/C3), small uppercase unit labels in JetBrains Mono. Mirrors MPC Sample's SEQ/GBL BPM toggle and RT Swing (A6) and EP-133's TIMING+KNOB Y swing (B5).
- **Pad name + AI status row**: pad name in Space Mono uppercase; AI status is a small labeled dot with states **IDLE → LISTENING → THINKING → APPLYING**, matching the Claude tool-calling loop already validated in `/Users/shuhanzhang/duo-hack/audio-ai-stack.md` (URLSession → `api.anthropic.com/v1/messages`, model `claude-sonnet-5`, tool-calls mutate pattern/mixer state) — this status row is the honest visual readout of that loop, not new AI design.

### D3. Bottom deck layout — laptop pose
```
┌────────────────────────────────────────────────────────────┐
│ [SAMPLE] [CHOP] [KEYS] [SEQ] [FX]        BANK [A][B][C][D]  │  <- mode row / bank row
│                                                              │
│   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                           │
│   │ 13  │ │ 14  │ │ 15  │ │ 16  │                           │
│   └─────┘ └─────┘ └─────┘ └─────┘                           │
│   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                           │
│   │  9  │ │ 10  │ │ 11  │ │ 12  │        4×4 pad grid        │
│   └─────┘ └─────┘ └─────┘ └─────┘        (square, flat,      │
│   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐         2-4px radius,      │
│   │  5  │ │  6  │ │  7  │ │  8  │         no drop shadow)    │
│   └─────┘ └─────┘ └─────┘ └─────┘                           │
│   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                           │
│   │  1  │ │  2  │ │  3  │ │  4  │                           │
│   └─────┘ └─────┘ └─────┘ └─────┘                           │
│                                                              │
│ [REC] [PLAY] [STOP]                          ▐▐FADER▐▐      │  <- transport / fader
└────────────────────────────────────────────────────────────┘
```
- **Mode row** (SAMPLE / CHOP / KEYS / SEQ / FX — exact names as given in the brief): one active at a time, TE-style small uppercase labels on flat rectangular buttons, active mode filled in TE-orange, inactive modes outline-only on the grey body ramp (C1/C5).
- **Bank row** (A–D): matches EP-133's GROUP A–D naming (B1) while covering MPC Sample's bank concept (A1/A4) — a genuine overlap between the two references, not a compromise.
- **Pads**: dark-grey fill at rest (matching the OP-XY/EP-133 grey ramp, C1), lit in TE-orange when active/triggered, brightness or a thin fill-level bar communicating velocity. Square-ish, flat, 2-4px corner radius, no drop shadow — a hairline border only, per C5's flat-design finding. Long-press on a pad in SAMPLE mode = pad options (mute group, offset — A4); tap-and-hold in CHOP mode after chopping = per-slice trim (A3).
- **Transport**: REC / PLAY / STOP exactly as specified. REC arms recording; the actual MPC-authentic gesture (A2/B2/B5) is **hold-to-record** on SAMPLE mode's pads and **REC+PLAY together** (or REC then PLAY for a 4-beat count-in, B5/A6) for the sequencer — reuse this exact two-button gesture rather than inventing a new one, it's the most-cited "feels right" mechanic across both reference devices.
- **Fader**: recommend defaulting the physical-feeling fader to the **same live low-pass filter cutoff** driven by the hinge (D7) — one parameter, two input methods (slide it with your thumb, or fold the device), which mirrors EP-133's "fader = live performance control" ethos (B4) and halves the FX implementation work. A held-fader-for-alternate-function reassignment (matching both A's K-knob context switching and EP-133's hold-FADER pattern, B4) is a good stretch goal, not a 4-hour requirement.

### D4. Closed pose — 5.4" outer display
Apple's own platform guidance rules out spawning new windows/scenes from the outer display (duo-api-cheatsheet.md §2.6) — so this is the *same* app showing a reduced, glanceable view, not a separate experience. Recommend a compact status card, no pads (too little confident touch-target room to be worth the risk in 4 hours):
```
┌──────────────────┐
│   A · PATTERN 03  │
│                    │
│  ▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃   │  <- tiny step/level strip, not a full waveform
│                    │
│   120.0 BPM        │
│   CLAUDE: IDLE ●   │
│                    │
│   [ PLAY ]   [■]   │  <- play/stop only; big tap targets
└──────────────────┘
```
Detecting "closed" should key off `hinge.status == .closed` (confirmed enum case, cheat sheet §2.1) combined with the outer display's own size class — not a continuous-angle threshold.

### D5. Tent pose
The confirmed API surface (`hinge.status`: `.closed` / `.partiallyOpen` / `.fullyOpen`, plus continuous `hinge.angle`) does **not** obviously disambiguate "propped up like a tent" from "sitting like a laptop on a table" — both are `.partiallyOpen` at a similar angle; the difference is which way the device is physically rotated/propped, which may need device-orientation sensor fusion that isn't documented in our current API notes. **Design recommendation: treat tent pose as a manually-toggled "performance mode"** rather than relying on automatic pose detection (flagged **[U]** — verify at the hackathon whether orientation data reliably distinguishes them; don't build the demo's critical path on an undocumented disambiguation). Content-wise, mirror the existing DJ-deck plan's tent-pose idea (`/Users/shuhanzhang/duo-hack/PLAN.md`): top display flips to a big, simple, audience-facing reactive visual (pulsing waveform / mirrored pad-light show in flat TE line-art), bottom display keeps the full pad deck facing the performer — screen-facing-out, controls-facing-in, matching the "top region for glanceable content, bottom region for touch controls" tent description already confirmed for this device (cheat sheet §1).

### D6. KEYS mode — chromatic playback, and how to do it better than either reference
- **How EP-133 does it (B2)**: select the pad holding a sample, press **KEYS**, and the *same* 12 physical pads become a chromatic mini-keyboard for that sample — hold KEYS+MINUS/PLUS for octave shift, KEYS+pad to set a new root note. One control surface, reused. No dedicated visual keyboard — you have to know the mapping.
- **How bigger MPCs do it (A8, since MPC Sample itself lacks this)**: a "Keygroup Program" assigns samples across key/velocity zones and is typically shown against an actual on-screen piano-style keyboard strip on the touchscreen — precise and visual, but on different hardware from the pads themselves.
- **How we should do it — use both displays, which neither reference device has**: press **KEYS** on the bottom deck; the 16 pads instantly relabel as chromatic steps (root = the selected pad's original sample, pad-to-the-right = root+1 semitone; BANK buttons double as octave up/down while KEYS is held, mirroring EP-133's KEYS+MINUS/PLUS). Simultaneously, the **top display's step-grid area swaps for a real flat-vector piano-strip** (white/black keys, OP-1 line-art style): the root key is marked in TE-orange, a big Doto readout shows the currently-sounding note ("C4 · ROOT"), and each physical pad-press lights its corresponding piano key on top in real time. This is the legitimate "not possible before" moment for the judging rubric (`/Users/shuhanzhang/duo-hack/PLAN.md` line 4): EP-133 gives you *tactile* chromatic play with no visual map; bigger MPCs give you a *visual* keyboard with no repurposed pads; we give you both at once because we have two displays and they have one each.

### D7. Hinge angle as a punch-in FX — recommendation and reasoning
**Primary recommendation: hinge angle → live low-pass filter cutoff**, fully open/flat (180°) = filter fully open (no coloration), folding toward closed (0°) sweeps the cutoff down toward muffled/dark. Reasoning:
- **Physically intuitive**: "closing the lid darkens/muffles the sound" is an instantly-legible metaphor (closing a laptop, muting a room) — no explanation needed in a 90-second demo.
- **Musically forgiving**: a filter sweep sounds good at *any* continuous angle, with no discontinuities, and doesn't fight tempo/pitch sync — unlike a straight pitch-drop, which sounds actively wrong at in-between angles unless carefully staged.
- **Technically de-risked**: implementable with `AVAudioUnitEQ` as a low-pass, exactly the unit already scoped in `/Users/shuhanzhang/duo-hack/audio-ai-stack.md`'s "hand-roll it directly on AVAudioEngine" recommendation — no new audio dependency.
- **Real precedent on this exact API**: Apple's own worked example for `.onHingeChange` (cheat sheet §2.1) is a musical one — mapping continuous hinge angle to guitar pitch-bend. A continuous filter-cutoff mapping is the same shape of idea, just a different parameter, so we're following the API's own intended use case, not stretching it.
- **Secondary, staged effect for the "money shot"**: layer a **tape-stop** (playback rate/pitch slowdown via `AVAudioUnitTimePitch`'s rate parameter, also already scoped in audio-ai-stack.md) that only engages in the last ~15-20° before fully closed — so ordinary folding just darkens the tone, but slamming it fully shut triggers a dramatic pitch-down/stop, and snapping back open resumes full pitch/rate instantly (like releasing a vinyl platter). This mirrors TE's own "punch-in" philosophy (B3) of a continuous performance layer (filter) plus a discrete, committed gesture (the full-close "punch") — and gives the demo an actual beat/drama moment, not just a knob.
- **Rejected alternatives and why**: high-pass sweep (wrong metaphor — thinning out doesn't read as "closing"); bitcrush/sample-rate reduction (technically easy but reads as glitchy/digital, undercuts the analog-tape character TE's own products lean into); reverb/space increase (closing a device physically reducing space should *not* map to *more* space acoustically — backwards metaphor).
- Per Apple's explicit guidance already flagged in the cheat sheet, keep this strictly a performance/FX mapping — never let `hinge.angle` drive layout decisions; layout stays on `ArrangementView`/`reservedRegions`.

## E. Minimal MPC Sample workflow elements for a 4-hour build, ranked

Ranked specifically for **fidelity to MPC Sample's actual workflow** (part A) per unit of build effort — not general demo appeal, which is covered by D. KEYS mode is deliberately **excluded from this ranking** and footnoted separately, since MPC Sample itself does not have it (A8) — including it here would misrepresent what "MPC Sample authenticity" means; it belongs to D6 as a Duo/EP-133-motivated addition, not an MPC Sample element.

1. **SAMPLE mode's record gesture** (A2): SAMPLE button → pick input (mic/resample) → set threshold → tap-and-hold a pad to record, release to stop. Lowest effort (input node + level metering you likely need anyway), highest authenticity payoff — it's the single most iconic MPC gesture and the literal opening beat of every demo.
2. **CHOP, starting with equal-slice ("Regions 4/8/16")** (A3): divide the recorded buffer into N equal slices and auto-map one-per-pad. Cheap to implement (arithmetic, no DSP) and delivers the "chop to pads" payoff immediately. Add **Threshold-based auto-chop** (transient/onset detection) only if time remains — it's the same feature MPC Sample itself defaults to, but it's real DSP work and is the correct thing to cut first if the clock is tight, not the pad grid or sequencer.
3. **16-pad grid trigger + banks** (A1/A4/D1): one-shot playback per pad, 4 banks (A-D). This is the tactile/visual core identity of "being an MPC" and is required scaffolding for everything else anyway.
4. **SEQ record/overdub + quantize** (A6): REC+PLAY (or REC-then-PLAY count-in) to loop-record live pad hits, with snap-to-grid quantize on by default. This is what turns "a pile of chopped one-shots" into "a beat that loops" — the actual payoff moment of the whole demo, and directly reuses the exact two-button gesture both reference devices converge on (A6/B5).
5. **Swing amount + sequence length control** (A6): polish on top of #4, not a prerequisite for it — nice-to-have if #1-4 are solid with time to spare.
6. **PAD FX / KNOB FX** (A7): lowest priority *for MPC-Sample authenticity specifically* — MPC Sample's own FX system is broad (~60 effects) and isn't the device's signature identity the way SAMPLE→CHOP→pads→SEQ is; MPC Sample's own effects aren't even recordable into sequences (A7), so a simplified version doesn't buy much authenticity per hour spent. (The hinge-driven filter/tape-stop in D7 covers "FX" far more cheaply and is more Duo-specific than MPC-specific — build that instead if FX time is limited.)

---

## Sources

### Akai MPC Sample (part A)
- https://www.akaipro.com/guides/mpc-sample/features.htm — hardware layout, button names
- https://www.akaipro.com/guides/mpc-sample/sample_record_mode.htm — sampling workflow, Resample, Recall
- https://www.akaipro.com/guides/mpc-sample/pad_play.htm — chop types, pad play
- https://www.akaipro.com/guides/mpc-sample/sequence_mode.htm — sequencer (BPM, quantize, swing, length, step edit, song mode)
- manualslib.com/manual/4564377/Akai-Mpc-Sample.html — manual excerpts (Sample Mode, Pad Play sections)
- musictech.com/reviews/hardware-instruments/akai-mpc-sample-review/ — review (screen spec, FX limitation)
- musicradar.com — review (single-track structure, no Keygroup, "closer to SP-404")
- soundonsound.com — review (cross-check)
- support.akaipro.com FAQ (article 69000876967) — battery life, effects counts
- MPC Stems coverage (musicradar.com / djmag / soundonsound, multiple articles) — confirms MPC Stems is One/Live/X/desktop-only, never mentions MPC Sample

### Teenage Engineering EP-133 K.O. II (part B)
- https://teenage.engineering/products/ep-133 — specs, "super segment hybrid display," aesthetic description
- https://teenage.engineering/guides/ep-133 — top-level guide index
- https://teenage.engineering/guides/ep-133/buttons-and-combos — exact button names, GROUP/SHIFT/knob/fader mechanics
- https://teenage.engineering/guides/ep-133/modes — SAMPLE/KEYS/SOUND/MAIN/TEMPO/FX/TIMING/RECORD/PLAY/ERASE
- https://teenage.engineering/guides/ep-133/functions — chop types (auto/manual), resample definition, input sources
- https://teenage.engineering/guides/ep-133/play-and-record — KEYS mode mechanism, octave/root-note control
- https://teenage.engineering/guides/ep-133/effects — Punch-In FX 2.0, 6 send/group effects, per-pad performance FX
- https://teenage.engineering/guides/ep-133/workflow — COMMIT, verbatim official description
- https://www.soundonsound.com/reviews/teenage-engineering-ep-133-ko-ii — review (limitations, "feel" quotes, aesthetic comparison to MPC-60/calculators)
- https://musictech.com/reviews/hardware-instruments/teenage-engineering-ep-133-ko-ii-review/ — review (7/10, fun-factor, punch-in-not-recordable limitation)
- https://musictech.com/features/interviews/teenage-engineerings-ep-133-ko-ii-limitations-fadergate/ — "Fadergate" QC story, Eriksson design-philosophy quotes
- https://www.gearnews.com/teenage-engineering-ep-133-k-o-ii-review-better-than-an-mpc/ — hands-on sampling flow, live-play-vs-step-sequencer framing vs MPC
- https://gabrielroth.com/ko2/ — fan reference, used only for corroboration (SAMPLE flow, COMMIT combo)

### TE visual language (part C)
- https://teenage.engineering/products/op-1 — OP-1 Field specs/imagery
- https://teenage.engineering/products/tx-6 — "scales of gray to match OP-XY" quote
- https://teenage.engineering/products/ep-40 — EP-40 Riddim imagery
- https://en.wikipedia.org/wiki/Teenage_Engineering_OP-1 — design-award citation, color-coded knob/screen scheme, "punch" boxer icon example
- https://en.wikipedia.org/wiki/Teenage_Engineering — general brand history
- https://typ.io/s/4ozt — confirms Univers webfont usage on teenage.engineering
- https://lospec.com/palette-list/teenageengineering-op-xy — best-grounded fan-extracted grey ramp (used for our body-grey recommendation)
- https://blakecrosley.com/guides/design/teenage-engineering — design essay (orange hex guess, "brutalist grid," flat/no-shadow claim, monospace claim — flagged where it conflicts with other sources)
- color-hex.com/color-palette/1057593 and /1057594 — community palettes (lower confidence, snippet-only)
- https://www.figma.com/community/file/1108269080565562838/op-1-field-screen-graphics — fan-vectorized OP-1 icon reference
- https://teenage.engineering/press/teenageengineering — press/media index

### Duo platform + existing hackathon plan (grounding for part D)
- `/Users/shuhanzhang/duo-hack/duo-api-cheatsheet.md` — `onHingeChange`/`DeviceHinge`, `reservedRegions`, `ArrangementView`, size classes (itself sourced from developer.apple.com Tech Talks 111461-111464 and apple.com/newsroom)
- `/Users/shuhanzhang/duo-hack/audio-ai-stack.md` — AVAudioEngine/AVAudioUnitEQ/AVAudioUnitTimePitch scoping, Claude tool-calling loop
- `/Users/shuhanzhang/duo-hack/PLAN.md` — existing hackathon plan, tent-pose precedent, judging criteria ("creative use of what's unique to Duo... not possible before")

### Unverified / flagged items (consolidated)
- Exact hex values for "TE orange" and any per-group accent colors (no official brand guideline found — C1)
- Whether TE's typeface is "exclusively monospaced" (one source's claim conflicts with confirmed proportional Univers webfont use — C2)
- Whether TE UI animation is deliberately fast/hard-cut (no source discusses this at all — pure inference, C6)
- MPC Sample: exact NOTE REPEAT time-division behavior, RT Swing numeric range, complete 60-effect name list, battery life (5h vs 6h), whether Full Level/Roll are truly absent vs. undocumented (A5/A6/A7/A11)
- EP-133: exact button combo for COMMIT (reported as SHIFT+MAIN, fan-source only), complete list of all 12 punch-in performance FX names, resample capability (review says absent, official page says present — likely an OS-update discrepancy) (B3/B6/B7)
- Whether hinge angle + status alone can reliably distinguish "tent" from "laptop-on-table" pose (D5) — verify on Device Hub / hardware before relying on automatic detection
