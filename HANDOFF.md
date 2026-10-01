# CRATE: engineering handoff

Last updated 2026-09-30, overnight, by the engineering agent. You are the **engineering agent**.
Marketing and distribution belong to a separate agent (`docs/DISTRIBUTION_HANDOFF.md`). Don't post, email or DM anything.
**Detailed code maps (sampling UX tap flows + confusion points, layout decision tree, proxy/infra, tooling + all crate:// commands): `docs/CODE_MAPS.md`** (written at 71d4814; the layout section predates the iPhone/iPad work below).
The old hackathon-day handoff is in `docs/archive/HACKATHON_HANDOFF.md` and is history only. `docs/EAR-PLAN.md` is another session's research plan for a taste model; not engineering work yet.

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

## TestFlight (live since 2026-09-30)
- App Store Connect app **"CRATE: AI Sampler"** (Apple ID 6818032563), bundle **com.shuhan.crate**, team **9R86FG9KG8** (Shuhan Zhang). Xcode on this Mac is signed in to that team.
- **Public link: https://testflight.apple.com/join/NTU9XppA** (external group "Public", open to anyone). Every new *version* needs Beta App Review; later builds of an approved version usually don't.
- Internal group "Team" = Steven (account holder) with automatic distribution: every upload reaches his TestFlight app after processing, no review. On 9/30 Steven had every other App Store Connect user removed; the team is just him.
- Upload a build: `TEAM_ID=9R86FG9KG8 tools/testflight.sh` (release Xcode 27.0, iPhone/iPad build; timestamp build number). Then add the build to "Public" (TestFlight → Public → Builds → +, "What to Test", Submit for Review).
- The upload signs in with the Xcode account, which **fails while the Mac is locked** ("missing Xcode-Token"; `git push` hangs the same way). Re-run with `BUILD_NUMBER=<n>` to upload an existing archive.
- Builds (all version 0.1): **202609302158** = pre-redesign UI, waiting for Beta App Review since 22:15. **202609302329** = the redesign (uploaded 23:55). **202609302356** = redesign + the SAMPLE tap fix below.
- Test information is filled in (description, feedback email, contact phone, review notes, no sign-in). Privacy policy: https://crateduo.vercel.app/privacy (`site/privacy.html`, deployed with `cd site && vercel deploy --prod --yes`).

## Sampling redesign (built 9/30, on main)
- Deck: **SAMPLE · KEYS · FX** only. SAMPLE arms (pads blink; hold a pad to record the mic into it; silence trimmed; one UNDO). KEYS toggles. Hold FX and tap a pad to pick an effect (quick tap latches one pick). The fader / phone slider is the FX amount everywhere (the hinge on a Duo); pull it from high to zero for the DROP.
- Lid: one **pad line** (bank tag, name, ‹ › next similar library sound, EDIT). **EDIT** = the sound big, drag its two edges (a song slice shows in context; its edges move the neighbours). Steven rejected deck knobs ("horrible on touch") and then trim strips ("too complex"): keep editing to dragging the edges.
- **＋** next to the prompt imports a song (16 chops on bank D, chop 1 auditions, FLIP IT glows, no auto-flip) or a short sound (onto the selected pad). Drag-and-drop does the same.
- **● REC** from stop counts in one bar (clicks via `CountIn`), then plays + records; tap again to stop recording. Takes, imports, swaps, trims and REC passes are each one UNDO step.
- A tap shorter than 0.2 s while SAMPLE is armed records nothing, keeps the pad and stays armed ("too short · hold the pad while you record"). The editor opens only when a take landed. A hold past the 120 s recorder cap still lands on the pad at lift.
- Take placement (trim → pad → editor → UNDO/REDO) was checked with `crate://take?pad=A3&path=<wav>` on the iPhone 17 Pro (iOS 26.5) sim: a 1.8 s file with 0.6 s of lead-in trimmed to 0.59–1.16 s. Not verified: the microphone capture itself on a phone. The Mac's CoreAudio is wedged by an earlier simulator mic session (`afplay` hangs; sims abort in `AURemoteIO` unless launched with `-crateSilentAudio 1`). `sudo killall coreaudiod` fixes it and needs Steven's password. Everything else was driven by taps on that sim and checked on the Duo sim.

## Still waiting on Steven
1. **New OpenAI + Jev keys** are in `~/duo-hack/.secrets/keys.new.env`; Vercel still runs the old (working) keys because the agent can't write secrets to Vercel. To switch, in `~/crate-build/site`:
   ```
   set -a; source ~/duo-hack/.secrets/keys.new.env; set +a
   printf %s "$OPENAI_API_KEY"   | vercel env add OPENAI_API_KEY production --sensitive --force
   printf %s "$TYPESAFE_API_KEY" | vercel env add TYPESAFE_API_KEY production --sensitive --force
   vercel deploy --prod --yes
   ```
   Then move the two lines into `keys.env`, delete `keys.new.env`, and revoke the old keys. The ElevenLabs key from 9/26 still needs rotating too.

## Repo, build, run
- Repo: `~/crate-build` → github `Shuhan-Zhang/crate-duo`, branch `main`. Commit + push after each step.
- SwiftUI and XcodeGen. **Deployment target iOS 26.0** (`Sources/Audio/AudioCompat.swift` wraps the iOS 27-only AVAudioEngine calls; 27.1 was Duo-only, so a 27.1 target couldn't install on any iPhone or iPad).
- Two Xcodes, both build the app:
  - `~/Downloads/Xcode.app`: **Xcode 27.1 beta** (27A9269), the only one with the Duo SDK. Use it for the Duo and day-to-day work.
  - `/Applications/Xcode.app`: **Xcode 27.0 release** (27A266a). Duo APIs compile out via `NO_DUO_SDK` (set in `project.yml` for the 27.0 SDKs), so the result is an iPhone/iPad-only app that App Store review accepts. On a Duo it runs with the phone layout and no hinge FX.
  ```
  export DEVELOPER_DIR=~/Downloads/Xcode.app/Contents/Developer
  xcodegen generate
  xcodebuild -project Crate.xcodeproj -scheme Crate -destination "generic/platform=iOS Simulator" -derivedDataPath build/dd build
  xcrun simctl install <UDID> build/dd/Build/Products/Debug-iphonesimulator/Crate.app   # bundle id com.shuhan.crate
  ```
- Saved and demo projects store library sounds as `~lib/<relative>` (old absolute paths are remapped at load). The bundled demos used to point at this Mac's disk, which only worked in simulators.
- Simulators (keep at most 2 booted; first boot of a new sim spikes the load for minutes):

  | Simulator | UDID | Runtime |
  |---|---|---|
  | Steven's Duo sim ("iPhone Duo") | `0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4` | 27.1 |
  | Test/video Duo sim ("Duo-Video-3") | `E82B9354-4493-4C8B-A6B8-52BA5EE92C7F` | 27.1 |
  | iPhone 18 Pro | `825C8398-869F-4650-9E7A-4BE00AC51B60` | 27.0 |
  | iPad Pro 13" (M5) | `145D9367-05C9-47FA-AEB0-DDA8CCACA2B1` | 27.0 |
  | Bitrig's set: iPhone Duo / iPad Pro | `9193E59E-E5A1-449D-BF60-C48438FE33AC` / `3058DE90-F371-4E2C-AED1-88BEB8818D37` | 27.1 / 27.0 |

  Bitrig's set lives at `"$HOME/Library/Application Support/app.bitrig.bitrigapp/SimulatorHost/Devices"`; reach it with `xcrun simctl --set "$B" …`.
- **Xcode 27.1 has no Simulator.app; it's `~/Downloads/Xcode.app/Contents/Applications/DeviceHub.app`.** A Duo sim booted headless (`simctl boot`) only has its outer display; open DeviceHub once so the inner display exists. `simctl io <udid> screenshot` defaults to the outer display; for the inner one pass its UUID: `ID=$(xcrun simctl io $U enumerate | awk '/UUID:/{u=$2} /Default width: 2007/{print u}' | head -1); xcrun simctl io $U screenshot --display="$ID" out.png`.
- Hinge control:
  - Default set: `hinge -d <UDID> <deg>`, `hinge -d <UDID> sweep a b secs`, `hinge -d <UDID> get`.
  - Bitrig's set: `xcrun simctl --set "$B" spawn <UDID> ~/.cache/hinge/hinge_helper-* set|sweep`.
  - The Duo moves the app to the outer screen below about 55°.
- **Debug command channel**:
  - Launch with `-crateCmdFile /tmp/x.txt -crateDebugLog 1 [-crateFresh 1] [-crateDebugRecord 1] [-crateSilentAudio 1]`. Append `crate://…` lines to the file to drive the app.
  - Commands: `dig?q=`, `mode?m=`, `bank`, `pad`, `play`, `stop`, `perform`, `flip`, `punch`, `fx?t=`, `fxamt`, `latch`, `rot`, `crowdrot`, `import`, `project?cmd=new|save|saveas|open&name=`, `rec`, `padstyle`, `undo`, `redo`, `bpm?v=`, `bars?n=`, `slice?b=&i=&t=`, **`orient?o=landscape|portrait`** (iPhone only; iPadOS refuses programmatic rotation in windowed mode). Redesign: `arm?on=1`, `editor?open=1`, `swap?dir=1`, `trim?s=&e=`, `recpress`, `fxhold?on=1`, `fxpick?i=`, `take?pad=A3&path=`.
  - Debug events worth grepping: `layout` (size, duo, window insets), `device`, `jev_plan`, `gpt`, `engine_start` (`silent`).
  - `SIMCTL_CHILD_CRATE_DEBUG_WAV=/path.wav` records the master bus. Example script: `tools/video/bitrig_fx_take.py`. `-crateNoPaywall` does nothing (paywall is off anyway).
- **Known sim issue: launch abort in `AURemoteIO::Initialize` / `Cleanup` → `_ReportRPCTimeout`** (simulator CoreAudio, before any app code). Causes seen: several sims booted at once, a load spike, and **the Mac lid closed** (clamshell: every sim crashed at launch overnight, even alone). For layout work launch with **`-crateSilentAudio 1`**: the engine runs in offline manual-rendering mode with no audio hardware (dev only; normal launches are unchanged). For audio work, open the lid / fix the output device, shut down extra sims and reboot the one you use. **Ask Steven before shutting down his sims or Bitrig's.**

## Device layouts (RootView)
- **Duo** = a `.division` fold is present, a hinge event arrived, or a Duo simulator; remembered per device model (`crateDuoMachine`). Duo branches are unchanged: laptop / book / flat / counter-rotated, `CompactView` on the outer screen.
- **iPhone**: `PhoneLidView` (project chip, LOOP bar, hero, the mode's main area, result line, `›` prompt + chips) over `DeckView(phone: true)` (mode row, pads, BANK · REC PLAY STOP · DIG; no LEVEL fader). Lid ≈ 40 % in portrait, side by side in landscape (lid 44 %). Padded by the **window's** safe-area insets (`DeviceInfo.windowEdgeInsets`; the root ignores the safe area, so its GeometryProxy reports zero). The step grid scrolls when a beat has more lanes than fit.
- **iPad** (regular width): the flat split with a 1 pt hairline, deck kept above the home indicator; the step grid spreads out on the tall lid. Compact-width iPad windows get the phone layout. No counter-rotation outside the Duo, which fixed the Stage Manager 90° bug.
- The Duo scene hooks (`sceneAccessory` camera/external crowd screens, `onHingeChange`) live in `DuoSceneHooks`, gated on iOS 27.1 and the SDK. The external-display crowd view is Duo-only for now.
- The FX amount is the deck fader (iPad/Duo) or the slider under the pads (iPhone). The old PAD FX page with its knob and the old SAMPLE panel are off the touch deck; Shift-Tab on a hardware keyboard cycles SEQ / KEYS only. The long-press crowd rotation only works on the Duo.

## Verified overnight (2026-09-30)
- Proxy runtime test on the Duo sim: `jev_plan` via proxy 524 ms (source jev), `gpt` ok in 5.3 s ("NUJ DILLA POCKET"). On the iPad: Jev 264–309 ms; GPT 5.9 s, once timed out at the 8 s arrange limit on a cold start.
- Duo inner (laptop pose) and outer screens unchanged; iPhone 18 Pro portrait + landscape, all modes (SEQ, KEYS, PAD FX, SAMPLE, CHOP); iPad Pro 13" portrait. Screenshots were checked by eye.
- The Release archive builds with Xcode 27.0: `DRY_RUN=1 tools/testflight.sh` → 329 MB app (min iOS is now 26.0).
- **Not verified:** iPad landscape, iPad Split View / Stage Manager windows (no scriptable rotation or resize in DeviceHub yet; the landscape path is the Duo's existing flat-wide `book` layout), hold-to-record on the mic (sims had no audio), real devices.

## App Store details
- iPad in the device family, `Resources/PrivacyInfo.xcprivacy` (UserDefaults CA92.1, boot time 35F9.1 for `mach_absolute_time`, prompts as user content for app functionality, no tracking), `ITSAppUsesNonExemptEncryption = false`, single 1024 icon, all 4 orientations (needed for iPad multitasking). RevenueCat ships its own privacy manifest. `MARKETING_VERSION` is 0.1.
- `tools/testflight.sh`: xcodegen → Release archive → export with `destination: upload`. Default `XCODE=release` (27.0, App Store eligible); `XCODE=beta` for the full Duo build (Apple takes beta-SDK uploads for TestFlight only when it enables that SDK, never for review). `DRY_RUN=1`, `ARCHIVE_ONLY=1`, optional App Store Connect API key env vars.
- For Duo launch day: build with Xcode 27.1 RC/GM once Apple ships it; one binary then covers Duo, iPhone and iPad.

## Later / backlog
- **The sample library is commercial packs** (Jazz Hop合集, LofiHiphop合集, Cymatics, Golden Trap). OK for a private beta per Steven; swap for licensed sounds before a public launch. It's bundled from an absolute path (`/Users/shuhanzhang/duo-hack/library`, 308 MB), so archives only build on this Mac.
- The proxy token ships inside the app, so it's a speed bump, not auth. Later: App Attest/DeviceCheck plus OpenAI spend caps. Rate limit is per serverless instance.
- GPT arrange budget is 14 s (16 s for a flip); a cold start on cellular can still miss it and falls back to the template silently.
- An imported song's chop session isn't saved with the project: after a relaunch, FLIP IT on those chops makes a new beat instead.
- Marketing asked for a **"share your beat" 15 s vertical video export** (brat end card + "made with crate") and **in-app analytics**: prompts, sessions, D2/D7 retention, shares.

## Security rules (non-negotiable)
- Keys live only in `~/duo-hack/.secrets/` (`keys.env`, and `keys.new.env` until the swap above) and the gitignored `Config/Secrets.xcconfig`. Never print, echo or commit them. Never put them back in Info.plist.
- Never send keys to jevapi.org or tokenra.io; they are lookalike phishing hosts. The real host is api.typesafe.ai.
- Don't search other projects' env files for keys. Don't delete `~/Downloads/Omnisphere`.
