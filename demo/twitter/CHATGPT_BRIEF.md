# Brief for ChatGPT: record raw footage of CRATE in Bitrig

Your job is **raw footage only**. Record the clips below and save them. Claude does all the editing, captions and music. Don't edit, trim, add text, or speed anything up.

## What CRATE is (so the footage makes sense)
CRATE is a sampler app for the iPhone Duo (foldable). It won 1st place at the YC × Bitrig iPhone Duo hackathon.
- **Top half (lid):** a black display with BPM, a step sequencer, the waveform, and a prompt line.
- **Bottom half (deck):** 16 pads, banks A–D, and mode buttons: SAMPLE, CHOP, KEYS, SEQ, PAD FX.
- **Manual use:** you can play it by hand like an MPC. Tap pads, program the sequencer by tapping dots, drag chop lines, play KEYS.
- **AI use:** type a vibe and pads fill from the sample library.
- **Duo use:** the hinge is an FX knob (fold = filter build, snap open = DROP), and the back screen shows a light show for the crowd.

## Setup (once)
1. Open Bitrig with the crate-build project and the **iPhone Duo** simulator showing CRATE.
2. Make the Bitrig window big and put it on the largest display. Hide the left chat panel so the 3D device fills the pane.
3. Launch CRATE fresh, recording the app's own audio:
   ```
   B="$HOME/Library/Application Support/app.bitrig.bitrigapp/SimulatorHost/Devices"
   : > /tmp/crate-cmd-bitrig.txt
   SIMCTL_CHILD_CRATE_DEBUG_WAV=$HOME/crate-build/demo/raw/<clip>.wav \
   xcrun simctl --set "$B" launch --terminate-running-process 9193E59E-E5A1-449D-BF60-C48438FE33AC \
     com.shuhan.crate -crateNoPaywall 1 -crateDebugRecord 1 -crateCmdFile /tmp/crate-cmd-bitrig.txt -crateFresh 1
   ```
   Use a new `<clip>.wav` name per clip. Relaunch like this before each clip.
4. **Sending actions:** append a line to `/tmp/crate-cmd-bitrig.txt`, e.g. `echo "crate://pad?i=1&b=A" >> /tmp/crate-cmd-bitrig.txt`. You can also click and drag in Bitrig directly. Real clicks look better where noted.

Useful commands:

| What | Command |
|---|---|
| AI prompt | `crate://dig?q=french%20jazz%20piano%20sample` |
| Hit a pad (bottom row: 1 kick, 2 snare, 3 clap, 4 hat) | `crate://pad?i=1&b=A` |
| Mode | `crate://mode?m=seq` · `chop` · `keys` · `padfx` · `sample` |
| Bank | `crate://bank?b=A` (or B / C / D) |
| FX type | `crate://fx?t=lpf` |
| Tempo | `crate://bpm?v=100` |
| Play / stop | `crate://play` · `crate://stop` |

**Record:** a screen recording of only the Bitrig device pane, at 60 fps and the highest resolution, **with the cursor hidden**. Start each recording 2 s before the first action and stop 2 s after the last. Save to `~/crate-build/demo/raw/<clip>.mov` with the matching `.wav`.

## Clips

Pose buttons are on Bitrig's right-side toolbar: **Closed · Partially Open · Fully Open · Seated · Standing**. Rotate is also there. You can also click-drag the 3D device to orbit it.

| # | File | Pose / camera | Actions (in order) | Length |
|---|---|---|---|---|
| 1 | `01_ai_jazz` | **Seated** (laptop), front | Empty CRATE. Click the prompt and type **french jazz piano sample** at human speed, press Enter. Let it play 6 s. | ~12 s |
| 2 | `02_manual_pads` | **Seated**, drag-orbit slightly toward the deck | With the beat playing, **click pads by hand** on the beat: kick, snare, clap, hat (pads 1–4), then a few top-row sounds. Switch bank A → B and tap 4 chop pads. | ~12 s |
| 3 | `03_manual_seq` | **Seated**, front | Mode SEQ. **Click dots** on the lid grid to add 3 hats and remove 1 kick, and click a lane name to mute it. Then UNDO. | ~10 s |
| 4 | `04_chop` | **Fully Open**, flat | Mode CHOP, bank B. **Drag 2 slice lines** on the waveform, then click 3 slices to audition. | ~10 s |
| 5 | `05_keys` | **Standing** (tent) | Mode KEYS. Click keys to play a short melody (~8 notes). | ~8 s |
| 6 | `06_house` | **Seated** | Relaunch fresh. Type **deep house, 124**, Enter. Let it play 6 s. | ~10 s |
| 7 | `07_hinge_fx` | **Seated** | Mode PAD FX, `fx?t=lpf`. **Slowly** go **Seated → Partially Open** over about 4 s (the filter should close). Hold 1 s, then **snap back to Seated fast** (DROP). Let the DROP play 4 s. If the pose buttons jump instantly, drag the hinge instead, or run `crate://fxamt?v=0.0 … 0.95` in 0.05 steps every 0.1 s, then `v=0`. | ~12 s |
| 8 | `08_back_screen` | **Closed**, then drag-orbit to see the **back / outer screen** | House beat playing. Hold on the back-screen light show 4 s. | ~8 s |
| 9 | `09_rotate_orbit` | Any pose | Beat playing. Click **Rotate** once, then **drag-orbit** the device a slow 90–180°. Go through the poses: **Closed → Partially Open → Seated → Standing → Fully Open**, about 1.5 s each. | ~12 s |
| 10 | `10_hero` | **Seated**, 3/4 angle (drag-orbit) | Beat playing, no actions. A clean beauty shot for the end card. | ~6 s |

**Don't record:** AI PERFORM, the paywall, the left Bitrig chat panel, the desktop, or notifications. Turn on Do Not Disturb.

When you're done, list each file with its length and anything that didn't work.
