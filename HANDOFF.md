# CRATE: engineering handoff

Last updated 2026-09-30 by the previous engineering agent, whose context ran out. You are the **engineering agent**.
Marketing and distribution belong to a separate agent (`docs/DISTRIBUTION_HANDOFF.md`). Don't post, email or DM anything.
The old hackathon-day handoff is in `docs/archive/HACKATHON_HANDOFF.md` and is history only.

## What CRATE is
CRATE is an AI sampler for the iPhone Duo, Apple's foldable. It won **1st place at the YC × Bitrig iPhone Duo hackathon** on 2026-09-26.
- You type a vibe ("french jazz piano sample"). Jev (TypeSafe) parses it in about 0.3 s, and the pads fill from a sample library.
- GPT (gpt-6-luna for arranging, gpt-6-sol for flips) writes the variations.
- You play 16 pads by hand.
- The **hinge is an FX knob**: folding builds tension and snapping open is the drop.
- The back screen shows a crowd view.

The founder is Steven (the user; X handle @stvnzhangshuhan). He is preparing for a **YC interview** and wants real users.
The Duo ships Oct 23, 2026. The goal is a TestFlight build for **iPhone + iPad** as soon as possible, then App Store on Duo launch day.

## How Steven works (important)
- **"Simplicity is key. The fewer buttons, the less mode, the simpler it is, the better."** This applies to every UI decision.
- He is impatient with slow progress. Keep replies short, show the result, and don't write essays.
- Before any big UI rebuild, propose it in a few bullets or a mockup. Build once he approves.
- "The AI part is actually great already." Don't rework the AI flow.

## Repo, build, run
- Repo: `~/crate-build` → github `Shuhan-Zhang/crate-duo`, branch `main`.
- SwiftUI and XcodeGen. Xcode 27.1 lives at `~/Downloads/Xcode.app`; it is the only version with the Duo SDK:
  ```
  export DEVELOPER_DIR=~/Downloads/Xcode.app/Contents/Developer
  xcodegen generate
  xcodebuild -project Crate.xcodeproj -scheme Crate -destination "generic/platform=iOS Simulator" -derivedDataPath build/dd build
  xcrun simctl install <UDID> build/dd/Build/Products/Debug-iphonesimulator/Crate.app   # bundle id com.shuhan.crate
  ```
- Simulators:

  | Simulator | UDID / name |
  |---|---|
  | Steven's Duo sim | `0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4` |
  | Test/video Duo sim | `E82B9354-4493-4C8B-A6B8-52BA5EE92C7F` ("Duo-Video-3") |
  | iPhone 17 Pro | `46B2AB32-0CE8-434E-9037-5C66CCB0A38A` |
  | iPad Pro 13" | `01F69029-E71F-43A3-B02B-8C22F009EE75` |
  | Bitrig's own set: iPhone Duo | `9193E59E-E5A1-449D-BF60-C48438FE33AC` |
  | Bitrig's own set: iPad Pro | `3058DE90-…` |

  Bitrig's set lives at `"$HOME/Library/Application Support/app.bitrig.bitrigapp/SimulatorHost/Devices"`; reach it with `xcrun simctl --set "$B" …`.
- Hinge control:
  - Default set: `hinge -d <UDID> <deg>`, `hinge -d <UDID> sweep a b secs`, `hinge -d <UDID> get`.
  - Bitrig's set: `xcrun simctl --set "$B" spawn <UDID> ~/.cache/hinge/hinge_helper-* set|sweep`.
  - The Duo moves the app to the outer screen below about 55°.
- **Debug command channel**:
  - Launch with `-crateCmdFile /tmp/x.txt -crateNoPaywall 1 -crateDebugLog 1 [-crateFresh 1] [-crateDebugRecord 1]`. Append `crate://…` lines to the file to drive the app.
  - Commands: `dig?q=`, `mode?m=`, `bank`, `pad`, `play`, `stop`, `perform`, `flip`, `punch`, `fx?t=`, `fxamt`, `latch`, `rot`, `crowdrot`, `import`, `project?cmd=new|save|saveas|open&name=`, `rec`, `padstyle`, `undo`, `redo`, `bpm?v=`, `bars?n=`, `slice?b=&i=&t=`.
  - `SIMCTL_CHILD_CRATE_DEBUG_WAV=/path.wav` records the master bus. Example script: `tools/video/bitrig_fx_take.py`.
