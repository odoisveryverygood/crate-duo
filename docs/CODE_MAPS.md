# CRATE code maps (2026-09-30)

Read-only maps written by 4 agents for the engineering handoff (`HANDOFF.md`). file:line refs are as of commit 71d4814.


---

<!-- sampling-ux -->

# CRATE sampling UX map (Duo inner screen: lid on top, deck below)

Repo: `/Users/shuhanzhang/crate-build`. Every path below is relative to it. I only read files and ran nothing. The app starts with `mode = .seq`, `bank = .a` and selected pad A1 (`Sources/Core/AppState.swift:7-9`).

## 1. Inventory

### Modes
`enum Mode { sample, chop, keys, seq, padFX, levels16 }` is at `Sources/Core/Models.swift:105-117`. Each one has its own mode key on the deck. Tap handling is at `Sources/UI/DeckView.swift:254-257`, which calls `CrateUI.setMode` (`Sources/UI/UISupport.swift:44-48`).

| Mode | Deck center | Deck right column | Lid main area (`Sources/UI/LidDisplayView.swift:82-111`) | Lid hero (`:293-316`) |
|---|---|---|---|---|
| SAMPLE | `SampleModePanel` (mic record strip) above the pads (`DeckView.swift:204-208`, `:279-296`) | Bank, LEVEL, transport, DIG | AI log. A chop waveform shows only if **bank B** has sounds (`LidDisplayView.swift:100-107`) | BPM, SWING, BAR |
| CHOP | Normal pad grid; there are no chop controls on the deck (`DeckView.swift:209-210`) | same | `ChopWaveView`, the only place slices can be edited (`Sources/UI/LidPanels.swift:234-377`) | SLICE, BPM, BAR. SLICE only reads bank B (`LidDisplayView.swift:359-362`) |
| KEYS | One-octave keyboard across the full width. The right column is hidden, so there are no BANK keys and no fader (`DeckView.swift:15-16`, `:36-88`) | none; OCT−, OCT+, SCALE replace 16 LVL and SHIFT (`DeckView.swift:244-245`, `:263-271`) | Waveform of the selected pad (`LidPanels.swift:381-413`) | NOTE, SEMI. The LOOP bar shows ROOT/OCT instead (`LidDisplayView.swift:275-280`) |
| SEQ (default) | Pad grid | Bank, LEVEL, transport, DIG | Step dot grid (`LidPanels.swift:57-230`). In portrait the AI log is added (`LidDisplayView.swift:84-94`) | BPM, SWING, BAR |
| PAD FX | The 16 pads become effects, plus an FX knob and a LATCH/HOLD key (`Sources/UI/PadFXView.swift:6-126`). You cannot play pads in this mode | The fader becomes PUNCH (`DeckView.swift:214-221`) | AI log | PUNCH or FX %, BPM, BAR |
| 16 LVL | Pads show "TUNE −7…+8" of the selected pad; pad 8 = 0 (`Sources/UI/PadGridView.swift:108-121`, `:178-179`) | same | AI log | BPM, SWING, BAR |

Entering KEYS silently moves the selection (and the bank) to the first pitched pad, checking bank C first (`UISupport.swift:51-57`).

### Deck controls (`Sources/UI/DeckView.swift`, `Sources/UI/DeckControls.swift`)
- **Mode keys ×6** (`DeckView.swift:243-257`).
- **SHIFT** (`DeckView.swift:259-262`):
  - A tap latches the next pad touch as "select without playing", then un-latches (`PadGridView.swift:173-177`).
  - A 0.6 s long-press toggles the pad skin between plain and records (`Sources/UI/RecordPad.swift:20-33`). This is hidden.
- **BANK A–D** (`DeckControls.swift:292-335`, calling `UISupport.swift:60-68`). In KEYS mode it also selects that bank's first pitched pad. It is not on screen in KEYS mode.
- **LEVEL fader**: per selected pad (`DeckView.swift:223-228`). **It does nothing audible.** `CrateUI.onLevel` is never assigned; only `onPunch` is wired (`Sources/App/CrateApp.swift:17`, `UISupport.swift:22-25`). It only moves the cosmetic lid bank meters (`LidDisplayView.swift:474-477`).
- **PUNCH fader**: only in PAD FX mode (`DeckView.swift:299-321`).
- **REC** toggles `isRecording` (`DeckControls.swift:435-440`). Pad hits are recorded only while playing (`Sources/Audio/AudioSequencer.swift:547`).
- **PLAY** (`DeckControls.swift:442-448`).
- **STOP** stops playback and also turns REC off (`DeckControls.swift:450-455`).
- **DIG**: focuses the lid prompt, or submits the draft if there is one (`DeckControls.swift:484-515`, `UISupport.swift:33-41`).
- **Project chip** opens the projects sheet (`Sources/UI/ProjectsView.swift:4-23`). BOUNCE is hidden (`DeckView.swift:81`).
- **Pads**: touch-down plays and selects, with velocity from touch height (`PadGridView.swift:153-184`). The pad grid is also the audio drop target (`PadGridView.swift:52-71`).
- **SAMPLE panel** (`Sources/Sampler/SampleRecordButton.swift`):
  - CHOP TYPE chips THRESH / REGIONS 16 (`:15-26`).
  - Hold-to-record strip (`:27-71`), with the caption "HOLD TO RECORD · RELEASE TO CHOP → BANK D" (`:75`).
- **PAD FX**: 16 effect pads (layout at `Sources/Core/FXType.swift:54-59`), the FX knob (`PadFXView.swift:171-234`) and LATCH/HOLD (`PadFXView.swift:120-125`).

### Lid controls (`Sources/UI/LidDisplayView.swift`, `Sources/UI/LidPanels.swift`)
- **Prompt field** (`LidDisplayView.swift:755-828`).
- **Chips** UNDO, REDO, FLIP IT, AI PERFORM (`:837`), with tap handlers at `:889-911`. The chips are hidden while the prompt is focused (`:44`); the DIG composer shows them instead (`LidPanels.swift:544`).
- **Hidden gestures** (none has a visible affordance):
  - Vertical drag on the BPM number changes tempo (`LidDisplayView.swift:327-328`, `:343-357`).
  - Tapping the LOOP bar cycles 1→2→4→8→1 bars (`:260-266`). This still works in KEYS mode, where the bar shows ROOT/OCT instead.
  - Long-pressing the title rotates the back screen (`:179-185`).
- **SEQ grid**:
  - Tapping a dot toggles that step in **every bar** (`LidPanels.swift:104-120`, `Sources/AI/Orchestrator+Edit.swift:212-240`).
  - Tapping a lane name **deletes the whole lane** (`LidPanels.swift:111-113`, `Orchestrator+Edit.swift:199-209`). This is hidden.
- **CHOP wave**:
  - Dragging within 16 pt of a slice line moves that boundary (`LidPanels.swift:299-325`, `Orchestrator+Edit.swift:245-268`).
  - Tapping a slice plays and selects it (`LidPanels.swift:326-332`).
- **Read-only**: the SWING number (no gesture), the BANKS legend, the result line and the timing strip.

### Hardware keyboard (`Sources/App/KeyboardControl.swift`)
- Pads: Z X C V / A S D F / Q W E R / 1 2 3 4 (`:5`).
- Space = play, Return = REC, Tab = next bank, Shift+Tab = next mode, `/` = prompt (`:50-68`).
- ⌘Z / ⇧⌘Z = undo / redo (`Sources/App/RootView.swift:75-79`).

## 2. Tap flows

Counts start from the default SEQ mode.

**(a) Import an mp3 and play a chop**
- There is no in-app file picker; there is no `fileImporter` anywhere. The only way in is dragging a file from the Files app onto the pad grid (`PadGridView.swift:52`). The alternative is the dev URL `crate://import?path=` (`Sources/App/Router.swift:58-59`).
- Files over 2 s that are not demo songs open a dialog: "CHOP 16 into Bank D" or "Load on pad X" (`PadGridView.swift:62`, `:73-95`). Demo songs skip it (`Sources/Transfer/AudioImport.swift:108`).
- CHOP 16 does all of this automatically (`AudioImport.swift:140-155`, `Sources/AI/Orchestrator+Import.swift:14-67`):
  - replaces **all of bank D**,
  - switches to bank D and selects D1,
  - **auto-starts playback** of a starter flip (`Sources/AI/Orchestrator.swift:284`),
  - lets GPT re-flip it in the background.
- Then tap a pad.
- **Total: 1 drag (needs Files open alongside) + 1 dialog tap + 1 pad tap.** No checkpoint is pushed, so it cannot be undone cleanly.
- "Load on pad" puts the whole file on one pad of the current bank as a `.loop` (`AudioImport.swift:83-105`), overwriting that pad. That is also not undoable.

