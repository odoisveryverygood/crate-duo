# CRATE (CR-16) — build spec for Bitrig Hacks: iPhone Duo Edition

> Working name: **CRATE / CR-16**, "an AI sampler for iPhone Duo that digs your crates instantly." Rename freely.
> **Rules:** no app code before 11:30. Everything in this repo before then is data/assets/design/prompts.
> At 11:30: `git init`, and the first commit is the scaffold. Keys live in `.secrets/keys.env` (gitignored). Never commit them.

## 1. What we demo (90 s)
1. **Closed (outer screen):** a tiny "pocket" view with the prompt. Type or tap: *"4 bar loop, J Dilla laid-back drums + a killer Nujabes piano sample"*.
2. **Instant (< 0.5 s):** Jev parses intent. Pads fill from *your* sample library: bank A dusty drum kit, bank B piano loop chopped into 16 slices, bank C an 808/upright bass. The groove starts with a Dilla template (late snares, drunk hats) and a rule-based bassline follows the piano's chords. The lid logs `JEV 118ms`.
3. **~2–4 s later:** the GPT arrangement lands on the next bar (bassline + 4-bar variation). The lid shows `GPT 2.4s ✓ walking bass under Am9–Dm9`.
4. **Unfold to laptop pose.** The top half is the lid display (sequencer, waveform, AI log); the bottom half is the deck (16 pads, modes, banks, transport). "It's an MPC Sample now, except it can't do what we just did."
5. **Finger-drum on pads.** "Fill up the pads with some house drums" swaps only bank A instantly while the loop keeps playing.
6. **KEYS mode:** the 808 plays chromatically across a keyboard (scale-locked to the loop's key). Both screens work together: keys at the bottom, note and waveform on top.
7. **HINGE = PUNCH-IN FX:** slowly fold, and a filter closes while crush and reverb swell into a breakdown. **Snap open = DROP** (crash + everything back).
8. **AI PERFORM:** Jev decides a fill every bar (`PERFORM ▸ ROLL`).

## 2. Model choice (why each model)
| Job | Model | Why |
|---|---|---|
| Parse the request into typed params (scope, drum style, sample style, instrument, mood, bars, tempo, laid-back/vintage/energy/brightness scores, wants bass) | **TypeSafe Jev** (`/v1/systemone`, one call, ~12 questions) | System-1 typed decisions in ~70–500 ms. It never writes prose, so it can't hallucinate a format. It makes the app feel instant. |
| Pick the actual sounds | **No model: local retrieval** over the pre-analyzed library (`library/*.json`) | < 5 ms, offline, and it's *your* sample packs |
| First groove + first bassline | **No model: groove templates + rule-based bass** (`library/grooves.json`) | Instant and musically safe |
| Per-bar performance (fill? energy? vary?) | **Jev** (`perform` questions) | Real-time loop: must answer inside one bar (2.7 s at 89 BPM) |
| Composition: 4-bar variation, bassline over the loop's chords, sample FLIP, "make it more laid back" | **OpenAI** small/fast tier, Responses API, strict json_schema, reasoning effort none/minimal (`ai/openai-arrange.md`) | Real generative work; runs in the background and is swapped in on the next bar |
| A sound your library lacks ("glass bottle snare") | **ElevenLabs SFX** (stretch goal) | ~2 s+ per sound, so never on the instant path |

Pitch line: **"Jev reacts, GPT composes, your crates supply the sound."** If the network dies, everything still works through the keyword parser, templates and rule-based bass.

## 3. Repo layout and ownership (XcodeGen, so agents only ADD files and pbxproj never conflicts)
```
duo-hack/
  project.yml                      LEAD
  Config/Base.xcconfig             LEAD (includes Secrets.xcconfig if present)
  Config/Secrets.xcconfig          generated from .secrets/keys.env (gitignored)
  Resources/Info.plist             LEAD (UIAppFonts, CRATE_LIBRARY_PATH, API keys from xcconfig, NSMicrophoneUsageDescription)
  Resources/Fonts/                 from assets/fonts: Doto-w900.ttf (Doto-Black), Doto-w700.ttf (Doto-Bold), SpaceMono-{Regular,Bold}, JetBrainsMono-{Regular,Bold}
  Resources/AI/jev-questions.json  copy of ai/jev-questions.json
  Resources/DefaultKit/            copy of assets/kits/boombap + assets/manifest.json (offline fallback)
  Sources/Core/                    LEAD, first 15 min. Foundation + Observation only (compiles on macOS too)
  Sources/Audio/                   AGENT A (AVFoundation)
  Sources/Library/                 AGENT C (Foundation only)
  Sources/AI/                      AGENT C (Foundation only)
  Sources/UI/                      AGENT B (SwiftUI)
  Sources/App/                     LEAD (App entry, RootView = Duo layout, wiring, hinge)
  library/                         asset data (NOT bundled; the simulator reads it from the host path)
```
Build settings: iOS deployment target 27.1, Swift language mode 5, `SWIFT_STRICT_CONCURRENCY = minimal`, bundle id `com.shuhan.crate`.
**Library access:** in the simulator the app reads `/Users/shuhanzhang/duo-hack/library` directly (Info.plist `CRATE_LIBRARY_PATH`). Verify this in the first 15 minutes. If sandboxing blocks it, copy the library into the app's Documents with `xcrun simctl get_app_container booted com.shuhan.crate data`, and fall back to `Resources/DefaultKit`.

## 4. Shared contract: `Sources/Core` (LEAD writes this at 11:30, exactly as below)
- `enum Style: String, CaseIterable, Codable` { dilla, jazzhop, boombap, lofi, vintage, house, trap, drill, rnb }
- `enum Category: String, Codable, CaseIterable` { kick, snare, clap, hat, openhat, rim, perc, shaker, cymbal, `eight08 = "808"`, bass, fx, vocal, texture, keys, synth, chop, loop }
- `enum Bank: Int, CaseIterable` { a, b, c, d }: A = drums, B = sample chops, C = bass/keys, D = free (AI one-offs, generated sounds)
- `struct PadID: Hashable, Codable { bank: Bank; index: Int }`: index 0…15, 0 = pad 1 = bottom-left (MPC order; top row = 13–16)
- Bank-A slot order (index → lane name): `kick, kick2, snare, clap, hat, hat2, openhat, rim, perc, perc2, shaker, cymbal, 808, fx, vocal, texture` (same as `grooves.json bankA.pads`)
- `struct PadSound: Identifiable, Hashable { id: String; name: String; category: Category; fileURL: URL; start: Double = 0; end: Double? = nil; rootNote: Int?; gain: Float = 1; source: String = "" }`: start/end in seconds (chops are slices of one file)
- `struct Hit: Hashable, Codable { step: Int; velocity: Int; offset: Double = 0; ratchet: Int = 1 }`: `offset` is a fraction of one 16th (+ = late)
- `struct NoteEvent: Hashable, Codable { step: Int; length: Double; midi: Int; velocity: Int }`: length in steps; played on a pad, pitched `midi - rootNote` semitones
- `struct Pattern: Hashable { var bars: Int; var swing: Double /*50–70 %*/; var lanes: [PadID: [Hit]]; var late: [PadID: Double]; var notes: [PadID: [NoteEvent]] }`: steps absolute `0 ..< bars*16`
- `enum ApplyTiming { case now, nextBar }`
- `enum Mode: String, CaseIterable { sample, chop, keys, seq, padFX, levels16 }`
- `struct LogLine: Identifiable { id = UUID(); tag: String /*JEV KIT SAMPLE BASS GPT PERFORM ERR*/; text: String; ms: Int?; tint: Tint }` with `enum Tint { orange, blue, ochre, grey, red }`
- `protocol SamplerEngine: AnyObject` (Agent A implements `AudioEngine`, Agent B uses `MockEngine` for previews):
  - `func start() throws`
  - `func loadBank(_ bank: Bank, sounds: [Int: PadSound]) async throws`: decode/convert/cache buffers, then swap in atomically
  - `func sound(for pad: PadID) -> PadSound?`
  - `func trigger(_ pad: PadID, velocity: Int, semitones: Double)`: live, as soon as possible
  - `func release(_ pad: PadID)`: keys note-off (10 ms fade), no-op for one-shots
  - `func setPattern(_ p: Pattern, timing: ApplyTiming)` / `var pattern: Pattern { get }`
  - `func play()`, `func stop()`, `var isPlaying: Bool { get }`, `var bpm: Double { get set }`, `var swing: Double { get set }`
  - `func position() -> Double`: absolute position in steps (for the playhead; UI polls it at 60 fps)
  - `var onBar: ((Int) -> Void)?`: called on main at each bar start (absolute bar index)
  - `func queueFill(_ id: String, atBar: Int)`: fill ops from grooves.json, applied when that bar is scheduled
  - `func setRecording(_ on: Bool)`: while playing, live `trigger`s are quantized (1/16) into `pattern` (overdub)
  - `func setPunch(_ amount: Double)`: hinge FX 0…1; `func drop()`: crash + FX reset (snap-open)
  - `func level() -> Float`: master RMS 0…1; `func waveform(_ pad: PadID, points: Int) -> [Float]`: peak envelope for display
- `@Observable final class AppState` (UI binds to this; LEAD wires the actions):
  `mode, bank, selectedPad: PadID, sounds: [PadID: PadSound], bpm, swing, isPlaying, isRecording, bars, styleLabel: String, sampleLabel: String, chordsLabel: String, log: [LogLine], prompt: String, isDigging: Bool, keysOctave: Int, scaleLock: Bool, scaleKey: String?, punch: Double, hingeAngle: Double?, performOn: Bool, lastHitPad: PadID?, engine: SamplerEngine`
  plus actions set by the App: `var onDig: ((String) -> Void)?`, `var onFlip: (() -> Void)?`, `var onPerformToggle: ((Bool) -> Void)?`, and convenience `func hit(_ pad: PadID, velocity: Int, semitones: Double = 0)` (engine.trigger + lastHitPad + record).

## 5. Agent A: audio engine (`Sources/Audio/`)
- AVAudioSession `.playback`, preferred IO buffer 5 ms (`#if os(iOS)`). Engine format 44.1 kHz stereo float. Convert every file on load (mono → stereo, any SR → 44.1 k) with `AVAudioConverter`; cache `AVAudioPCMBuffer` per pad. Chops = sub-buffers copied from the loop file by `start/end`.
- **Voices:** 32 × (`AVAudioPlayerNode` → `AVAudioUnitVarispeed`) → one `AVAudioMixerNode` per bank → master chain. Pitch = varispeed `rate = 2^(semitones/12)` (classic sampler behaviour). Allocate only voices that are idle *now* (tracked `busyUntilHostTime`), round-robin. Velocity → `volume = (v/127)^1.6`.
- **Master chain:** bankMixers → `AVAudioUnitEQ` (band0 lowPass; band1 highPass bypassed) → `AVAudioUnitDistortion` (preset `.multiDecimated2`, wetDry 0) → `AVAudioUnitDelay` (3/16 note, feedback 35, wet 0) → `AVAudioUnitReverb` (`.largeHall`, wet 0) → Apple PeakLimiter (`kAudioUnitSubType_PeakLimiter`) → `mainMixerNode`. Tap on the limiter for `level()`.
- **`setPunch(p)`** (called ~60 Hz from the hinge): cutoff = 20000·(180/20000)^(p^0.85) Hz; crush wet = 30·p²; delay wet = 22·p; reverb wet = 38·p. Above p > 0.92: "breakdown", so mute banks A+C (the chops ring through the FX). `drop()`: instant p = 0, unmute, trigger bank-A `cymbal` pad (index 11) at velocity 118 plus the kick.
- **Sequencer:** `DispatchSourceTimer` every 10 ms on a `.userInteractive` serial queue; lookahead 100 ms. Anchor `(anchorStep, anchorHostTime)`; secondsPerStep = 60/bpm/4. Event time = anchor + (step − anchorStep + swingDelay(step) + hit.offset + late[pad])·secondsPerStep, converted with `AVAudioTime.hostTime(forSeconds:)`, scheduled via `scheduleBuffer(_, at: AVAudioTime(hostTime:))`. `swingDelay` = odd steps × (2·swing/100 − 1). Ratchet r = r events spaced 1/r step (velocity ×0.85 each). BPM change → re-anchor at the next step.
- **Chokes:** truncate at schedule time (copy with a short fade, or schedule a frame-limited segment): hat/hat2 cut openhat; each bank-B chop cuts the previous chop (mono); bank-C notes are mono/legato (note length = `NoteEvent.length` steps).
- **Pattern swap:** `pending` pattern applied when scheduling reaches the next bar's step 0 (`.nextBar`), or immediately (`.now`). **Fills:** `queuedFills[bar]` ops (`clear` lanes fromStep; `add` hits; `addNextBar`) applied to that bar's bank-A lanes only (lane names → bank-A index per §4).
- **Recording:** position now → nearest step (−25 ms latency compensation) mod `bars*16` → add `Hit` (or `NoteEvent` in KEYS mode) to `pattern`; publish.
- **Test on the Mac first** if convenient: it's AVFoundation, so a tiny macOS harness (`tools/audio-harness`, not in the app) can play a groove from `library/grooves.json` through the speakers.
- Typecheck without touching the shared build: `xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios27.1-simulator -swift-version 5 Sources/Core/*.swift Sources/Audio/*.swift`

## 6. Agent C: library + AI (`Sources/Library/`, `Sources/AI/`), Foundation only
- **LibraryStore:** decode `oneshots.json`, `loops.json`, `grooves.json` from `CRATE_LIBRARY_PATH` (fallback: bundled DefaultKit manifest). Schemas: see the headers in those files (loops: `slices16Sec`, `chordsPerBar`, `bassPerBeat`, `key`, `bpm`, `bars`; grooves: `styles`, `bankA.pads`, `grooves[].lanes{lane:[[step,vel,offset,ratchet?]]}`, `fills[]`, `bassRhythms{style:{notes:[{step,len,deg,vel}], followKick}}`).
- **Retrieval** (< 5 ms, seeded RNG so "DIG AGAIN" varies):
  - Kit: for each bank-A slot, candidates in category (kick2 → kick, hat2 → hat, perc2 → perc, 808 → `808`). Score = 1.0·styles[style] + 0.35·(1−|dust−t.dust|) + 0.25·(1−|brightness−t.brightness|) + 0.2·(1−|punch−t.punch|) + 0.08·rand. Take the best unused; "2" slots take the runner-up. Targets = `grooves.json styles[style].kit`, nudged by Jev scores (vintage → dust, brightness → brightness, energy → punch).
  - Loop: filter by instrument (piano ↔ rhodes ↔ keys interchangeable; `any` = no filter), score = 1.0·styles[sampleStyle] + 0.3·moodMatch + 0.3·bpmFit(style bpm range) + 0.1·keyConfidence + 0.08·rand + 0.1·(bars ≥ requested). Library facts: 77 loops, most are 8 bars; for a shorter request use only the FIRST `requested` bars (end = requested·240/bpm s), with 16 equal slices over that span (snap each to the nearest onset within 40 ms), and `chordsPerBar` truncated to match. Ignore BPMs < 60 unless doubled (a half-time detection); prefer 80–100 for hip-hop styles.
  - Bank C: pad 1 = bass (`808` for trap/drill, else `bass`, fallback `808`), pad 2 = best `keys` one-shot, pad 3 = best `synth` one-shot, pad 4 = the loop's lowest-register chop? (optional).
- **Pattern builders:** groove → Pattern (tile to `bars`, map lanes to bank-A pads, scale offsets by the laidback score: ×(0.5 + laidback)); chops in original order = slice i at step i·L for L = loop bars (length L steps), repeated to fill the bars; `BassWriter` = `bassRhythms[style]` + chord root per bar (`chordsPerBar` → root, else `bassPerBeat[bar*4]`, else the key tonic), register 33–52, degrees R/3/5/b7/8/appr; followKick adds roots on kick steps. **Octave-fold rule (also for GPT bass):** before playback on a pitched one-shot pad, move each note by whole octaves to within ±6 semitones of that pad's `rootNote` (pitch class kept), so the varispeed rate stays about 0.7–1.4 and 808 tails never chipmunk or drag. Library root octaves are approximate (pitch-class reliable), so this rule matters. Missing rootNote → assume 36 for 808/bass, 60 for keys/synth.
- **KeywordParser** (offline, instant): style keywords from `grooves.json styles[].keywords`; instruments (piano, keys, rhodes, ep, guitar, strings, pad, vibes, horn, sax, flute, vocal, break); "N bar(s)"; "NN bpm"; "drums/kit/kick/snare" without a melodic word → drums_only; "sample/loop/piano…" without drums → sample_only; "flip" → flip; "laid back/drunk" → laidback 0.9; "vintage/dusty/old" → vintage 0.9.
- **JevClient:** `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer <TYPESAFE_API_KEY>`, body `{model:"jev-latest", state, questions}` (questions from `Resources/AI/jev-questions.json`: `plan` / `perform` / `route`). Parse `answers[id]` → `.choice` (String) + `probabilities`, `.score`, `.noul` (Double). Handle score as Int, Double **or** String (unverified shape). Timeout 900 ms for plan, 2 s for perform. Warm the connection at launch with a tiny request. **Never use jevapi.org / tokenra.io.**
- **OpenAIClient:** Responses API, strict schema, prompt from `ai/openai-arrange.md` (embed as a Swift string). Parse `output[].content[].text` (type `output_text`). Timeout 8 s. `Arrangement` → Pattern (X=118, x=92, g=44, r=ratchet 2 @86; repair string lengths; clamp midi).
- **Orchestrator** (`@MainActor`): `dig(prompt)`: t0 → KeywordParser plan immediately; the Jev plan races a 900 ms timeout and overrides where the choice probability is > 0.4 → retrieval → `engine.loadBank` ×3 (in parallel) → set bpm/swing (bpm = the loop's bpm when a sample is chosen) → Pattern (template + chops + rule bass) → apply (`.nextBar` if playing, else `.now` + `play()`) → log lines with ms → fire OpenAI in the background → on success apply at `.nextBar` + log. Scopes: drums_only (bank A + drum lanes only), sample_only (bank B + chops + bass), change_groove (OpenAI with the current pattern; instant local swing/late tweak from the laidback score), bass_only, single_sound (Jev `route` → best library match onto the selected pad), flip (OpenAI chops only).
  **Performer:** when `performOn`, on `onBar(n)` call Jev `perform` with state (style, bpm, bar in 8-bar phrase, energy, bars since the last fill) → `engine.queueFill(choice, atBar: n+1)`; energy < 0.3 → mute perc/shaker for the bar; log `PERFORM ▸ ROLL`.
- **macOS harness** (`tools/harness/main.swift`, not in the app): compile Core+Library+AI with `swiftc` for macOS and run `dig` dry-runs against the real library + live APIs (keys from env), printing the chosen kit/loop/pattern + timings. This is how C verifies without the simulator.

## 7. Agent B: UI (`Sources/UI/`), SwiftUI, TE look (see `design/mockup-laptop.png`)
- **Tokens:** chassis `#C9C9CB`, button `#E4E4E6` with 1 px `#9D9DA2` border, silk text `#16161D`, pad `#2F2F36` / pressed `#3A3A42` + 2 px inset orange, pad edge `#484850`, pad label `#AFAFB3`; display bg `#000`, text `#F6F4F4`, mid `#797982`, dim `#484850`; accents: orange `#FA5B1C` (bank A, REC, active), blue `#5B8DEF` (bank B), ochre `#E0A92E` (bank C), grey `#AFAFB3` (bank D). Flat, no shadows, corner radius 4–6, animations ≤ 100 ms linear.
- **Fonts** (PostScript): `Doto-Black` (hero numerals: BPM, swing, bar.beat, note), `SpaceMono-Bold` (uppercase tracked labels, 8.5–13 pt, tracking 0.14–0.18 em), `JetBrainsMono-Regular/Bold` (values, AI log, prompt).
- **LidDisplayView** (black): header (CRATE · CR-16 | BANK x · MODE · N BARS | JEV ● ms · GPT ● s); readouts (BPM, SWING %, BAR.BEAT in orange, style × sample label, chords); main area by mode: SEQ = 16-step dot grid for the current bar (lanes that have hits; bank colors; ghost = grey; playhead column), CHOP = waveform of the bank-B loop with 16 numbered slice markers (current slice orange), KEYS = big note name + semitone + waveform of the selected pad + "SCALE LOCK: A MINOR", SAMPLE/others = AI log. Bottom: `›` prompt line + a row of result chips with timings (from `log`). While `isDigging`: a 3-dot dot-matrix spinner.
- **DeckView** (chassis): left column MODE buttons (SAMPLE, CHOP, KEYS, SEQ, PAD FX, 16 LVL, SHIFT); center 4×4 pads (MPC order, number top-left, name bottom-left, a 3 px top bar in the bank color when loaded, orange inset flash ≤ 100 ms on hit); right column PAD BANK A–D (2×2 with a color tick), LEVEL fader (vertical, orange line on the cap), transport ● ▶ ■, orange **✦ DIG** button (focuses the prompt).
- **Pads:** trigger on touch-down (`DragGesture(minimumDistance: 0)` + a `@GestureState` guard), velocity from touch height (top = 127, bottom = 70) unless `16 LVL`. **16 LVL:** the selected pad across 16 pads at −7…+8 semitones.
- **KeysView (KEYS mode = the MIDI keyboard mode):** 10 white + 7 black keys (F to A, like the mockup) filling the pad area, multi-touch note on/off → `hit(pad, semitones: note − root)`, `release`. OCT −/+ in the mode column. SCALE LOCK maps keys to the loop's key scale (white keys = scale degrees). The top display mirrors the note played.
- **PromptBar:** TextField (JetBrains Mono) + chips: `DILLA DRUMS`, `NUJABES PIANO`, `VINTAGE BREAK`, `HOUSE KIT`, `FLIP IT`, `MORE LAID BACK`, `AI PERFORM`. Submit → `state.onDig`.
- **CompactView** (outer display, closed): mini lid (BPM, bar, style/sample, 2 log lines) + 4×4 pads + DIG. **CrowdView** (tent, stretch): the huge last-hit pad name in Doto + a level-meter bar.
- `MockEngine` + `#Preview`s for LidDisplay, Deck, Keys, Compact at 626×445.
- Typecheck: `xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios27.1-simulator -swift-version 5 Sources/Core/*.swift Sources/UI/*.swift`

## 8. LEAD: Duo integration (`Sources/App/`)
- `RootView`: read the `.division` reserved region via `GeometryReader { proxy.reservedRegions(kind: .division) }`. Horizontal fold (laptop) → lid above, deck below, split at the division rect; vertical fold (book) → lid left, deck right; no active division (flat) → split 50/50 by the longer axis; compact width (outer display) → `CompactView`. Try `ArrangementView(.split)` first; fall back to manual geometry if its axis behaviour is unclear (§ cheat sheet 2.3).
- `.onHingeChange { _, ctx in if let h = ctx.hinge { … } }`: angle in degrees; `punch = clamp((restAngle − angle)/(restAngle − 25°), 0, 1)` with restAngle = 110° (anything more open = 0). Snap-open detection: punch fell from > 0.6 to < 0.1 within 250 ms → `engine.drop()`. Smooth at 60 Hz. Test with `hinge sweep 120 30 3`, then `hinge 120`.
- Fallback for non-Duo devices: PAD FX mode with the pad-12 "PUNCH" slider.
- Wire: AppState ↔ AudioEngine ↔ Orchestrator; secrets from Info.plist; `library` path check with an on-screen error if missing.

## 9. Timeline
| Time | Lead | Agents |
|---|---|---|
| 11:30–11:45 | `git init`, project.yml, Core types, App shell, secrets xcconfig, build+run in Duo sim, check the library path is readable, `hinge` works, sound plays | — |
| 11:45 | spawn A, B, C with §5/§6/§7 briefs (+ "read BUILD.md, Sources/Core, design/mockup-laptop.png") | start |
| 11:45–12:45 | RootView Duo layout + hinge + wiring | A engine, B UI, C library+AI (+ macOS harness) |
| 12:45–13:00 | **integrate → first playable DIG (keyword parser + templates)** | fix-ups |
| 13:00–14:15 | Jev + GPT live, KEYS mode, performer, hinge FX, polish | P1 features |
| 14:15–14:45 | polish, bugs, perf; **feature freeze 14:45** | — |
| 14:45–15:15 | record a backup demo video (`record_sim_video`), rehearse ×3 | — |
| 15:15–15:30 | submit: repo, video, one-paragraph description | — |

## 10. Risks and fallbacks
- Jev slow or down → keyword plan (it already runs first; Jev only upgrades it).
- OpenAI slow or down → templates + rule bass already playing.
- Simulator can't read the host path → copy into the app container / DefaultKit.
- Duo layout APIs misbehave → manual GeometryReader split (works on any device).
- hinge CLI breaks → Option-slider in Device Hub; PAD FX slider fallback.
- Simulator audio crackle → keep voices ≤ 32, IO buffer 5–10 ms, avoid main-thread work in callbacks.
- Demo wifi → run the whole demo once offline to prove the fallback path sounds good.
