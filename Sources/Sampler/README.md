# WP7 — microphone sampling

`MicSampler(state:)` records 44.1 kHz mono 16-bit PCM WAV takes in `Documents/samples/rec-<timestamp>-<unique suffix>.wav`. `SampleRecordButton(state:sampler:)` provides hold-to-record, release-to-chop, THRESH / REGIONS 16 selection, a live input meter, elapsed seconds, and error feedback using the shared Theme.

## Lead wiring

Keep one sampler alive beside the same AppState used by the deck. For example, in the owning SwiftUI view:

```swift
@MainActor
struct SampleModePanel: View {
    let state: AppState
    @State private var sampler: MicSampler

    init(state: AppState) {
        self.state = state
        _sampler = State(initialValue: MicSampler(state: state))
    }

    var body: some View {
        SampleRecordButton(state: state, sampler: sampler)
    }
}
```

Embed that panel in the deck's SAMPLE mode. No shared UI, App, Core, Audio, project or Info.plist files are changed by this package. The app must retain its existing `NSMicrophoneUsageDescription` in Info.plist. The SDK/deployment target is iOS 27.1.

Direct calls are `sampler.startRecording()` and `await sampler.stopRecording(chop: .threshold)` (or `.regions16`). The button already manages these calls. A VoiceOver double tap toggles recording so it does not require holding a finger down.

## Behavior

- Permission is requested only on record. Releasing during the permission prompt invalidates that start request, so granting permission afterwards cannot unexpectedly start recording. Hold again once permission is granted.
- Recording uses `.playAndRecord`, `.defaultToSpeaker` and `.mixWithOthers`. Ending, cancelling, startup failure, and interruption restore `.playback` with mixing. The session is not explicitly deactivated, and this package never stops/restarts the performance engine. The existing engine handles route/configuration changes.
- Interruption uses iOS 27's `didBecomeInactiveNotification`. Leaving the view or backgrounding cancels the pending/active recording without loading incomplete audio. Already-started chop processing is allowed to finish. Takes are retained on disk, including failed-load or cancelled takes.
- A take is limited to 120 seconds, then automatically chopped with the selected mode. WAVs shorter than 80 ms are rejected. Permission, start/save/read/load errors appear inline and in the ERR log.
- WAV analysis runs off the main actor with 10 ms RMS windows and bounded buffer memory. THRESH detects rising edges above an adaptive noise envelope and absolute floor, at least 80 ms apart, with at most 16 slices. The first slice starts at zero and the last ends at the file duration; silence/sustained tones produce a single threshold slice. REGIONS 16 divides the entire take equally into sixteen slices. Optional threshold-triggered record arming is not implemented.
- Slices become `REC 01` … `REC 16`, category `.chop`, root note 60. **Bank D is replaced** using the engine's atomic `loadBank` API. AppState is updated only after a successful load; all other banks are preserved. The UI selects bank D/pad 1. A failed engine load retains the previous UI bank contents.
- Success logs `SAMPLE` with slice count and duration; debug events are `sample_rec { sec }` and `sample_chop { slices }`. Debug events respect the existing `-crateDebugLog 1` flag.

## Verification

Run from the repo root:

```sh
xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios27.1-simulator -swift-version 5 \
  Sources/Core/*.swift Sources/UI/Theme.swift Sources/Sampler/*.swift
bash Sources/Sampler/verify.sh
```

The script additionally typechecks DEBUG previews and runs host-only tests for transient spacing, complete slice coverage, the slice cap, silence, sustained signals, invalid input, real mono 44.1 kHz/16-bit WAV decoding (including a partial final window), and missing files. It never uses the microphone or simulator.

Passed on Xcode 27.1. Live permission, recording/playback coexistence, interruption routing, hold gesture, and audible chops still need the lead's device/simulator QA when that device is free.