**(b) Record from the mic onto a pad**
- Steps: SAMPLE (1 tap), optionally a CHOP TYPE (1 tap), **hold** the strip, release, then tap a pad. **Total: 2–3 taps + 1 hold.**
- On the first use, the mic-permission prompt appears mid-hold. Releasing invalidates that take (`Sources/Sampler/MicSampler.swift:117-121`), so the user has to hold again.
- You cannot choose a destination pad. The take always replaces **all 16 pads of bank D**, including an imported song, then switches to D and selects D1 (`MicSampler.swift:146`, `Sources/Sampler/SampleBankCommit.swift:13-17`).
- No checkpoint is pushed. UNDO pops the previous checkpoint, which wipes the take and also reverts the last DIG or edit (`Orchestrator+Edit.swift:91-144`).
- The take does not create an Orchestrator session, so FLIP IT cannot flip it (see §3).
- The lid shows no waveform for the take unless bank B already has sounds (`LidDisplayView.swift:101`).

**(c) Pick a pad and swap its sound**
- There is **no browse or audition UI**. Select a pad by tapping it (which plays it) or with SHIFT then the pad (2 taps, silent).
- Then DIG (1 tap), type, and press Return.
- The prompt **must** contain "pad N", "this pad", "selected pad", "one sound" or "single sound" (`Sources/AI/KeywordParser.swift:191-193`). Otherwise the prompt is read as a full beat or drums request and whole banks get replaced.
- The best match goes onto the selected pad and auditions (`Sources/AI/Orchestrator+Scopes.swift:124-149`).
- Resubmitting the same prompt gives the next variant (`Orchestrator.swift:86-88`).
- **Total: about 3 taps + typing per audition.**
- The other route is dragging a file shorter than 2 s onto a pad, which loads it directly (`PadGridView.swift:63`).

**(d) Adjust chop slice points**
- Steps: CHOP (1 tap), then drag a slice line **on the lid**. The slice auto-auditions.
- The lid shows bank B, or bank D only when D is the selected bank or B is empty (`LidPanels.swift:240-244`). If both have chops, the user must press BANK D first, and nothing tells them this.
- The drag only moves a shared boundary (indices 1–15). You cannot move slice 1's start or slice 16's end, set start and end separately, re-chop, change the slice count or zoom (`Orchestrator+Edit.swift:245-251`).
- THRESH / REGIONS 16 exist only in SAMPLE mode, and only before recording.
- The SLICE readout shows "--" for chops on bank D (`LidDisplayView.swift:359-362`).

**(e) Sequencer steps and live recording**
- **Adding steps:** tap a pad on the deck (it plays and selects, and its lane appears on the lid, `LidPanels.swift:33-42`), then tap a lid dot. That is 2 taps.
  - Each toggle applies to every bar.
  - You cannot pick which bar you are viewing; the page follows the playhead (`LidPanels.swift:146-157`).
  - Bank B lanes are merged into one "CHOP" row, and a new step there goes to the first B pad that has hits (`Orchestrator+Edit.swift:227`).
  - Each bank D pad gets its own row, all labelled "CHOP" (`UISupport.swift:195-211`).
- **Live recording:** REC, then PLAY, then play pads, then STOP. That is 3 taps plus hits.
  - Hits are quantized to 1/16 as overdub (`AudioSequencer.swift:564-583`).
  - There is no count-in, no metronome and no quantize toggle (grep found none).
  - The overdub pass is not checkpointed, so it cannot be undone.

**(f) Undo**
- The UNDO chip on the lid is 1 tap. Typing "undo" and ⌘Z also work.
- It is snapshot-based and keeps 30 entries (`Orchestrator+Edit.swift:31-37`).
- It covers only checkpointed actions: DIG (`Orchestrator.swift:95`), tempo, bars, lane delete, step toggle, slice move and pad layout.
- It does **not** cover mic takes, imports, live overdub or FX. Any of those gets rolled back together with the previous action.

**(g) BPM and bars**
- BPM: drag the BPM numeral vertically on the lid (hidden), or type "bpm 100" / "faster" (`Orchestrator+Edit.swift:340-347`). There is no tap tempo. BPM does not appear in KEYS mode.
- Swing: can only be changed through the prompt ("more swing" goes through changeGroove, `Orchestrator+Scopes.swift:99-122`).
- Bars: tap the LOOP bar (hidden) or type "8 bars" (`Orchestrator+Edit.swift:349-352`).

**(h) Apply an effect**
- Steps: PAD FX (1 tap), an FX pad (1 tap), then the amount by knob drag, PUNCH fader, or folding the hinge. **Total: 3.**
- Three controls drive the same `state.punch` value.
- The hinge works in every mode (`CrateApp.swift:17`, `Sources/App/HingeFX.swift:23-58`).
- The FX is master-only, and the pads cannot be played while the FX grid is showing.
- Pulling the fader from above 0.6 to below 0.1 fires a DROP (`DeckView.swift:309-314`). This is hidden.

## 3. Bank semantics
- **Labels:** A DRUMS, B CHOPS, C BASS·KEYS, D FREE (`Sources/UI/Theme.swift:110`, `Models.swift:18`).
- **A:** the 16 kit slots from DIG (`Models.swift:35-36`). Empty pads show placeholder names (`PadGridView.swift:126`).
- **B:** chops of the library loop that DIG found (`Orchestrator.swift:166`, `Orchestrator+Scopes.swift:66`).
- **C:** C1 holds the rule/GPT bass notes and C2 holds the chord-stab keys (`Orchestrator.swift:179-182`).
- **D:** "free" in name, but in practice it holds an imported song's CHOP 16 **and** mic takes. Each one overwrites the whole bank.
- **Where chops land:**
  - DIG → B.
  - Import CHOP 16 → D.
  - Mic → D.
  - Import "Load on pad" → the drop-target pad in the current bank.
- **FLIP IT:**
  - It sends `dig("flip the sample")` (`Orchestrator.swift:72`), which **re-sequences the existing slices** without re-slicing, first locally and then with GPT (`Orchestrator+Scopes.swift:152-164`).
  - It uses the session's chop bank: B, or D after an import (`Orchestrator+Import.swift:10-11`, `:92-107`).
  - It needs `session.chops`. A mic take never sets that. With no session, the flip scope is promoted to a **full new beat** (`Orchestrator.swift:121`), which replaces banks A, B and C.
- **Likely bug:** `keyGuarded` removes the C1 bass whenever any bank D lane exists (`Orchestrator.swift:273`). But `buildDrums` writes a bass for imported flips and logs "BASS" (`Orchestrator+Scopes.swift:38-46`). That bass is probably stripped on `apply`. Verify before relying on it.

## 4. Top confusion points, ranked
1. **Sampling is spread over three modes and two screens.** Record lives in SAMPLE (deck), slice editing in CHOP (lid only), sequencing in SEQ (lid dots plus deck pads), and chop-type choice only before recording.
2. **No destination pad and silent whole-bank overwrite.** Mic and import each replace all of bank D with no warning and no undo.
3. **No in-app import.** It is drag-from-Files only, then a dialog, then music auto-starts and an AI flip begins without being asked for.
4. **No sound browser.** Swapping a pad needs a typed prompt with magic words ("this pad"); without them a whole beat is replaced.
5. **Hidden gestures carry core functions:** BPM drag, LOOP-bar tap, lane-name tap = delete, slice-line drag, SHIFT long-press, title long-press, fader-snap DROP.
6. **The CHOP view silently picks which bank to show** (B or D), and the SLICE readout ignores D. The SAMPLE-mode waveform depends on bank B, not on the take you just recorded.
7. **Undo is incomplete.** Mic takes, imports and overdubs are not checkpointed, so UNDO jumps back further than the user expects.
8. **Redundant pitch and effect paths:**
   - 16 LVL duplicates KEYS.
   - KEYS hides the BANK keys and fader and yanks the selection to a pitched pad.
   - PAD FX takes over the pads and has three amount controls (knob, fader, hinge).
9. **The LEVEL fader is dead** (cosmetic only), and SHIFT is a one-shot latch for "select without playing".
10. **Weak feedback when recording:** REC does nothing unless PLAY is also on, there is no count-in or metronome, and step toggles copy to every bar.

## 5. What research-mpc-te.md already recommends
- **Record on the pad:** hold a pad to record and release to stop, with the recording bound to a chosen pad (EP-133 B2, `research-mpc-te.md:103`). Ranked #1 for authenticity (`:307`).
- **Auto-map chops:** one slice per pad; Threshold / Regions 4/8/16 / Manual chop types; per-slice start and end on knobs (`:28-34`). Start with Regions (`:308`).
- **Sequencer recording:** REC+PLAY together, or REC then PLAY for a 4-beat count-in; hold REC plus a pad to step-record; hold ERASE plus a pad to clear (`:120-122`, `:268`).
- **One dedicated button per mode, no menu diving** (`:104`). Keys can reuse the same pads, with BANK keys acting as octave up/down while KEYS is held (`:291-293`).
- **The fader should be the live filter**, the same control the hinge drives: one parameter, two inputs (`:269`, `:296`).
- **Constraints reduce decision fatigue** (`:117`). EP-133 users play parts in real time rather than step-program them (`:144`).

