# Teammate 1: WP8 keyboard + WP13 audio transfer

Implemented against the current HANDOFF, including the 12:23 wider-key update. Integration is already wired into RootView, PadGridView and LidDisplayView; the project automatically includes the added Swift files.

## Keyboard

- Pads: `1 2 3 4` = 13–16; `Q W E R` = 9–12; `A S D F` = 5–8; `Z X C V` = 1–4. Held visuals and shortcut legends are shared with the touch UI. Repeats are ignored.
- 16 LVL: the same grid plays the selected pad at −7…+8 semitones.
- KEYS: `A W S E D F T G Y H U J K O L P ; '` = C3…F4, shifted by the octave setting. Scale lock matches the touch keyboard. `Z/X` changes octave; `C/V` changes velocity.
- The piano displays eight white keys and five black keys across the full deck width, with mode/octave/scale controls and transport/DIG in a slim row. The original extended hardware map is preserved: holding a note above the visible high C temporarily shows the upper octave and its matching legends.
- Space = play/stop; Return = REC; Tab = next bank; Shift+Tab = next mode; `/` = DIG prompt; Escape = leave prompt. Text editing suppresses music shortcuts. Key-up uses the original pad, not the bank selected later. Focus loss/app deactivation clears held notes.
- Enable **Capture Keyboard** in Device Hub for physical keyboard input.

## Import

Drop one local audio file onto a pad. Files are copied into `Documents/imported/` while the item-provider URL is valid (with security-scoped access when supplied). The original file is never moved. Supported formats are those AVAudioFile can decode; unreadable/non-audio files are rejected. Limit: 100 MB / five minutes to bound sampler memory use.

Audio up to two seconds replaces that pad while preserving the other bank sounds. Longer files offer **Use on this pad**, **CHOP 16 → BANK D (replace bank)**, or Cancel. CHOP 16 creates contiguous equal slices over the full file. Cancel removes the uncommitted copy. The UI/log updates only after checking the engine accepted the replacement.

The drop modifier covers the pad grid and maps the drop location to its MPC pad index, including when a transparent multi-touch surface is layered over the pad cells. The Files/Split View gesture still needs manual confirmation (see validation).

## Bounce and export

Start playback, then select **BOUNCE 4 BARS** in the lid. Capture starts at the next bar boundary and records four bars at the starting BPM into `Documents/bounces/`. The finished chip exports a WAV through a Transferable FileRepresentation; the adjacent ShareLink offers the system share sheet.

**Lead/audio-owner integration note:** AudioEngine has a small, lock-protected `attachMasterCapture` / `detachMasterCapture` hook. It forwards the buffer and timestamp from the existing main-mixer tap. No second tap or onBar replacement is installed, so level metering, debug recording, and AI PERFORM retain their callbacks. Audio/ alone still has no dependency on Transfer/.

Tap buffers are copied before the callback returns; file writes run on a separate serial queue. The first sample aligns with the next bar, then an exact sample count determines the duration (avoids cumulative host-clock drift). Only a finalized file is published. Stop, tempo changes, discontinuous sample time, explicit cancellation, and timeout discard partial recordings. Starting a second capture while one owns the hook is rejected. Route/device interruption should still be checked on hardware.

A small no-SDK fallback type in PaywallGate also fixes the latest upstream custom paywall's `Never.localizedPriceString` compile error when RevenueCat is absent. The configured RevenueCat path is unchanged.

## Reproduce validation

```sh
CRATE_VERIFY_DEVICE=<booted-iOS-27.1-simulator-UDID> \
  bash Sources/Transfer/Verification/check.sh
```

This compiles all app Swift sources directly into a temporary simulator app with a separate bundle ID (`com.shuhan.crate.teamate1`). It does not edit project.yml or use the shared Xcode build. No keys are copied; launch is offline with the paywall disabled. Build files are cleaned up after the run. Synthetic fixtures and `Documents/teamate1-checks.txt` remain inside the verification app's container.

The script tests actual source code, a spy engine for keyboard events, an NSItemProvider file delivery, and the real AudioEngine master tap. The RevenueCat SDK is not linked in this isolated check.

Verified on the iOS 27.1 Duo simulator:

- All-app compile/link/launch.
- All 16 pad mappings, repeat suppression, key-up handling, multi-note release, 16 LVL, scale snapping, octave/velocity controls, prompt suppression, transport/record/bank/mode shortcuts.
- Valid/invalid audio imports, unique owned copies, preservation of untouched bank sounds, 16 contiguous chops, invalid-copy cleanup, and copying from an NSItemProvider before its callback returns.
- Real four-bar WAV at 89 BPM: **10.786520833 seconds**, non-silent peak **0.1423**; cancellation does not publish a partial file.
- Interactive `/` → prompt typing → Return, Escape → Tab returns to bank switching, bank switching, piano note readout, and the full-width one-octave layout.
- Interactive four-bar bounce produces the WAV chip; ShareLink opens a system sheet with Copy / Save to Files.

**Not verified:** an actual Files → CRATE drop in Split View, a drag from CRATE into another app, or physical-device audio interruptions. Native automation returned `noWindowsAvailable` for coordinate click/drag calls even though accessibility clicks and keyboard events worked. The provider/import path passes independently; this does not establish the end-to-end drag gesture.

Manual final check: put Files beside CRATE, drag a short WAV onto an occupied pad and verify its neighbors survive; drag a >2-second WAV and try both import choices; then drag a completed bounce back into Files and open the saved WAV.