- **Known sim issue:** the app sometimes aborts at launch in `AURemoteIO::Initialize` → `_ReportRPCTimeout` (simulator CoreAudio). It happens when several sims are booted, including Bitrig's. The fix is to shut down the extra sims and reboot the one you use. It is not an app bug. **Ask Steven before shutting down his sims or Bitrig's**, because he may be using them.

## State right now (uncommitted! commit this first)
Steven asked: "just use the current sample pack. let's code up the iphone and ipad for tonight. and yes move the ai key to a server."

| Done | Where |
|---|---|
| AI keys are off the device. The app calls the proxy `https://crateduo.vercel.app/api/ai/{openai,jev}` with the header `x-crate-token` | `site/api/ai/openai.js`, `site/api/ai/jev.js` (**untracked**), `Sources/AI/OpenAIClient.swift`, `Sources/AI/JevClient.swift`, `Sources/Core/Support.swift` (AppConfig.aiBase/appToken) |
| The proxy is deployed and tested: no token → 401; OpenAI works (~4 s); bad model → 400; Jev reachable | Vercel project "crate" (team simtra). Env vars: OPENAI_API_KEY, TYPESAFE_API_KEY, CRATE_APP_TOKEN. Deploy with `cd site && vercel deploy --prod --yes` |
| Proxy guards: model allowlist gpt-6-luna/gpt-6-sol, 20k-char input cap; best-effort per-IP rate limit (in-memory, so weak); `max_output_tokens` 4000 | same files |
| Info.plist now carries only `CRATE_APP_TOKEN` and `REVENUECAT_API_KEY`. `Config/Secrets.xcconfig` (gitignored) holds only those two. OpenAI/TypeSafe keys can still come from env vars, for local experiments only | `Resources/Info.plist` |
| Sample library bundled into the app (~300 MB of one-shots and loops). `libraryURL` resolves in order: `CRATE_LIBRARY_PATH` override → bundle `library/` → dev Mac path | `project.yml` folder resource `/Users/shuhanzhang/duo-hack/library`; **absolute path, so it only builds on this Mac** |
| iPad enabled: `TARGETED_DEVICE_FAMILY: "1,2"` | `project.yml` |
| Build succeeded, and the bundle was grepped: no OpenAI/TypeSafe/ElevenLabs key values inside | — |

**Not done:**
1. **Runtime test through the proxy.** Launch on a Duo sim, `dig`, and confirm the `jev_plan` / `gpt` events in the debug log. The last attempt hit the CoreAudio crash above.
2. **A real iPhone layout.** `Sources/App/RootView.swift` treats any compact size class as the Duo *outer screen* and shows `CompactView`, the mini UI. A normal iPhone in portrait would therefore get the wrong UI. Plan:
   - Detect the Duo. Candidates: a fold region present (`reservedRegions(.division)`), a first `onHingeChange` event (persist a flag), or, in the sim, `SIMULATOR_MODEL_IDENTIFIER` / `SIMULATOR_DEVICE_NAME` containing "Duo".
   - Duo + compact → `CompactView`, as today.
   - iPhone portrait → lid stacked over deck.
   - iPhone landscape → side by side.
   - iPad → the existing flat laptop/book logic.
   - Non-hinge devices use the PAD FX slider instead of the hinge.
3. **Check the iPad layout** in portrait and landscape on the iPad Pro 13" sim. Info.plist probably needs `UISupportedInterfaceOrientations~ipad` (all 4) or `UIRequiresFullScreen`, otherwise App Store validation complains.
4. **Commit and push**: `site/api/ai/`, the Swift/plist/project.yml changes, this file, and the archive move. Don't commit `demo/` media junk; it is mostly untracked.