---

<!-- layout -->

# CRATE device-layout map (iPhone and iPad support)

Everything below was found by reading the code only. I did not build it, run it in a simulator, or change any file.

## 0. Current state
- `project.yml:14`: `TARGETED_DEVICE_FAMILY: "1,2"`. This is uncommitted; git HEAD has `"1"`.
- Other uncommitted changes in the same files:
  - `project.yml:50-54` adds an absolute-path folder resource `/Users/shuhanzhang/duo-hack/library`. The project will only build on this Mac until that is fixed.
  - `Resources/Info.plist` swaps some key names (no values shown here). Removed: `OPENAI_API_KEY`, `TYPESAFE_API_KEY`, `CRATE_LIBRARY_PATH`. Added: `CRATE_APP_TOKEN` (`Info.plist:46-47`).
- Nothing in `Sources` checks `userInterfaceIdiom`, `SIMULATOR_*` or "Duo". Every layout decision is made in `RootView`.

## 1. RootView decision tree (`Sources/App/RootView.swift`)
Inputs:
- `hSize` / `vSize` come from the environment (:14-15).
- `deviceOrientation` comes from `UIDevice` (:16). It is updated only for portrait or landscape values (:86-92), so faceUp and unknown are ignored.
- `turnOverride` is `@AppStorage("crateTurn")`, default 999 = automatic (:18). It can be set with `crate://rot?deg=` (`Router.swift:53-54`).
- `lockedTurn` (:20).

Inside `GeometryReader` (:23):
- `division` = `reservedRegions(kind: .division).first` (:24). This is the active fold, present only when the Duo is folded.
- `anyFold` = the same query with `.includeInactive` (:25).
- `outer = hSize == .compact || vSize == .compact` (:29).
- `liveTurn = outer ? 0 : counterRotation(size)` (:30).
- `turn = (punch > 0.04 ? lockedTurn : nil) ?? liveTurn` (:31). While the hinge FX is active, the layout never re-rotates.

The branches, evaluated in order:

| # | Condition | Renders | Line |
|---|---|---|---|
| A | `outer` (any compact size class) | `CompactView` (Duo outer-screen mini UI) | :34-35, :158 |
| B | `turn != 0` | `laptop()` built at the swapped portrait size, fold from `rotatedFold(division ?? anyFold)` (:139-143), then `.rotationEffect(turn)` | :36-42 |
| C | `division` exists and has size | `fold.width >= fold.height` gives `laptop(size, fold minY/height)` (lid above deck). Otherwise `book(fold minX/width)` (lid left of deck). | :43-49 |
| D | flat, `height > width` | `laptop(size, anyFold.midY ±6, 12)`. With no fold, the default is `size.height/2 - 6`, 12 (:120-121). | :50-52 |
| E | flat, wide | `book(anyFold.midX ±6, 12)`, or `(width/2 - 6, 12)` with no fold | :53-56 |

`counterRotation` (:146-154):
- Returns `turnOverride` if it is not 999.
- Otherwise returns 0 unless both `width > height` and `deviceOrientation` is portrait or portraitUpsideDown.
- If both hold, it returns ±90 based on `effectiveGeometry.interfaceOrientation`.

Layout helpers:
- `laptop` = VStack of lid (height y), a black gap of height h, then the deck (:119-127).
- `book` = HStack of lid (width x), a black gap, then the deck (:130-136).

Modifiers on the whole tree:
- `.ignoresSafeArea()` (:82), `.statusBarHidden` (:83), `.persistentSystemOverlays(.hidden)` (:84).
- `KeyboardControl` background (:71), ⌘Z / ⇧⌘Z (:72-81).
- `sceneAccessory` (:93-107), `onHingeChange` (:108-115).

Subview self-layout:
- `DeckView` picks keys-wide if `mode == .keys` (:15-16). Otherwise it picks portrait when `h > w*1.05` (:17-18), else landscape (:19-20).
- Landscape uses fixed columns: left 74/80 (:100) and right 102 (:109). It is tuned for about 669×455 (:5).
- Portrait has a 142pt control block (:152). It is tuned for about 455×669.
- `LidDisplayView`: `portrait = h > w*1.05`, `narrow = w < 560`, `hero = w < 400 ? 48 : 58` (`LidDisplayView.swift:12-15`). It is tuned for 669×455 and about 455×669 (:6).
- `CompactView`: if `w > h` it uses an HStack (mini lid, then a square pad grid), else a VStack (`CompactView.swift:13-33`). It is tuned for 466×678 (:3).

## 2. What each device renders today
Point sizes are from Apple's specs: iPhone 17 Pro 402×874, 17 Pro Max 440×956, iPad Pro 13" 1032×1376.

| Device / state | Size classes | Branch | Result |
|---|---|---|---|
| iPhone 17 Pro portrait | C/R | A (`hSize == .compact`) | **CompactView portrait**: mini lid, 4×4 pads and a bottom row of banks, transport and DIG (`CompactView.swift:27-32, 168-229`). There are no mode keys, so SAMPLE/CHOP/KEYS/SEQ/PAD FX/LEVELS can't be reached. There is **no PUNCH fader or FX knob**, so no FX or DROP. Chips are limited to undo, redo, flip and perform (:93). This is wrong for a phone. |
| iPhone 17 Pro landscape | C/C | A | CompactView HStack (:13-25). Same gaps as portrait. |
| iPhone 17 Pro Max landscape | R/C | A (`vSize == .compact`) | CompactView HStack. |
| iPhone, any orientation | – | – | `counterRotation` is never reached because `liveTurn = 0` when `outer` (:30). |
| iPad Pro 13" portrait, full screen | R/R | D | `laptop` with no fold: lid 1032×~682, 12pt black bar, deck 1032×~682. Deck uses the **landscape** 3-column layout; lid is wide and not narrow. Usable. Fixed columns and fonts look sparse on a panel this large. |
| iPad Pro 13" landscape, full screen | R/R | E | `book(width/2-6, 12)`: lid ~682×1032, deck ~676×1032. Deck uses the **portrait** layout; lid is portrait and not narrow (676 ≥ 560). Usable. |
| iPad Split View 1/3 or Slide Over | C/R | A | CompactView. Acceptable as a fallback. |
| iPad Split View 1/2 in landscape (~678pt wide) | usually C/R | A | CompactView. |
| **iPad Stage Manager or iPadOS windowing**: device portrait, window wider than tall, regular width | R/R | **B, a bug** | `counterRotation` returns ±90 because `width > height` and the device is portrait (:148-149). The layout is drawn rotated 90°. Also possible on an iPad with orientation lock plus a resizable window. |
| iPad with interface set before any orientation notification | – | – | `deviceOrientation` starts as `UIDevice.current.orientation` (:16). If the iPad is lying flat this can be `.faceUp` or `.unknown`, which fails the guard, so the result is 0. Harmless. |

## 3. Hinge- and Duo-dependent features, with non-Duo fallback

| Feature | Where | Non-Duo behavior today | Should be |
|---|---|---|---|
| Hinge punch FX, 110° to 65° mapped to 0 to 1 punch; snap open fires DROP | `HingeFX.swift:23-28` (update), `:36-60` (`apply` with DROP detection), `:16-21` (released) | Never fires. `context.hinge` is nil on devices without a hinge (`duo-api-cheatsheet.md:43`), so `state.hingeAngle = nil` (`RootView.swift:112-113`). | Already has a fallback: `CrateUI.shared.onPunch = { hingeFX.apply($0) }` (`CrateApp.swift:17`) is shared by the PUNCH fader and the PAD FX knob, so drag-to-zero DROP still works. |
| PUNCH fader (fallback) | `DeckView.swift:215-229` (shown only when `mode == .padFX`), `PunchFader` at `:299-321` | Works, but only inside DeckView PAD FX mode. | Keep. Phone layouts must include DeckView (or at least mode keys) so it can be reached. CompactView has no route to it. |
| PAD FX knob | `PadFXView.swift:229-233` (`send` calls `onPunch`); label at `:108` "FX KNOB · HINGE", `:115-116` shows "DRAG KNOB ↕" when `hingeAngle == nil` | Works; the label is already right when there is no hinge. | Change `:108` to drop "· HINGE" when not on a Duo. |
| Punch strip on lid | `LidDisplayView.swift:32-33`, `LidPanels.swift:472` | Device-agnostic. | No change. |
| `onHingeChange` | `RootView.swift:108-115` | Fires with a nil hinge, or not at all. Harmless. | Also use it to persist a Duo flag (see §5). |
| Turn lock during punch | `RootView.swift:19-20, 31, 67-69` | Harmless. | Only meaningful on Duo. |
| `counterRotation` (Duo sim laptop-pose workaround) and orientation tracking | `RootView.swift:146-154, 16, 18, 85-92` | **Wrong** under iPad resizable windows (see §2). | Gate it on `isDuo`. |
| `reservedRegions` (.division / includeInactive) | `RootView.swift:24-25, 39, 43-56, 139-143` | Both are nil, so the split defaults to 50/50 with a **12pt black "hinge gap"** (:120-121, :55). | On phone and iPad, make the gap 0 or a hairline, and use a phone-specific split ratio. |
| Back-screen crowd, `CameraCaptureAccessory` | `RootView.swift:94-100` feeding `OuterCrowdHost` (:168-185) and `CrowdStageView` | The accessory is Duo-specific and needs full screen on the inner display plus a camera session (`cheatsheet.md:280`), so it should report unavailable. Not verified on iPhone or iPad. | No-op. `state.outerDisplayAvailable` (`AppState.swift:50`) is written at :98 and never read anywhere. |
| External display crowd, `ExternalNonInteractiveAccessory` | `RootView.swift:101-106` | May show the crowd stage on an AirPlay or USB-C external display for iPhone or iPad, since `crowdDisplayOn` defaults to true (`AppState.swift:51`). | Treat as a feature. Verify on device. |
| `CrowdCam` debug | `Router.swift:51-52`, `CrowdCam.swift:11-28` | Debug-only (`crate://cam`). | No change. |
| Long-press logo rotates back screen | `LidDisplayView.swift:179-185` | Does nothing visible on non-Duo devices; it still adds a log line. | Gate on `isDuo` (optional). |
| Paywall copy "crowd screen on the back of your Duo" | `PaywallGate.swift:251`; the attach point should be outside the pose branches (:174) | Paywall is off (`CrateApp.swift:28`). | Fix the copy before re-enabling the paywall. |
| `CompactView` itself | `RootView.swift:34-35` | Serves every compact size class. | Should serve only the Duo outer screen, plus maybe the narrow iPad multitasking fallback. |

