# HANDOFF: parallel work on CRATE (Bitrig Hacks: iPhone Duo Edition)

**Deadline:** submit by 15:30; demos 15:30–17:00. **Repo:** github.com/Shuhan-Zhang/crate-duo (private), branch `main`.
**What CRATE is:** an AI sampler for iPhone Duo with a Teenage Engineering look and the MPC Sample workflow. Type a vibe → Jev (TypeSafe) parses it in ~150 ms → pads fill from the user's own sample library → GPT-6-luna writes bass/variations → the hinge is a punch-in FX (snap open = DROP) → the Duo's back screen shows a crowd view while you play. Read `BUILD.md` (spec), `DEMO.md` (script), `design/mockup-laptop.png` (look).

## Who owns what (DO NOT edit these)
| Path | Owner |
|---|---|
| `Sources/Core`, `Sources/App`, `project.yml`, `Resources/Info.plist`, `tools/selftest.sh`, `tools/analyze.py` | Lead (Claude session on the main Mac) |
| `Sources/Audio` | Agent A (audio engine) |
| `Sources/UI` | Agent B (TE-style UI) |
| `Sources/Library`, `Sources/AI`, `tools/harness` | Agent C (retrieval + Jev/GPT orchestrator) |
| `demo/`, `tools/video/` | Video agent (demo film pipeline) |

## Rules for parallel agents
- Work on a branch `wp/<name>`, touch ONLY your work package's paths, `git pull --rebase` before pushing, push the branch, and tell the lead to merge. Never commit keys (`Config/Secrets.xcconfig` is gitignored).
- Verify Swift with a typecheck, NOT xcodebuild on the shared project (the lead integrates):
  `xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios27.1-simulator -swift-version 5 Sources/Core/*.swift <your files>`
- Core contract = `Sources/Core/*.swift` (AppState, Models, SamplerEngine, MockEngine, Support). Use `AppState(engine: MockEngine())` for previews.
- **Setup on another computer:** Xcode 27.1 (the only version with the Duo SDK) + iOS 27.1 simulator runtime, `brew install xcodegen`, clone, then `xcodegen generate`. Keys: create `Config/Secrets.xcconfig` with `OPENAI_API_KEY = …`, `TYPESAFE_API_KEY = …`, `CRATE_LIBRARY_PATH = …` (get the keys from Shuhan privately). The sample library audio exists only on the main Mac; elsewhere the app falls back to `Resources/DefaultKit`.

## Work packages
### WP1: RevenueCat paywall (prize), `Sources/Paywall/` only, ~40 min
Prereq (human, 10 min): RevenueCat project + iOS app + product + offering + entitlement `pro`; put `REVENUECAT_API_KEY` in Secrets.xcconfig.
Build a `.paywallGate(state:)` view modifier: after 3 DIGs (count them via `state.log` tags or a counter you keep in your own type) show RevenueCatUI `PaywallView` unless the user has entitlement `pro`; a "CRATE PRO" copy line ("unlimited digs, AI PERFORM, crowd screen"). Don't edit project.yml: write the exact XcodeGen `packages:` + target `dependencies:` lines for `purchases-ios` (products RevenueCat, RevenueCatUI) into `Sources/Paywall/README.md`. Done = typechecks against a stub of RevenueCat, or builds on a local scratch copy of the project with the package added.

### WP2: Crowd stage for the back screen, `Sources/Crowd/` only, ~45 min
`CrowdStageView(state: AppState)`: the audience-facing visual shown on the Duo's OUTER screen (1398×2034 px portrait panel) while the performer plays inside. Black background, TE palette (orange #FA5B1C, blue #5B8DEF, ochre #E0A92E, text #F6F4F4), fonts `Doto-Black` / `SpaceMono-Bold`. Content: CRATE wordmark; the current `state.styleLabel` × `state.sampleLabel` in huge type; a 4×4 dot matrix that flashes the pad being hit (`state.lastHitPad` / `lastHitTime`, and sequencer hits from `state.engine.pattern` + `state.engine.position()` via `TimelineView(.animation)`); a level bar from `state.engine.level()`; a full-screen "DROP" flash when `state.punch` falls from high to 0; `state.lastPerform` ("PERFORM ▸ ROLL") ticker. It must read well from 2 m away. **Look = a "Now Playing" card** (reference: the viral iPhone Duo concept of a folded Duo on a nightstand showing album art + "Heat Waves / Glass Animals" on the outer screen): a square generated COVER (a dot-matrix/pad-grid artwork in the bank colours, seeded by the kit so each DIG gets new art), the TITLE (the GPT arrangement title, e.g. "NUJ KEYS POCKET", else `state.styleLabel`), the ARTIST line ("CRATE · J DILLA × JAZZ HOP"), a thin progress/level line, soft glow. Also export `NowPlayingCard(state:)` so the lead can reuse it for the CLOSED pose (outer screen as the only screen: card + ▶/■ + DIG). Pitch framing: **three screens at once in laptop pose: lid (top), deck (bottom), crowd/now-playing (back).** Orientation: the content currently renders rotated on the outer panel; make it orientation-proof (GeometryReader: if the width > the height, rotate the content 90° to fill the portrait panel, and expose a `rotate: Angle` parameter so the lead can flip it). #Previews at 466×678 and 678×466. The lead wires it into `OuterCrowdHost` in `Sources/App/RootView.swift`.

