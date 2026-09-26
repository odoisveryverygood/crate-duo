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
`CrowdStageView(state: AppState)`: the audience-facing visual shown on the Duo's OUTER screen (1398×2034 px portrait panel) while the performer plays inside. Black background, TE palette (orange #FA5B1C, blue #5B8DEF, ochre #E0A92E, text #F6F4F4), fonts `Doto-Black` / `SpaceMono-Bold`. Content: CRATE wordmark; the current `state.styleLabel` × `state.sampleLabel` in huge type; a 4×4 dot matrix that flashes the pad being hit (`state.lastHitPad` / `lastHitTime`, and sequencer hits from `state.engine.pattern` + `state.engine.position()` via `TimelineView(.animation)`); a level bar from `state.engine.level()`; a full-screen "DROP" flash when `state.punch` falls from high to 0; `state.lastPerform` ("PERFORM ▸ ROLL") ticker. It must read well from 2 m away. Orientation: the content currently renders rotated on the outer panel; make it orientation-proof (GeometryReader: if the width > the height, rotate the content 90° to fill the portrait panel, and expose a `rotate: Angle` parameter so the lead can flip it). #Previews at 466×678 and 678×466. The lead wires it into `OuterCrowdHost` in `Sources/App/RootView.swift`.

### WP3: Submission kit, docs only (`README.md`, `SUBMISSION.md`), ~30 min
README: what/why, the Duo APIs used (reserved regions `.division`, `onHingeChange`, `CameraCaptureAccessory` for the back screen, size classes), models (Jev, GPT-6-luna/sol, local retrieval: see BUILD.md §2), architecture diagram (text), how to run (xcodegen, secrets, simulator), the self-test (`tools/selftest.sh`). SUBMISSION.md: title, one-liner, 150-word description, "what's only possible on Duo" bullets, the tech stack, a demo video link placeholder, team. Pull facts from BUILD.md / DEMO.md / git log; don't invent features.

### WP4: App icon + brand, `Resources/Brand/` only, ~20 min
`AppIcon-1024.png` (no alpha): TE style: light grey chassis, a 4×4 grid of dark pads with one orange pad, or an orange dot-matrix "CR". Also `wordmark.png` (orange Doto "CRATE" on transparent, 2000 px wide) for the video/slides. The lead adds the asset catalog to project.yml.

### WP5 (human, main Mac, after ~12:45): pose QA
In the Simulator: ⌘→ to rotate into laptop pose; hold ⌥ and drag for the hinge slider; check that the lid sits on the top half and the deck on the bottom, the fold gap is clean, and pads are reachable; screenshot anything broken. Check which way the back-screen content faces (`xcrun simctl io 0F3EDA96-26C2-468E-AAC2-2B28AE79F3B4 screenshot --display=1 /tmp/outer.png`).

### WP6 (human, main Mac): ears on the library
`afplay ~/duo-hack/library/loops/piano/L002.wav` (the headline Nujabes piano), plus L001/L003/L004/L018 and the breaks L061–L063. Note any bad sample IDs in `LIBRARY-NOTES.md` so they can be excluded.