## 4. Info.plist and iPad App Store requirements (`Resources/Info.plist`)
- `UISupportedInterfaceOrientations` (:70-76) lists all 4, including PortraitUpsideDown. There is no `~ipad` key, so the base key applies to iPad. That meets the requirement that multitasking iPad apps support all 4 orientations, so **validation passes without `UIRequiresFullScreen`**.
- `UISupportedInterfaceOrientations~ipad` is missing. It isn't required.
- `UIRequiresFullScreen` is missing, so the app joins Split View, Slide Over and Stage Manager. The layout therefore has to handle compact width and arbitrary aspect ratios on iPad. My understanding (not verified) is that iPadOS 26+ deprecates or ignores this key under the new windowing, so don't rely on adding it.
- `UILaunchScreen` is an empty dict (:66-67). That is valid.
- `UIApplicationSupportsMultipleScenes = false` (:63-64). Only one window on iPad, which is fine.
- `UIStatusBarHidden = true` (:68-69) and `UIViewControllerBasedStatusBarAppearance = false` (:77-78).
- `LSRequiresIPhoneOS = true` (:38-39) is normal for iOS apps, including iPad.
- App icon: a single universal 1024 image (`Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`). That is enough for iPad.

## 5. Minimal implementation plan

### 5.1 Duo detection (RootView)
Add after `RootView.swift:20`:
```swift
@AppStorage("crateIsDuo") private var hingeSeen = false
private static let simDuo: Bool = {
    #if targetEnvironment(simulator)
    let e = ProcessInfo.processInfo.environment
    return (e["SIMULATOR_DEVICE_NAME"] ?? "").localizedCaseInsensitiveContains("Duo")
        || (e["SIMULATOR_MODEL_IDENTIFIER"] ?? "").localizedCaseInsensitiveContains("Duo")
    #else
    return false
    #endif
}()
```
- In the body after :25: `let isDuo = anyFold != nil || hingeSeen || Self.simDuo`.
- In `onHingeChange` (:109): set `hingeSeen = true` inside `if let h`.
- Things to confirm on a Duo sim:
  - The Duo model identifier on real hardware is unknown, so don't use `utsname`.
  - `.includeInactive` is expected to return the fold on the Duo inner display even when flat (`cheatsheet.md:76, 445`) and nothing on iPhone or iPad.
  - On the closed Duo outer display, `anyFold` is probably nil, which is why the hinge flag and the sim env check are needed.

### 5.2 Branching
Replace :29-30 with:
```swift
let phone = UIDevice.current.userInterfaceIdiom == .phone
let outer = isDuo && (hSize == .compact || vSize == .compact)
let liveTurn = (outer || !isDuo) ? 0 : counterRotation(size: size)
```
This removes the iPad Stage Manager rotation bug. Also add `isDuo` as a guard inside `counterRotation` (:148) so debug overrides can't affect non-Duo devices; that means passing it in.

Insert new branches in the ZStack (:34) before the Duo branches:
- `if !isDuo && phone { size.height > size.width ? phoneStack(size) : phoneSide(size) }`
- `else if !isDuo && hSize == .compact { phoneStack(size) }` for iPad Slide Over or narrow split. CompactView is acceptable here if that's faster.
- `else if !isDuo { size.height > size.width ? laptop(size: size, fold: (size.height*0.5, 1)) : book(fold: (size.width*0.5, 1)) }`. This is the iPad path and matches the existing flat D/E logic with a hairline gap.
- Otherwise the existing Duo tree (:34-56) stays unchanged.

New helpers, next to `laptop`/`book` (:118-136):
- `phoneStack`: VStack of `lid` at about 40% of the height, a 1pt `Theme.hingeGap` (`Theme.swift:72`), then `deck`.
  - On an iPhone 17 Pro (874pt tall), the deck gets about 402×520. That is taller than 1.05×width, so DeckView portrait (:118-164) is used.
  - Check that the 142pt control block (:152), the mode row and the pads fit.
  - The lid gets about 402×350: `narrow` is true and `hero` is 58 since 402 is not under 400. The lid is likely too tall for that space, so it probably needs a compact lid variant, or hide `mainArea` below about 380pt.
- `phoneSide`: HStack of `lid` at about 45% of the width, then `deck`.
  - On a 17 Pro in landscape the deck is about 480×402, so DeckView landscape with `narrow` true (:92).
  - The fixed columns 74+102 plus padding leave about 230pt for pads. Consider a phone-landscape deck variant, or `mode == .keys`-style wide keys.
- Both helpers must pad by `proxy.safeAreaInsets`, because the root `.ignoresSafeArea()` (:82) puts content under the Dynamic Island and the home indicator. CompactView already does this (`CompactView.swift:11, 36-37`) and can serve as the model.

### 5.3 Small follow-ups
- `PadFXView.swift:108`: drop "· HINGE" when `hingeAngle == nil` and not on a Duo. Pass a flag or add a `CrateUI.shared.isDuo`.
- `LidDisplayView.swift:179-185`: gate the crowd-rotation long-press on Duo.
- `PaywallGate.swift:251`: make the copy conditional before the paywall is re-enabled.
- iPad polish (optional): cap the size of DeckView and LidDisplayView, or scale them up. They use fixed metrics (`DeckView.swift:100, 109`; `LidDisplayView.swift:14-15`).

### 5.4 Verification
Once the user allows simulator use, build for these simulators:
- iPhone 17 Pro, portrait and landscape
- iPhone 17 Pro Max, landscape (R/C)
- iPad Pro 13", portrait, landscape, 1/3 split, and a Stage Manager window that is wide while the device is portrait
- Duo, to confirm no regression

Set `AppConfig.debugLog` to show the overlay (:58-65). It prints size, div, hinge and turn. `layout_turn` is logged at :66.

### Risks
1. **Duo regression.** Branch A used to catch every compact size class. Now it catches them only when `isDuo`. If `anyFold` is nil on the Duo outer display and no hinge event has happened yet (first launch while closed), the outer screen gets the phone layout instead of CompactView. Mitigations:
   - `simDuo` covers the simulator.
   - Check whether `onHingeChange` delivers an initial value at launch.
   - Worst case the phone layout on the 5.4" outer screen is still usable.
2. `hingeSeen` persists across devices restored from a backup (Duo backup restored to an iPhone), which would force Duo mode there. Consider clearing it when `onHingeChange` reports a nil hinge on the inner display.
3. `.includeInactive` returning nil on iPhone and iPad is assumed, not verified.
4. Phone space is tight: DeckView portrait and LidDisplayView were tuned for about 455×669 and 669×455. Expect clipping at 402pt width and in landscape heights of about 402pt.
5. Safe areas: the root ignores them, so the new phone branches must add insets themselves.
6. iPadOS windowing allows any aspect ratio, so the flat `height > width` split must look right at every ratio. Watch the thresholds at `DeckView.swift:17` and `LidDisplayView.swift:12`.
7. The external-display accessory may unexpectedly show the crowd stage on iPhone or iPad when a display is connected.
8. The absolute path in `project.yml:50` and the uncommitted Info.plist key changes need resolving before any commit or CI build.