### WP3: Submission kit, docs only (`README.md`, `SUBMISSION.md`), ~30 min
README: what/why, the Duo APIs used (reserved regions `.division`, `onHingeChange`, `CameraCaptureAccessory` for the back screen, size classes), models (Jev, GPT-6-luna/sol, local retrieval: see BUILD.md §2), architecture diagram (text), how to run (xcodegen, secrets, simulator), the self-test (`tools/selftest.sh`). SUBMISSION.md: title, one-liner, 150-word description, "what's only possible on Duo" bullets, the tech stack, a demo video link placeholder, team. Pull facts from BUILD.md / DEMO.md / git log; don't invent features.

### WP4: App icon + brand, `Resources/Brand/` only, ~20 min
`AppIcon-1024.png` (no alpha): TE style: light grey chassis, a 4×4 grid of dark pads with one orange pad, or an orange dot-matrix "CR". Also `wordmark.png` (orange Doto "CRATE" on transparent, 2000 px wide) for the video/slides. The lead adds the asset catalog to project.yml.

### WP5 (human, main Mac, after ~12:45): pose QA
In the Simulator: ⌘→ to rotate into laptop pose; hold ⌥ and drag for the hinge slider; check that the lid sits on the top half and the deck on the bottom, the fold gap is clean, and pads are reachable; screenshot anything broken. Check which way the back-screen content faces (`xcrun simctl io 0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4 screenshot --display=1 /tmp/outer.png`).

### WP6 (human, main Mac): ears on the library
`afplay ~/duo-hack/library/loops/piano/L002.wav` (the headline Nujabes piano), plus L001/L003/L004/L018 and the breaks L061–L063. Note any bad sample IDs in `LIBRARY-NOTES.md` so they can be excluded.