## Next big task: sampling UX redesign (propose first, then build)
Steven's words: "the UI right now for selecting a sample and importing, and then how to record and stuff, is a little confusing. Just rethink it: really try to match teenage engineering or MPC on this or, even better, reduce the number of clicks and make it really, really intuitive… improve the experience of sampling, chopping, recording, and editing." Then: "The fewer buttons, the less mode, the simpler it is, the better."

How to approach it:
1. Map today's flows and count taps for each: import a song → play a chop; mic record → pad; swap a pad's sound; move a chop slice; edit sequencer steps; undo; BPM/bars; FX.
   - Relevant files: `Sources/UI/{DeckView,DeckControls,LidDisplayView,LidPanels,PadGridView,PromptBar,KeysView,PadFXView}.swift`, `Sources/Transfer/AudioImport.swift`, `Sources/Sampler/MicSampler.swift`, `Sources/AI/Orchestrator+Edit.swift`.
   - Background: `research-mpc-te.md` covers the MPC Sample and TE KO II workflow.
2. Direction to pitch (MPC Sample / KO II feel):
   - **Hold a pad = record into it.** Mic, or the imported song if one is loaded.
   - **Drop or import a song = auto-chop it across the pads.** No separate chop mode.
   - **Tap a pad = select and play it.** The lid always shows the selected pad's waveform, with draggable slice or trim points.
   - **One REC button** records the pattern live, quantized.
   - Keep the sequencer tap-to-toggle that already exists; undo/redo stays prominent.
   - Remove modes rather than adding them.
3. Show Steven 3–5 bullets or a quick mockup, get a yes, then build and verify on the sim with screenshots.

## Already built this session (committed)
- Undo/redo (`EditHistory`), BPM/bars editing, tap-to-edit sequencer, prompt-based sound removal. Files: `Orchestrator+Edit.swift`, `LidPanels.swift`, `LidDisplayView.swift`.
- Draggable chop slices for banks B and D. The playing pad is highlighted on the sequencer. A "BAR n/N" page marker with auto-flip. An AI status pill.
- Kick/snare/clap/hat default on the bottom row at every launch (`Models.swift` BankA.defaultSlots). The AI can reorder pads (`Orchestrator+Reorder.swift`).
- Default projects FRENCH JAZZ / HIP HOP / HOUSE (`Resources/DefaultProjects`, `ProjectStore.swift` seedDefaults V3).
- Hinge FX tuned so the full effect lands at a 65° fold (`HingeFX.swift`).
- The paywall is removed from the UI; the code is kept (`Sources/Paywall`, see `CrateApp.swift`).
- Waitlist site plus private Blob signups: `site/`. Export with `cd site && node waitlist-export.mjs [--csv]`.

## Later / backlog
- TestFlight needs an Apple Developer account. Steven hasn't answered whether he has one; ask him.
- **The sample library is commercial packs** (Jazz Hop合集, LofiHiphop合集, Cymatics, Golden Trap). That's OK for a private beta per Steven, but it must be swapped for licensed sounds before a public launch.
- The proxy token ships inside the app, so it is a speed bump, not auth. Later: App Attest/DeviceCheck plus OpenAI spend caps.
- Marketing asked for a **"share your beat" 15 s vertical video export** (brat end card + "made with crate") and **in-app analytics**: prompts, sessions, D2/D7 retention, shares.

## Security rules (non-negotiable)
- Keys live only in `~/duo-hack/.secrets/keys.env` and the gitignored `Config/Secrets.xcconfig`. Never print, echo or commit them. Never put them back in Info.plist.
- Never send keys to jevapi.org or tokenra.io; they are lookalike phishing hosts. The real host is api.typesafe.ai.
- Don't search other projects' env files for keys. Don't delete `~/Downloads/Omnisphere`.
- The ElevenLabs key was pasted in chat on 9/26 and still needs rotating. Remind Steven.