Key files:
- `/Users/shuhanzhang/crate-build/Sources/App/RootView.swift`
- `/Users/shuhanzhang/crate-build/Sources/App/HingeFX.swift`
- `/Users/shuhanzhang/crate-build/Sources/App/CrateApp.swift`
- `/Users/shuhanzhang/crate-build/Sources/UI/DeckView.swift`
- `/Users/shuhanzhang/crate-build/Sources/UI/LidDisplayView.swift`
- `/Users/shuhanzhang/crate-build/Sources/UI/CompactView.swift`
- `/Users/shuhanzhang/crate-build/Sources/UI/PadFXView.swift`
- `/Users/shuhanzhang/crate-build/Resources/Info.plist`
- `/Users/shuhanzhang/crate-build/project.yml`
- `/Users/shuhanzhang/crate-build/duo-api-cheatsheet.md`

---

<!-- infra -->

# CRATE: AI proxy, server and site infrastructure (as of 2026-09-30)

## 1. Request flow: app → proxy → upstream

**The app side, which is uncommitted working-tree changes**
- `AppConfig.string(key)` checks the process environment first. If that is empty, it reads Info.plist and ignores unexpanded `$(...)` values (`Sources/Core/Support.swift:6-10`).
- The proxy base URL is `CRATE_AI_BASE`, which defaults to `https://crateduo.vercel.app/api/ai` (`Support.swift:18`). `CRATE_AI_BASE` is not in Info.plist, so it can only be overridden with an env var.
- The shared token is `AppConfig.appToken`, read from `CRATE_APP_TOKEN` (`Support.swift:19`). It comes from Info.plist key `CRATE_APP_TOKEN = $(CRATE_APP_TOKEN)` (`Resources/Info.plist:46-47`), which is filled from `Config/Secrets.xcconfig` via `#include?` in `Config/Base.xcconfig`, wired in at `project.yml:30-32`.
- Direct upstream keys are **env only**, never read from the bundle: `OPENAI_API_KEY` and `TYPESAFE_API_KEY` (`Support.swift:21-22`). Their Info.plist entries were removed in the diff.
- **OpenAI** (`Sources/AI/OpenAIClient.swift:58-64`):
  - If there is a token, it sends `POST {aiBase}/openai` with header `x-crate-token`.
  - Otherwise it sends `POST https://api.openai.com/v1/responses` with `Authorization: Bearer <env key>`.
  - Body (`:49-55`): the model is `gpt-6-luna` for arrange or `gpt-6-sol` for flip (`:30-31`), with `reasoning.effort=none`, `instructions`, `input`, and `text.format` json_schema strict.
  - Timeout is 8s for arrange and 12s for flip (`Orchestrator+Scopes.swift:184`), plus 1s on the URLRequest (`OpenAIClient.swift:67`).
- **Jev** (`Sources/AI/JevClient.swift:88-94`):
  - Same pattern: `POST {aiBase}/jev` with `x-crate-token`, or `POST https://api.typesafe.ai/v1/systemone` with Bearer.
  - Body is `{model:"jev-latest", state, questions}` (`:98`).
  - Timeouts are 0.9s for plan and route (`Orchestrator.swift:102`, `Orchestrator+Scopes.swift:127`) and 4s for warm-up (`JevClient.swift:72`).

**The proxy, which is untracked in git but deployed**
- **`site/api/ai/openai.js`**
  - POST only, otherwise 405 (`:15`).
  - Returns 401 if `CRATE_APP_TOKEN` is unset or `x-crate-token` does not match (`:16-18`). The comparison is plain `!==`, not constant-time.
  - Rate limit is 40 requests/min per IP, keyed on the first `x-forwarded-for` hop (`:4-12`, `:19-20`), and returns 429.
  - Model allowlist is `{"gpt-6-luna","gpt-6-sol"}` (`:3`); anything else gets 400 (`:24`).
  - `input` and `instructions` are each capped at 20,000 chars, otherwise 413 (`:25-27`).
  - The server forces `reasoning.effort:"none"` and `max_output_tokens:4000`. It forwards `text` unchanged (`:29-36`).
  - Upstream call uses `Bearer ${OPENAI_API_KEY}` (`:37-41`). The upstream status and body are passed back as-is (`:42-43`).
  - There is no try/catch around `fetch`, so a network error becomes an unhandled 500.
- **`site/api/ai/jev.js`**
  - Same method and token gate (`:13-16`).
  - Rate limit is 120 requests/min per IP (`:4`).
  - `state` is required and capped at 8,000 chars; `questions` must be an object (`:22-23`). `questions` has **no size or count cap**.
  - Upstream is `https://api.typesafe.ai/v1/systemone` with `Bearer ${TYPESAFE_API_KEY}`, and the model is hardcoded to `jev-latest` (`:25-29`).
- **Weaknesses in the rate limiter**
  - `hits` is a module-level `Map` (`openai.js:4`, `jev.js:2`). The limit therefore applies **per warm serverless instance**: it resets on cold start and is not shared across concurrent instances. The real limit is N instances × 40 or 120.
  - Map keys are never evicted, so memory grows slowly within an instance.
  - IP rotation defeats it entirely.
  - A proper fix needs a shared store, such as Vercel KV/Upstash, keyed on IP plus some install id.
- **Latency risk:** the 0.9s Jev budget now includes an extra Vercel hop and possible cold starts. More Jev timeouts will fall back silently to the keyword plan, logged as `"JEV timeout → keyword plan"` (`Orchestrator.swift:107`).

**Live checks (network)**
- `POST /api/ai/openai` with `{}` returns **401**.
- `POST /api/ai/jev` with `{}` returns **401**.
- `GET /api/waitlist` returns **405**.
- So both AI functions are **deployed to production**, even though they are untracked in git. They were deployed from the local working tree via the Vercel CLI link in `site/.vercel`.

## 2. How the app decides AI is "available", and what offline does

- `OpenAIClient.available = (appToken != nil || openAIKey != nil) && !offline` (`OpenAIClient.swift:34`).
- `JevClient.available` is the same, using `typesafeKey` (`JevClient.swift:38`).
- `offline` is `UserDefaults "crateOffline"`, set with the launch arg `-crateOffline 1` (`Support.swift:24-25`). The verify scripts use it (`Sources/Crowd/verify.sh:220`, `Sources/Transfer/Verification/check.sh:36`).
- "Available" only means **a credential is configured**. There is no reachability or health check, so a device with no network still counts as available and each call pays its timeout before falling back.
- Fallbacks:
  - **DIG plan:** Jev is skipped and the keyword parser plan is used (`Orchestrator.swift:100-109`).
  - **Single sound:** the route falls back to the keyword category, or `"perc"` (`Orchestrator+Scopes.swift:127-131`).
  - **GPT arrange/flip:** skipped completely, so the template pattern stays (`Orchestrator+Scopes.swift:177`). `arrange` returns `.failure("offline")` (`OpenAIClient.swift:46`).
  - **Perform mode:** switches to the rule-based fill rotation (`Performer.swift:21,38-45`).
  - **Warm-up:** no-op (`JevClient.swift:69`).

## 3. Committed vs uncommitted

**`git status --short`:**
- ` M` `Resources/Info.plist`, `Sources/AI/JevClient.swift`, `Sources/AI/OpenAIClient.swift`, `Sources/Core/Support.swift`, `project.yml`
- `??` `site/api/ai/`: **both `openai.js` and `jev.js` are untracked**

**`git diff --stat`:** 5 files, +38/−18.

What the diff contains:
- **Info.plist:** removes `CRATE_LIBRARY_PATH`, `OPENAI_API_KEY` and `TYPESAFE_API_KEY`, and adds `CRATE_APP_TOKEN`. `CRATE_LIBRARY_PATH` is now an env-only override.
- **Clients:** switch to proxy-first requests, as described in section 1.
- **Support.swift:** adds `aiBase` and `appToken`, makes the upstream keys env-only, and changes the `libraryURL` order to env → `Bundle.main.url(forResource:"library")` → the hardcoded dev path (`:12-16`).
- **project.yml:**
  - `TARGETED_DEVICE_FAMILY` changes from `"1"` to `"1,2"` (`:14`). **This adds iPad**, which may be unintended.
  - Adds the library folder resource (`:50-54`).

**Tracked in `site/`:** `api/waitlist.js`, `vercel.json`, `package.json`/`package-lock.json`, `waitlist-export.mjs`, `index.html` and the other html/png files, `.gitignore`, `.vercelignore`.

**Ignored:**
- `site/.env.local`, which holds the names `BLOB_READ_WRITE_TOKEN` and `VERCEL_OIDC_TOKEN`.
- `site/.vercel`.
- `site/node_modules`.
- `Config/Secrets.xcconfig` (repo `.gitignore:4`). `Config/Base.xcconfig` is tracked.

Latest commit is `9a6c21d Handoff: include XHS post copy`.

