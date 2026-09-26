# WP13: audio transfer — teammate 2

Drop audio from Files onto a pad. The provider's temporary file is copied into
`Documents/imported/` before its callback returns. Files up to two seconds load
on the selected pad; longer files offer **CHOP 16 into Bank D** or **Load on pad**.
Imports are limited to 100 MB and five minutes. Other pads are preserved for a
single-pad import. All 16 decoded slices must be accepted before reporting chop
success. Dismissing the long-file choice removes the unused copy.

**BOUNCE** starts playback if needed, waits for the next bar, and captures four
bars from the existing master tap. It counts audio frames, finalizes a stereo
16-bit WAV, then exposes a draggable file chip and ShareLink. **CANCEL BOUNCE**,
stopped playback, tempo changes, or discontinuous audio invalidate the capture
and remove partial output. Only one capture can own the tap at a time.

## Integration

- `AudioEngine` exposes a callback on its existing tap; no second tap is installed.
- `MasterBounce` owns alignment, sample counting, file writing and completion.
- `AudioEngine+Bounce` provides an async API with task cancellation.
- `PadGridView` supplies drop targeting and the long-file choice.
- `DeckView` places BounceControl in the deck footer.
- Includes a small no-RevenueCat-SDK fallback type fix so isolated simulator
  builds compile. Live purchase behavior is unchanged.

This branch overlaps the WP13 portion of PR #3 (`teamate1`). Resolve that overlap
when integrating; these are alternative implementations of the same transfer
feature. Teammate 2's earlier crowd/Now Playing work is already merged in main.

## Reproduce simulator verification

Use Xcode 27.1 and a booted iPhone Duo simulator:

```sh
CRATE_VERIFY_DEVICE=<simulator-UDID> bash Sources/Transfer/Verification/check.sh
```

The script builds a separate `com.shuhan.crate.teamate2` app directly with Swift,
without altering the shared Xcode project or using API keys. It launches offline
with paywall bypassed, injects synthetic audio fixtures, and reports PASS/FAIL.
The verification source is not part of production compilation.

Verified on the iPhone Duo iOS 27.1 simulator:

- NSItemProvider file delivery, copied-file lifetime, unique import destinations,
  invalid-file rejection/cleanup, preservation of a neighboring pad, root-note
  assignment, and all 16 slices loaded by the real audio engine.
- Reproduced the original export timing failure: 10.8 seconds at 89 BPM instead
  of 960/89 seconds. Fixed output: 10.7865208333 seconds, nonzero peak 0.1423.
- Concurrent capture rejection, task cancellation, transport stop, and tempo
  change. No partial WAV survives these failures.

Cross-app Split View drag gestures still require manual verification; provider
and engine checks do not establish that the operating system delivers a drag
from Files to the intended visible pad.

Live UI check on the final build: entered `j dilla drums`, generated the offline
kit at 89 BPM, pressed BOUNCE, observed the exported `J-DILLA-35846603.wav` chip,
and opened its native share sheet (Audio Recording, 2.1 MB). The sheet offered
Copy and Save to Files. Saving into Files and cross-app dragging were not
verified by the UI automation.
