# R4 — compact and back screen (teammate 2)

Implements direction **05 COLOUR-CODED** on `wp/field-outer`:

- Compact: black mini lid, Inter Light readouts, pale aluminium surround, round
  bank knobs, monochrome chips (AI PERFORM inverts white), black DIG and transport
  keys. REC/DIG activity uses orange. Landscape controls stack to avoid clipping.
- Crowd / Now Playing: a kit-seeded white keypad cover with small bank-colour
  markers, thin Inter title, artist line, loop progress, hit matrix, output meter,
  and PERFORM ticker in both portrait and landscape. Orange identifies live hits,
  level and DROP. No decorative orange wordmark or glow.
- Manual and sequencer hits use the shared timing model (including swing/offsets).
  The hinge DROP flash remains wired to `state.punch`.
- `CrowdStageView(state:rotate:)` lays out natively for its frame. There is **no
  automatic landscape rotation**. Explicit quarter turns swap the layout bounds
  before rotating. `OuterCrowdHost`'s existing rotation preference still works.
- `NowPlayingCard(state:)` remains reusable. Core has no arrangement-title field;
  the existing sample-label, then style-label fallback remains.

All existing accessibility identifiers and action bindings are retained. The
shared `PadGridView` retains its touch, keyboard and audio-drop implementations.
The white/RECORDS pad rendering is owned by **R3**, not duplicated here. Before R3
is merged, this branch still displays main's dark shared pads. A scratch combined
build with R3 commit `46e3aaa` was compiled and visually reviewed with white pads.

`OuterField` scopes the exact direction-05 CSS palette and Inter font names to R4
so R1 can land independently. It uses the shared Theme for the live orange,
mono type and hit timing. The four Inter fonts are already bundled/registered by
main. No changes to Theme, Core, Audio, AI, project settings or app wiring.

## Verification (2026-09-26)

```sh
CRATE_VERIFY_DEVICE=<booted-iOS-27.1-Duo-UDID> bash Sources/Crowd/verify.sh
# Optional scratch integration of R3's pad files, without editing this checkout:
CRATE_PAD_REF=origin/teamate-one CRATE_VERIFY_DEVICE=<UDID> bash Sources/Crowd/verify.sh
```

The script compiles all app Swift sources into a separate simulator preview app
(`com.shuhan.crate.outerpreview`), registers the actual bundled fonts, renders six
PNG fixtures through UIKit, and runs the real audio import/export path offline.
It prints the Documents path containing images and separate render/flow reports.
No API keys or shared Xcode project are used. `project.yml` already excludes
`Crowd/verify.sh`. A failed flow check makes the command exit nonzero, even if
rendering passes.

- PASS: all-source compile/link; Inter Light/Regular/Medium/SemiBold registration.
- PASS: reviewed compact and crowd at **466×678 / 678×466**, explicit 90° crowd
  rotation, and the standalone Now Playing card. Also reviewed R3 white-pad
  integration at both compact sizes.
- PASS: NSItemProvider copy lifetime, unique files, invalid-file cleanup,
  neighboring pad preservation, and all 16 decoded slices on the real engine.
- PASS: four-bar WAV at 89 BPM = **10.7865208333 seconds**, non-silent; concurrent
  capture rejection, cancellation, transport stop and tempo-change cleanup.
- FAIL: **import → chop → FLIP** does not sequence the imported sound (below).
- NOT VERIFIED: the actual Files-to-pad Split View drag gesture, export into
  another app, physical-device orientation, or live network AI. Provider delivery
  and rendered fixtures are not evidence for those end-to-end interactions.

## QA handoff to the lead: imported chops are not the FLIP session

Reproduced on main integration `3b77107` with R4, and again with R3's pad files:

1. Fresh offline state, receive a WAV via `NSItemProvider`.
2. `AudioImport.chop16` loads all 16 slices into Bank D (verified in AudioEngine).
3. Execute the same `dig("flip the sample")` path used by FLIP IT.
4. Observed: **scope becomes `fullBeat`, 0 Bank D event lanes, 16 imported sounds
   still loaded**. A library beat is generated instead of flipping the import.

Cause: `AudioImport.chop16` populates Bank D and AppState but does not establish
`Orchestrator.session`. With no session, `dig` changes `.flip` to `.fullBeat`.
With an existing session, `flip` targets its Bank B `session.chops` instead.
This is in the lead's assigned song-import/auto-chop/AI-flip integration. The
release flow needs the imported source, tempo/key and chop bank wired into that
session before FLIP/DIG; the R4 PR does not edit the lead-owned orchestration.