## 4. Env var names

- **Vercel** (`vercel env ls production`, run in `site/`; scope `simtra`, project `crate`, projectId `prj_21B92TeOdsBgocA4uMNzltvcoYsk`):
  - `CRATE_APP_TOKEN`, `TYPESAFE_API_KEY`, `OPENAI_API_KEY`: type Secret, Production only, created about 9 minutes before the check.
  - `BLOB_READ_WRITE_TOKEN`: type **Config**, which is *not* sensitive, so `env ls` prints a value prefix. Set for Production, Preview and Development.
  - The three AI vars are **not set for Preview**, so AI calls to preview deployments will always return 401.
- **`Config/Secrets.xcconfig`:** `CRATE_APP_TOKEN`, `REVENUECAT_API_KEY`. Its header comment says it is generated from `~/duo-hack/.secrets/keys.env` and that the OpenAI/TypeSafe keys live on the server.
- **App runtime overrides (env):** `CRATE_AI_BASE`, `CRATE_APP_TOKEN`, `OPENAI_API_KEY`, `TYPESAFE_API_KEY`, `CRATE_LIBRARY_PATH`.
- **Launch args:** `-crateOffline 1`, `-crateDebugLog 1`, `-crateDebugRecord 1` (`Support.swift:25-27`).

## 5. Security notes

- **`CRATE_APP_TOKEN` is a speed bump, not authentication.** It is written in plaintext into the IPA's Info.plist (`Info.plist:46-47`), so anyone with the IPA can read it and call the proxy. The only real protections are:
  - the model allowlist
  - the 20k-char input caps and 4000-token output cap
  - the per-instance rate limit
- Suggestions, in rough order:
  1. **Hard spend caps** on the OpenAI project and TypeSafe accounts. Use a separate OpenAI project and key just for CRATE, with a monthly budget and alerts; compare the 2026-09-18 leaked-key incident.
  2. **A shared rate limit** (KV/Upstash), keyed on IP plus an install id, with a daily per-install quota.
  3. **A cap on `questions`** in `jev.js`, such as byte size and key count, or better, send only a question-set *name* (`plan`/`perform`/`route`) and keep the questions JSON server-side.
  4. **Whitelist the `text.format` fields** in `openai.js:34` instead of forwarding `b.text` unchanged. Longer term, move the system prompt and schema server-side so the proxy cannot be used as a general-purpose GPT endpoint.
  5. **App Attest / DeviceCheck** to replace the static token once the app ships: attest, then issue short-lived signed tokens. Use RevenueCat entitlement checks for paid-only AI.
  6. **Rotation:** the token can be rotated by updating both the Vercel env var and `Secrets.xcconfig`, but old builds break when it changes.
  7. **Smaller fixes:** constant-time comparison for the token; try/catch around upstream `fetch` returning 502; set `BLOB_READ_WRITE_TOKEN` to the sensitive type in Vercel.
- **The upstream keys are out of the app bundle** in this diff. Earlier committed builds put `OPENAI_API_KEY` and `TYPESAFE_API_KEY` into Info.plist. If any such IPA or TestFlight build was distributed, **rotate both keys**.
- **Waitlist** (`site/api/waitlist.js`): no auth or rate limit, only a honeypot `company` field (`:20`). It writes private Blob objects (`:45-47`). Role answers overwrite per email hash (`:29-35`), so anyone who knows an email can change that person's role (low impact). Export and delete are local only, via `waitlist-export.mjs`, which reads `BLOB_READ_WRITE_TOKEN` from `.env.local` (`:5-7`).
- **Site config:** `vercel.json` sets redirects `/xhs /x /li /tc /yc` → `/?r=...` and adds `X-Content-Type-Options: nosniff`. The only dependency is `@vercel/blob ^2.8.0` (`package.json:1`).

## 6. Library bundling

- **What is bundled:** `project.yml:50-54` adds `/Users/shuhanzhang/duo-hack/library` as a folder resource, excluding `*.md` and `*.backup-*.json`. At runtime the app finds it through `Bundle.main.url(forResource:"library")` (`Support.swift:14`).
- **Only builds on this Mac:** the path is absolute, so XcodeGen and the build fail or skip anywhere else, including CI and other machines.
- **Size:** `~/duo-hack/library` is **308M**, made of `loops/` 211M, `oneshots/` 96M, and 632 `.wav` files. All of it goes into the IPA.
- **Licensing:** these are commercial sample packs (for example `"Golden Trap Drumkit/..."` in `oneshots.json`). Redistributing them inside an App Store binary likely **violates the pack licenses**, so clear this before any public build.
- **App size:** 300MB+ is over the cellular-download comfort zone.
- **Repo copy:** `~/crate-build/library` is 592K and contains only JSON and MD, all tracked. `.gitignore` excludes `library/**/*.wav` and `assets/**/*.wav`; the wavs can be regenerated from `~/Documents` using `tools/*.py`.
- **Drift between copies:**
  - `grooves.json`, `loops.json`, `LOOPS.md` and `ONESHOTS.md` are identical.
  - **`oneshots.json` differs.** The duo-hack copy (Sep 26 12:26, 363,434 B) is newer than the tracked copy (commit `78baf69`, Sep 26 10:38, 362,345 B). There are 209 differing lines, for example `rootNote` 36→24 on 808s. The **bundled** copy is the untracked duo-hack one.
  - `demo_samples.json` exists only in duo-hack and is bundled.
- **Jev questions path:** `JevClient.loadQuestions` looks in the bundle first (`JevClient.swift:52-53`). Its third fallback, `libraryURL/../ai/jev-questions.json` (`:54`), resolves inside the app bundle when the library is bundled, so it only works on the dev path. The embedded JSON is the final fallback (`:60`).
- **Recommended fix:** move the library into the repo, or use Git LFS or on-demand download (for example Blob/CDN, fetched on first run), and replace the absolute path with a repo-relative one.

---

<!-- tooling -->

# CRATE build, run, test and debug tooling (repo `~/crate-build`)

I ran nothing that changed state: no build, nothing booted or installed, nothing edited. The only network call was `git fetch`.

**Before building, check these:**
- **Uncommitted changes.** The working tree has local edits to `project.yml`, `Resources/Info.plist`, `Sources/Core/Support.swift`, `Sources/AI/JevClient.swift` and `Sources/AI/OpenAIClient.swift`.
  - AI calls now go through the server with `CRATE_APP_TOKEN`.
  - The sample library is now bundled into the app.
  - iPad support is on (`TARGETED_DEVICE_FAMILY "1,2"`).
- **The app only runs on the Duo simulators.** The deployment target is iOS 27.1 (`project.yml:5`), and the iPhone Duo devices are the only simulators on that runtime. iPhone 17 Pro / Pro Max (26.5) and the iPads (26.5 / 27.0) can't run the current build.
- **`-crateNoPaywall` and `crate://paywall` do nothing today.** Details are in section 4.

## 1. Build
- xcodegen 2.45.4 is at `/opt/homebrew/bin/xcodegen`. `Crate.xcodeproj` is gitignored (`.gitignore` `*.xcodeproj/`), so always regenerate it.
```
cd ~/crate-build
export DEVELOPER_DIR=~/Downloads/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project Crate.xcodeproj -scheme Crate -destination "generic/platform=iOS Simulator" -derivedDataPath build/dd build
xcrun simctl install <UDID> build/dd/Build/Products/Debug-iphonesimulator/Crate.app   # bundle id com.shuhan.crate (project.yml:59)
```
- **Project settings:**
  - Swift 5 with minimal concurrency checking.
  - Signing is manual with identity `-`.
  - RevenueCat SPM ≥ 5.91.0 (`project.yml:18`).
  - `Config/Base.xcconfig` (`project.yml:30`) runs `#include? "Secrets.xcconfig"`.
- **Secrets:**
  - `Config/Secrets.xcconfig` (gitignored) holds the key names `CRATE_APP_TOKEN` and `REVENUECAT_API_KEY`.
  - Its source file `~/duo-hack/.secrets/keys.env` holds the key names `TYPESAFE_API_KEY`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY` and `CRATE_APP_TOKEN`.
- **Library bundling:** `project.yml:50` now bundles `/Users/shuhanzhang/duo-hack/library` (308 MB, absolute path) as a folder. The app looks for the library in this order (`Support.swift:12-15`):
  1. the env var or Info.plist value `CRATE_LIBRARY_PATH`
  2. the bundled `library`
  3. the hard-coded dev-Mac path
- **AI server:** the base URL is `CRATE_AI_BASE`, default `https://crateduo.vercel.app/api/ai` (`Support.swift:18`). The server side is `site/api/ai/{jev,openai}.js`.
- **Existing build:** `build/dd/Build/Products/Debug-iphonesimulator/` contains `Crate.app` and `Crate.swiftmodule` from Sep 30 00:06, plus RevenueCat `.o` files, modules and bundles.
  - This build already includes the uncommitted changes: `Crate.app/library` exists and there is no `CRATE_LIBRARY_PATH` key in its Info.plist.
  - Other derived-data folders: `build/dd-clean`, `dd-flip`, `dd-fx`, `dd-house`, `dd-rc`, `dd-save`, `dd-video`.