### WP7: SAMPLE mode, mic → pad → auto-chop (MPC Sample workflow), `Sources/Sampler/` only, ~60 min
The MPC Sample's core loop: press SAMPLE RECORD, record from the mic, and the take is auto-chopped onto pads ("Threshold" chop by transients, or "Regions 16" equal slices). Build it without touching `Sources/Audio`:
- `final class MicSampler` (init(state: AppState)): `startRecording()` / `stopRecording(chop: .threshold | .regions16) async`. Record with AVAudioRecorder (44.1 kHz mono 16-bit WAV) to `Documents/samples/rec-<timestamp>.wav`. While recording, switch the AVAudioSession to `.playAndRecord` with options `[.defaultToSpeaker, .mixWithOthers]`, then restore `.playback` afterwards (the audio engine keeps running; it handles config changes). Expose a live input `level` (0…1) for a meter. Optional: threshold arm (start the take when the level crosses −30 dBFS, like MPC Sample's Threshold).
- Auto-chop: load the WAV, find transients (RMS in 10 ms windows, rising edges above an adaptive threshold, ≥ 80 ms apart), and make up to 16 slices (or 16 equal regions) → `PadSound(id:, name: "REC 01"…, category: .chop, fileURL:, start:, end:, rootNote: 60)` → `await state.engine.loadBank(.d, sounds: [0: …, 1: …])`, set `state.bank = .d` and `state.sounds` for those pads, and `state.addLog("SAMPLE", "16 chops · 4.2 s", tint: .grey)`.
- `SampleRecordButton(state:sampler:)` SwiftUI view: hold to record (orange dot + live level bar + seconds), release to stop and chop; a small CHOP TYPE toggle (THRESH / REGIONS 16). TE style: see `Sources/UI/Theme.swift` (read-only) or HANDOFF WP2 colours.
- Add `DebugLog.event("sample_rec", ["sec": …])` and `("sample_chop", ["slices": …])`.
- Verify with the typecheck command above (Core + your files). If you have Xcode 27.1 + the iOS 27.1 simulator, you can also run it on a fresh clone (no keys needed; the app falls back to its built-in kit). The lead wires the button into the deck's SAMPLE mode.

### WP8: Keyboard play (Logic Musical Typing) + pressed visuals, ~45 min
The demo runs in the Simulator, so the performer plays with the Mac keyboard, and every press must VISIBLY press the pad/key in the app.
- Files: NEW `Sources/App/KeyboardControl.swift`; additive fields in `Sources/Core/AppState.swift` (`heldPads: Set<PadID>`, `heldNotes: Set<Int>`, `keyVelocity = 110`, `promptFocused`); small visual edits in `Sources/UI/PadGridView.swift`, `KeysView.swift`, `PromptBar.swift`; attach the key catcher once in `Sources/App/RootView.swift` (one line; rebase on main first).
- Key catcher: a UIViewRepresentable UIView that `canBecomeFirstResponder`, overrides `pressesBegan/pressesEnded/pressesCancelled` (ignore repeats), placed once at the root; it re-takes first responder when the DIG prompt resigns (Esc/submit). (SwiftUI `.onKeyPress(phases: [.down,.up])` is fine too if it works reliably with the Simulator's hardware keyboard, toggled with ⇧⌘K.)
- Pads (all modes except KEYS), MPC-software layout: pads 13–16 = `1 2 3 4`, 9–12 = `Q W E R`, 5–8 = `A S D F`, 1–4 = `Z X C V` → `state.hit(pad, velocity: state.keyVelocity)` on down, insert into/remove from `heldPads`; in 16 LVL the same keys play the selected pad at −7…+8 semitones.
- KEYS mode (Logic Musical Typing): `A W S E D F T G Y H U J K O L P ; '` = C … F, one octave-and-a-half from C3 (48 + 12·keysOctave), honouring scale lock like KeysView; `Z`/`X` = octave −/+, `C`/`V` = velocity −/+ 10; key up → remove from `heldNotes`, release the pad when none are held.
- Global: Space = play/stop, Return = REC, Tab = next bank, Shift+Tab = next mode, `/` = focus the DIG prompt, Esc = leave it.
- Visuals: held pads look pressed (like a finger press); held piano keys look pressed; each pad/key shows its letter small in the corner (Logic style).
- Verify: typecheck + run in the Duo Simulator; send keys with `axe key <HIDcode>` (a=4, z=29, space=44) and screenshot.
- **Wider keys (user feedback, 12:23):** in KEYS mode the keys are too narrow. Show ONE octave, 8 white keys (C to C) + 5 black keys, and let the keyboard use the FULL deck width: hide the right column (banks/level) in KEYS mode and move OCT −, OCT +, SCALE and the MODE buttons into one slim row above the keyboard; keep ▶/■/DIG reachable (small, top-right of that row). The musical-typing map stays the same (A…K = C…C, W E T Y U = black keys).

### WP13: Drag audio in/out (Duo Split View), ~45 min
The Duo is the first iPhone with side-by-side multitasking; make CRATE a good neighbour.
- Drag IN: every pad accepts dropped audio (`.dropDestination(for: URL.self)` / UTType.audio): copy into `Documents/imported/`, build a `PadSound` (short files → one-shot on that pad; files > 2 s → offer "CHOP 16" = 16 equal slices onto bank D), then `await state.engine.loadBank(...)` for that bank with the pad replaced, and log `SAMPLE ▸ dropped <name>`.
- Drag OUT: a BOUNCE button (lid header or deck) captures the next 4 bars of the master output to `Documents/bounces/<title>.wav` (add `func bounce(bars:completion:)` to AudioEngine by reusing its master tap, or tap `mainMixerNode` from your own file), then shows a draggable chip `↗ <title>.wav` (`.draggable` with a `Transferable` FileRepresentation, plus a ShareLink fallback).
- Files: NEW `Sources/Transfer/*.swift` (+ the tiny AudioEngine hook if needed; tell the lead).
- Verify: typecheck; in the Simulator drag a WAV from the Files app in Split View onto a pad.