- **`tools/video/go_build.sh <udid>`** builds `origin/main` HEAD in a clean `git archive` export (copying `Secrets.xcconfig` in) and installs it on the simulator. Its default work dir is hard-coded to an old session scratchpad; override it with `VIDEO_BUILD_DIR`.
- **Tests:** there is no XCTest target in `project.yml`. Testing means the self-test script, the macOS harnesses and the per-module verify scripts (section 5).

## 2. Simulators
Default set (only simulators relevant here):

| Name | UDID | Runtime | State |
|---|---|---|---|
| iPhone Duo | 0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4 | iOS 27.1 | Shutdown (default for `selftest.sh:6`) |
| Duo-Test | 89122C41-D45F-4DF6-8068-6FED286C2A03 | iOS 27.1 | Shutdown |
| **Duo-Video-3** | E82B9354-4493-4C8B-A6B8-52BA5EE92C7F | iOS 27.1 | **Booted** (the two crashes happened here) |
| iPhone 17 Pro | 46B2AB32-0CE8-434E-9037-5C66CCB0A38A | iOS 26.5 | Shutdown (below the deployment target) |
| iPhone 17 Pro Max | 67F5B8C9-1246-4ED0-940E-911F404FFEDA | iOS 26.5 | Shutdown (below the deployment target) |
| iPad Pro 13" (M5) | 01F69029-… (26.5) / 145D9367-05C9-47FA-AEB0-DDA8CCACA2B1 (27.0) | | Shutdown (below the deployment target) |
| iPad Pro 11" (M5) | 27BE020C-… (26.5) / C2EEF9A2-F265-4B36-8F9E-63889B53B5B8 (27.0) | | Shutdown (below the deployment target) |
| iPad mini (A17 Pro) | 46104A8F-… (26.5) / 760D468E-C3F9-4C83-9C8D-A0E65E019DBC (27.0) | | Shutdown (below the deployment target) |

- The device type is `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`.
- The runtimes installed are iOS 26.5, 27.0 and 27.1.

Bitrig set (`--set "$HOME/Library/Application Support/app.bitrig.bitrigapp/SimulatorHost/Devices"`):
- iPhone Duo `9193E59E-E5A1-449D-BF60-C48438FE33AC` on iOS 27.1, Shutdown. `tools/video/bitrig_fx_take.py:15` uses this device.
- iPad Pro 13" (M5) (16GB) `3058DE90-F371-4E2C-AED1-88BEB8818D37` on iOS 27.0, Shutdown.

**Booted right now:** only Duo-Video-3 in the default set. Nothing is booted in the Bitrig set.

## 3. The `hinge` tool
- **Location:** `/opt/homebrew/bin/hinge` is a symlink to `~/src/hinge/bin/hinge` (a bash script). It spawns a compiled helper, `~/.cache/hinge/hinge_helper-f56392df4622`.
- **Usage:** `hinge [-d <udid|name|booted>] <deg 0..180> | set <deg> | open | close | half | sweep <from> <to> [secs] | get`
- **How the scripts use it:**
  - `tools/selftest.sh:27` sets `hinge -d $U 150` (open).
  - `tools/selftest.sh:39` folds with `sweep 150 30 3`.
  - `tools/selftest.sh:40` snaps back to 150, which triggers the DROP.
  - `tools/video/take_v1*.py:57` wraps it as `["hinge","-d",UDID,...]`.
- **Bitrig set:** `hinge -d` only reaches the default set. For Bitrig, run the helper directly: `xcrun simctl --set "$B" spawn <udid> ~/.cache/hinge/hinge_helper-* set <deg>` (`bitrig_fx_take.py:16-17, 46-48`).
- **What the app logs:** hinge changes emit `CRATE {"event":"hinge","deg":…,"status":"partiallyOpen"}`, and a snap-open emits `{"event":"drop","source":"hinge"}` (see `demo/clips/console_*.log`). `take_v3.py:133` notes there is no DROP detection in the first ~2 s after launch.

## 4. Debug command channel
**How commands arrive:**
- **URL:** `xcrun simctl openurl <udid> "crate://…"`. The `crate` URL scheme is registered at `Resources/Info.plist:25-34`, and `CrateApp.swift:30` routes it with `.onOpenURL { Router.handle }`.
- **Command file (no prompt):** launch with `-crateCmdFile /tmp/x.txt`. The app polls that host file every 0.1 s and runs each new line as a URL (`DebugCommands.swift:10-21`).
  - Lines already in the file at launch are skipped (`DebugCommands.swift:11`).
  - The channel starts in `.onAppear` (`CrateApp.swift:31`).
- **Logging:** every routed URL logs `{"event":"url","cmd","q"}` (`Router.swift:12`).

`crate://` commands, all handled in `Sources/App/Router.swift`:

| Command | Params | Effect | Line |
|---|---|---|---|
| `dig` | `q=` prompt text (URL-encoded) | `state.dig(text)`, same as typing a prompt | 14 |
| `mode` | `m=` sample, chop, keys, seq, padfx, levels16 (raw value or label with spaces removed, e.g. `16lvl`) | Switch mode (`Models.swift:105`) | 16 |
| `bank` | `b=A..D` | Select bank | 20 |
| `padstyle` | `s=plain` or `records` | `PadStyle.set` (`RecordPad.swift:13`) | 22 |
| `pad` | `i=1..16` (1-based), `b=` (defaults to the current bank), `v=` velocity (default 110), `semi=` semitones | Select and hit a pad | 24 |
| `play` / `stop` | none | Toggle play if needed | 31/33 |
| `perform` | `on=0` or `1` (any value other than 0 means on) | AI PERFORM toggle | 35 |
| `flip` | none | `state.onFlip` (GPT flip) | 39 |
| `punch` | `p=0..1` | `hinge.apply(p)` | 41 |
| `fx` | `t=` an FXType raw value (repeat, crush, delay, reverb, ring, lofi, color, granular, comb, lpf, hpf, bpf, half, radio, dub), or its label with spaces removed (e.g. `beatrepeat`), or `punch`/`none`/`off` for the default chain | `state.selectFX` (`FXType.swift:6-9, 62`) | 43 |
| `fxamt` | `v=0..1` | Same path as the hinge or knob, including DROP detection | 46 |
| `latch` | `on=` | `state.fxLatched` | 49 |
| `cam` | none | `CrowdCam.shared.start()` | 51 |
| `rot` | `deg=` 90, -90, 0, or 999 (automatic) | Sets the `crateTurn` default | 53 |
| `crowdrot` | `deg=` | Sets `crateCrowdTurn` (rotation of the outer screen) | 55 |
| `import` | `path=` absolute host path to a .wav | Copy, chop and auto-flip (`AudioImport.swift:117`) | 57 |
| `project` | `cmd=` new, save, saveas or open (default save); `name=` | `ProjectStore.handle`. `open` matches the name or id case-insensitively, otherwise opens the first project (`ProjectStore.swift:355-366`) | 60 |
| `undo` / `redo` | none | Orchestrator undo/redo | 64/66 |
| `bpm` | `v=` | `setTempo` | 68 |
| `bars` | `n=` | `setBars` | 70 |
| `slice` | `b=` (default B), `i=` (1-based), `t=` seconds | Move the chop boundary before slice i | 72 |
| `rec` | `on=` | `state.setRecording` | 78 |

- **`crate://paywall` does not work.** `PaywallGate.swift:28` documents it, but Router has no `paywall` case. Nothing posts `cratePresentPaywall` (the only reference is the listener at `PaywallGate.swift:157`), and the paywall modifier isn't attached (`CrateApp.swift:28`).
- **Prompt commands (not URLs):** these are typed prompts that `dig` intercepts before building a new beat (`Orchestrator+Edit.swift:311-360`, called from `Orchestrator.swift:90`). They cover undo/redo phrases, "reset pads", "take out the X", "bpm N", "faster"/"slower", "N bars" (1, 2, 4, 8 or 16) and pad-reorder requests.

Launch arguments (`-key value` lands in UserDefaults) and other UserDefaults keys:

| Key | Effect | Cite |
|---|---|---|
| `-crateCmdFile <path>` | Enables the file command channel | `DebugCommands.swift:10` |
| `-crateDebugLog 1` | Prints `CRATE {json}` event lines to stdout and os_log (subsystem `com.shuhan.crate`, category `event`), plus an on-screen layout debug overlay | `Support.swift:27,31-45`; `RootView.swift:59` |
| `-crateDebugRecord 1` | Writes the master bus to a WAV (up to 120 s), by default `Documents/crate-debug.wav` | `Support.swift:26`; `AudioEngine.swift:28,570-580` |
| `-crateOffline 1` | Disables Jev and OpenAI; falls back to the keyword parser, templates and rule-based bass | `Support.swift:25`; `JevClient.swift:38`; `OpenAIClient.swift:34` |
| `-crateFresh 1` | Skips restoring the last project at boot | `ProjectStore.swift:138` |
| `-crateTurn <deg>` | Layout rotation override (999 = automatic) | `RootView.swift:17-18` |
| `-crateCrowdTurn <deg>` | Outer-screen rotation. A long-press on the logo also cycles it by +90° | `RootView.swift:170-171`; `LidDisplayView.swift:180-184` |
| `-crateNoPaywall 1` | **No code reads this key.** It's passed by `selftest.sh:29`, `bitrig_fx_take.py:62`, `take_v3.py:122` and the verify scripts. The paywall is off anyway (`CrateApp.swift:28`), so `take_v3.py paywall` won't show one | none |
| `-crateVerification` | Exists only inside `Sources/Transfer/Verification/check.sh:16`, which patches a temporary copy of `CrateApp` | none |
| `cratePadStyle` | Persisted pad style | `RecordPad.swift:14` |
| `crateLastProject` | Persisted last project id | `ProjectStore.swift:115` |
| `crateSeededDefaultsV3` | First-launch seeding of the demo projects | `ProjectStore.swift:157` |
| `crateBankASlots` | Legacy key, removed at startup | `Models.swift:40` |
| `crate.paywall.digCount.v1`, `crate.paywall.seenPlans.v1` | Free-DIG allowance counters | `DigAllowance.swift:6-7` |

Environment variables (pass them to the app with `SIMCTL_CHILD_<NAME>` on `simctl launch`):

| Variable | Effect | Cite |
|---|---|---|
| `CRATE_DEBUG_WAV` | Path for the debug-record WAV (used as `SIMCTL_CHILD_CRATE_DEBUG_WAV` in `bitrig_fx_take.py:60`) | `AudioEngine.swift:572` |
| `CRATE_FX_ORDER=spec` | Runs the filter before the crush (the default is crush first) | `AudioEngine.swift:29` |
| `CRATE_LIBRARY_PATH` | Overrides the library location | `Support.swift:13` |
| `CRATE_AI_BASE`, `CRATE_APP_TOKEN` | Server URL and token for AI calls (env first, then Info.plist) | `Support.swift:6-8,18-19` |
| `OPENAI_API_KEY`, `TYPESAFE_API_KEY` | Direct-call keys for local experiments only, read from env | `Support.swift:21-22` |
| `T_H`, `K_LO`, `K_HI`, `K_ETA`, `K_HSUB`, `K_MODE` | AudioAnalyzer tempo and key tuning | `AudioAnalyzer.swift:35,249,272,311,339` |
| `CRATE_OFFLINE`, `CRATE_DEBUGLOG`, `CRATE_QUICK` | Used only by the macOS harness | `tools/harness/main.swift:7-8,17-18,118` |

- The `launch` debug event still reports `hasOpenAI`/`hasJev` from the env-only keys, so it shows false when only the app token is set (`CrateApp.swift:21-23`).

## 5. `tools/`
**Self-test:**
- `selftest.sh [--offline] [--no-build]` runs the full demo-flow test on the Duo simulator.
  - Target: `UDID` (default 0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4). Output goes to `OUT` (default `/tmp/crate-selftest`) and the command file is `/tmp/crate-cmd.txt`.
  - Steps: builds (which runs `xcodegen`), installs, sets the hinge, launches with the debug flags, then drives dig → chop → house → fold/snap → keys → padfx → perform.
  - Afterwards it pulls `crate-debug.wav` out of the app container and runs `analyze.py` with `~/forkdaw/.venv/bin/python`.
  - It does **not** boot the simulator, so boot it first.
- `analyze.py <outdir>` parses the `CRATE {…}` console events, the marks and the WAV, and prints PASS/FAIL/SKIP for each check.

**macOS harnesses (not part of the app):**
- `harness/main.swift` dry-runs DIGs against the real library with MockEngine. Build and run commands are in its header (`main.swift:3-8`), and it can source `keys.env`.
- `audio-harness/{build.sh,main.swift}` tests `Sources/Audio` through the Mac speakers. It builds to `/tmp/crate-audio-harness`.
- `analyzer-harness/{build.sh,main.swift}` tests `AudioAnalyzer`. It builds to `/tmp/crate-analyzer-harness`.

**Library build (Python):** these write to `~/duo-hack/library`.
- `pipeline.py` builds the melodic-loop library.
- `scan_sources.py` scans sample packs for candidates.
- `selection.py` is the curated manifest.
- `validate.py` and `build_md.py` validate the library and write its markdown summaries.
- `oneshots_{common,classify,select,ingest,audio,finalize,build_md}.py` form the one-shot library pipeline: classify → select → ingest (resumable) → finalize → `ONESHOTS.md`.

**Video (`tools/video/`):**
- **Takes:**
  - `take_v1/v1c/v1d/v3.py` script prompt-free recordings through `-crateCmdFile`.
  - `bitrig_fx_take.py` records a hinge-FX take in Bitrig's 3D Duo (screencapture plus the debug WAV).
  - `simrec.py` wraps `simctl io recordVideo` with wall-clock JSON and can append command lines.
  - `prep_take.py` turns raw takes into edit-ready clips.
- **Edits:**
  - `assemble.py` goes from shot list to mp4.
  - `build_v1`, `build_v2_test`, `build_final`, `build_twitter`, `build_tw2`, `build_tw3` and `build_fx` produce the individual cuts.
  - Helpers: `cards.py`, `typing_intro.py`, `compose.py`, `duo_model`/`duo_anim`/`duo_compose.py` (procedural Duo renders), `hinge_overlay.py`, `frames_sheet.py`, `jitter_check`/`shake_check.py`, `vidcommon.py`.
  - `go_build.sh` is described in section 1.

**Per-module verify scripts:** each builds in an isolated temp dir, is excluded from the app target (`project.yml:36-45`) and launches its own bundle id.
- `Sources/{Crowd,Sampler,Paywall}/verify.sh`
- `Sources/{Paywall,Transfer}/Verification/check.sh`

## 6. Crashes (the two newest `.ips` files)
Both files are `~/Library/Logs/DiagnosticReports/`, on Duo-Video-3 (E82B9354), Crate 0.1, host macOS 27.0, with the build from 00:06.
- **`Crate-2026-09-30-000726.ips`:** EXC_CRASH / SIGABRT on the main thread.
  - Stack, top first: `_ReportRPCTimeout` ← `_CheckRPCError` ← `AURemoteIO::SetProperty` ← `AURemoteIO::Initialize` ← `AUAudioUnitV2Bridge allocateRenderResources` ← `AVAudioEngineGraph::Initialize` ← `-[AVAudioEngine prepare]` ← `AudioEngine.start()`.
  - That call is `engine.prepare()` at `AudioEngine.swift:181`.
- **`Crate-2026-09-30-000814.ips`:** EXC_CRASH / SIGABRT on the main thread.
  - Stack, top first: `_ReportRPCTimeout` ← `AURemoteIO::Cleanup` ← `AUAudioUnit deallocateRenderResources` ← `AVAudioIONodeImpl::GetOutputFormat` ← `-[AVAudioEngine outputNode]` ← `AudioEngine.formatLocked()` ← `AudioEngine.start()` ← `CrateApp.init()`.
  - That is `formatLocked()` reading `engine.outputNode` at `AudioEngine.swift:220`, which `CrateApp.swift:12` reaches through `try? engine.start()`.
- **Diagnosis:** this is a CoreAudio RPC timeout from the simulator's audio server, at launch, before any app logic runs. It is an abort inside CoreAudio, so `try?` can't catch it. It's an environment problem, not an app bug. I did not verify a fix; the usual one is to restart host `coreaudiod` or reboot the simulator.

## 7. Git
- Branch: `main`, level with `origin/main` after fetching (`## main...origin/main`, 0 ahead / 0 behind).
- Last 5 commits:
  - `9a6c21d` Handoff: include XHS post copy
  - `49253c1` Distribution/marketing handoff (separate from engineering)
  - `f560978` Waitlist export: personal vs work email + company domain
  - `26ae690` Waitlist: source tracking (?r= / short links) + one-tap 'you…' role after signup
  - `6faca49` Brat 30s v2 (no blur, drop on the beat, continuous audio) + Bitrig hinge-FX showcase
- Uncommitted:
  - The 5 modified files listed at the top (+38 / −18 lines).
  - Many untracked demo media and cache folders under `demo/`: `raw/`, `segments/`, `songs/`, `twitter/*/tmp`, `vo/cedar_*.wav`, shot lists and frame sheets.
- The existing `HANDOFF.md` (lines 30-50) already covers build, install, hinge and cmd-file usage; this report adds to it and corrects `-crateNoPaywall` and `crate://paywall`.