# AI-native DJ deck / mini DAW — iOS Simulator build stack research
Date: 2026-09-25. Target: iOS 27.1 Simulator, M1 Max Mac, ~6-7hr build window.

## 1. Audio engine in the Simulator

### AVAudioEngine basics
- The iOS Simulator routes `AVAudioEngine` output through CoreAudio to the **Mac's actual output device** (Mac speakers / headphones). This works reliably for playback (`AVAudioPlayerNode`, `AVAudioUnitSampler`, `AVAudioUnitEQ`, `AVAudioUnitTimePitch`, reverb/delay units) — it's a long-standing, well-trodden path since iOS 8 and it still works on Xcode 16.x / iOS 18-27 sims in 2026.
- Known friction points, all mild:
  - Occasional crackle/distortion in Simulator output has been reported as recently as March 2025 (Xcode 16.2, macOS Sequoia 15.3.2, M1 MBP) — cosmetic, not a blocker for a demo. (developer.apple.com/forums/thread/668170)
  - `AVAudioPlayerNode.play(at:)` scheduling has been reported with ~100ms extra latency vs expectation on device; on Simulator, exact latency is unpublished but CoreAudio's simulated round-trip is usually **larger and less deterministic than a real device** — expect tens of ms of extra jitter. For sample-accurate BPM sync you should schedule buffers using the node's sample-time API (`AVAudioTime`) rather than trusting wall-clock timers, and don't chase sub-10ms precision live on Simulator.
  - `AVAudioUnitTimePitch` (used for pitch-bend / key-lock scratch effects) reported ~90ms inherent processing latency on Debug builds — factor that into any "tight" transition/quantize logic.
- Bottom line: **audio will play through Mac speakers reliably**; timing precision is "good enough for a live demo," not "sample accurate." Build your BPM-sync/quantize logic to tolerate ~50-100ms of slop.
- Reference test harness: github.com/jnpdx/AudioEngineLoopbackLatencyTest — useful if you want to self-measure latency in the first 15 minutes of tomorrow instead of trusting forum numbers.

### AudioKit (2026 state)
- Current architecture (since v5): AudioKit split into separate SPM packages:
  - `AudioKit` (Swift-only core, works even in Swift Playgrounds)
  - `AudioKitEX` (C++ DSP core, backing package `CAudioKitEX`)
  - `SoundpipeAudioKit` (Soundpipe DSP oscillators/filters, depends on AudioKit+AudioKitEX+CSoundpipeAudioKit)
  - `DunneAudioKit` (Chorus, Flanger, **Sampler**, Stereo Delay, **Synth**, Transient Shaper — depends on AudioKit+AudioKitEX+CDunneAudioKit)
  - SPM URLs (add each as its own package dependency in Xcode):
    - `https://github.com/AudioKit/AudioKit`
    - `https://github.com/AudioKit/AudioKitEX`
    - `https://github.com/AudioKit/SoundpipeAudioKit`
    - `https://github.com/AudioKit/DunneAudioKit`
  - Swift Package Index pages (couldn't fetch full compat matrix live — 403'd — but repo activity and package listings from swiftpackageindex.com/AudioKit/AudioKit and swiftpackageregistry.com/AudioKit/SoundpipeAudioKit confirm packages are current and SPM-installable in 2026).
- **Swift 6 strict concurrency**: no confirmed open blocking issue found specific to AudioKit for Swift 6 strict concurrency (searched GitHub issues directly, nothing recent turned up besides a stale 2020 Xcode-12 build issue, #2134, unrelated). AudioKit's core Swift layer is fairly old code (lots of `@objc`, C++ bridging) — **risk**: with a brand-new project defaulting to Swift 6 language mode + complete strict concurrency, you may hit unavoidable Sendable-conformance warnings/errors bridging into AudioKitEX's C++ types. **Mitigation for tomorrow: set your app target's Swift language mode to Swift 5 (or strict-concurrency = minimal) rather than fighting AudioKit's concurrency annotations** — this is a solved, zero-cost workaround and will save you real time.
- **Recommendation given your 6-7hr window**: for a DJ deck (2 decks + crossfader + filter + loop + BPM sync), **skip AudioKit entirely and hand-roll it directly on AVAudioEngine**. Two `AVAudioPlayerNode`s → two `AVAudioUnitEQ` (as filter) → two `AVAudioUnitTimePitch` (BPM-sync via rate) → mixed into `AVAudioEngine.mainMixerNode` with per-node `volume` driven by a crossfader value (`nodeA.volume = 1-x; nodeB.volume = x`, or use `AVAudioMixingDestination` pan/gain). Looping is `AVAudioPlayerNode.scheduleBuffer(_:at:options:.loops,...)`. This is maybe 150-250 lines and avoids any AudioKit build-config risk on an unfamiliar iOS 27.1 toolchain the night before a demo.
- **For the mini-DAW piano-keyboard-with-samples path**, `DunneAudioKit`'s `Sampler`/`Synth` is convenient, but plain `AVAudioUnitSampler` (Apple, zero dependencies) loading a bundled `.sf2` via `loadSoundBankInstrument(at:program:bankMSB:bankLSB:)` is **faster to wire up** — it's ~10 lines, no SPM resolution wait, no concurrency-mode fighting. This is the recommended path for tomorrow regardless of which idea you pick.

### Free GM SoundFonts to bundle
- **FluidR3_GM.sf2** — the standard, well-tested, spec-compliant GM soundfont; widely used specifically with `AVAudioUnitSampler` on iOS (the bradhowes/SoundFonts iOS app — github.com/bradhowes/SoundFonts — does custom build-phase handling of exactly this file). Full FluidR3 is ~140MB; there are trimmed/compressed community variants under 30MB — search "FluidR3_GM slim" or use Polyphone (polyphone.io) to strip unused instruments down to just piano/bass/drums/synth for your keyboard demo (can shrink to <5MB if you only need a handful of programs).
- **GeneralUser GS** — also explicitly called out as spec-compliant/reliable with `AVAudioUnitSampler` (avoids the crash risk Apple's forums note for malformed soundfonts). ~30MB, good middle ground.
- Sources: polyphone.io/en/soundfonts (GM.sf2), archive.org/details/500-soundfonts-full-gm-sets, zanderjaz.com/downloads/soundfonts/packs (FluidR3 GM, Musica Theoria GM), sites.google.com/site/soundfonts4u.
- **Recommendation**: grab FluidR3_GM, trim to piano+bass+drum-kit+synth-lead with Polyphone (10 min), bundle at ~3-8MB. Do this first thing tomorrow morning since it's a hard prerequisite and totally decoupled from coding.

## 2. Beat/BPM detection & waveform rendering on-device

- **Apple's new "Music Understanding" framework (WWDC26, iOS 27)** — this is the single biggest finding. It's a first-party on-device framework that, per Apple's WWDC26 session 253 and multiple 2026 writeups (synthtopia.com, theswift.dev, blakecrosley.com), gives you with **~3 lines of code**:
  - Beat positions and bar boundaries as arrays of `CMTime`
  - Global tempo as `beatsPerMinute` (nil if <2 beats detected)
  - Also: key, loudness, structure, instrument activity
  - Runs fully on-device, no ML expertise needed, ships in Final Cut Pro's own beat-detection feature.
  - **This is exactly the iOS version you're targeting (27.1)** — use this instead of any third-party BPM library. It's the fastest path to "load a track → know its BPM and beat grid" for both the DJ deck (beatmatching) and DAW (metronome/quantize) ideas.
  - Caveat to verify tomorrow: confirm the framework's model assets are actually present in the iOS 27.1 **Simulator** runtime image (Foundation Models framework has a documented simulator gotcha — see §3 — where the simulator proxies to the host Mac's model store and versions must match exactly; Music Understanding may or may not have the same host-proxying behavior since it's audio-model-based, not the System LLM). Test this in the first 10 minutes with a trivial call before architecting around it.
- **Fallback / backup options** if Music Understanding misbehaves in-sim:
  - `TempiBeatDetection` (github.com/Gr1b/TempiBeatDetection, also mirrored at CheckThisCodeCarefully/TempiBeatDetection) — pure Swift, real-time mic or static file beat detection, MIT-ish, small, easy to vendor as source (SPM-installable too).
  - `BPMKit` (github.com/hPerezz/bpm-kit) — Swift package, iOS 15+/macOS 12+, estimates integer BPM from local audio files, extracted from a real shipping app.
- **Waveform rendering**: no need for a library — decode the audio file's samples via `AVAudioFile`/`AVAudioPCMBuffer`, downsample (min/max per pixel-column bucket), and draw with SwiftUI `Path`/`Canvas`. This is ~40 lines and fully controllable for styling (bars/filled/mirrored). Don't add a dependency for this.
- Design reference for waveform UI (not code reuse — see §4): tnayuki/sujay explicitly implements an 8-second zoom waveform + full-track overview strip.

## 3. AI-native features via HTTP from iOS

### Text-to-music / stem generation
| Service | Endpoint | Auth | Price | Latency (10-30s clip) | Realtime streaming |
|---|---|---|---|---|---|
| **ElevenLabs Music** | REST, `api.elevenlabs.io` (Music endpoint) | API key header | ~$0.15/min official (third-party resellers report up to $0.64/min) | Not published exactly, but ElevenLabs' generation APIs are typically single-request/response (tens of seconds for a full track); budget 15-45s for a 30s clip | No — request/response only |
| **Stability Stable Audio 2.5** | REST, `api.stability.ai`, credit-based (1 credit=$0.01) | API key (Bearer) | **$0.20 flat per generation** regardless of duration — cheapest predictable cost | Uses **long-polling** (submit job, poll for completion) — plan for a loading state, not instant; exact seconds not published but audio-diffusion models at this size typically land 10-30s server time | No |
| **Google Lyria RealTime** | Gemini API, **WebSocket** (bidirectional, persistent) | Gemini API key | Gemini API metered pricing (check current Gemini pricing page at call time) | **True streaming** — continuous 48kHz stereo audio stream, you steer live with text-prompt blending + direct key/tempo/density/brightness controls | **Yes — the standout option**. This is a persistent WS connection that never stops generating; you can interactively warp it in real time, which is uniquely suited to a live DJ-deck demo ("AI is jamming an extra layer live"). No vocals though. |
| **Google Lyria 3.5** (non-realtime) | Gemini API REST | Gemini API key | Gemini metered | Full-song generation, request/response | No |
| Suno (unofficial) | Reverse-engineered, no official API/ToS risk | none official | free/unofficial | variable, unreliable | No — skip for a demo, ToS/reliability risk not worth it in a 6hr window |
| Replicate MusicGen | `replicate.com/...` REST, poll or webhook | Replicate API token | pay-per-second GPU, cents per generation | Cold start can add 10-30s; warm run for a 20-30s clip typically 15-40s on an A100 | No |

**Recommendation**: For the "AI-native" wow-factor with least integration risk in 6-7 hours: **Lyria RealTime via WebSocket** if you want live-jamming-with-AI as a headline feature (best demo, but WebSocket streaming audio decode/playback into AVAudioEngine is the highest-effort integration — budget 1.5-2hrs). If you want a safer bet, **Stable Audio 2.5** (simple REST, flat $0.20/gen, long-poll) or **ElevenLabs Music** (simple REST) for "generate a 20s instrumental stem to drop into the mix" is a 30-45 minute integration: fire request → poll/wait → download resulting audio file (mp3/wav) → load into an `AVAudioPlayerNode` like any other deck track.

### Stem separation
| Service | Latency | Price | API maturity |
|---|---|---|---|
| **Replicate (demucs, e.g. ryan5453/demucs)** | ~1.5x track length; on Apple Silicon (M2/M3-class GPU) ~90s for a 4-min track, sub-30s on datacenter GPU, 8-15min on CPU-only fallback | ~$0.04-0.05/song | Straightforward REST + poll/webhook, well-documented, easiest to integrate quickly |
| **Moises** | 30-90s cloud processing | Consumer subscription tiers ($3.99-$9.99/mo); **API access is a limited partner tier**, not self-serve | Not recommended for a same-day hack — API access is gated |
| **LALAL.AI** | Not directly benchmarked here, but industry comparisons rank it competitively with Demucs quality | Per-minute credit pricing, has a public developer API | Reasonable fallback if Replicate is inconvenient |
| ElevenLabs | No confirmed stem-separation product found in this research (ElevenLabs' music line is generation, not separation) | — | Don't rely on this for stems |

**Recommendation**: **Replicate demucs** is the fastest, cheapest, most self-serve stem-separation option for a hackathon — plain REST, cents per song, ~90s on your own M1 Max class hardware if you even run it locally instead of via API (demucs also runs directly via `pip install demucs` + CLI if you want zero network dependency as a backup — worth having as an offline fallback given hotel-wifi-grade demo risk).

### LLM as agent DJ/producer (Claude)
- **Official Swift support exists**: Anthropic shipped `ClaudeForFoundationModels`, a Swift package announced at WWDC26 that conforms Claude to Apple's `LanguageModel` protocol. This means you can use Apple's own `LanguageModelSession` API (`respond(to:)`, streaming, guided generation, **tool calling**) and swap between Apple's on-device model and **Claude Sonnet/Opus** with essentially one argument change. Doc: platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models. This is very likely your fastest path for "LLM agent controls the mixer" — you get typed tool-calling for free via the Foundation Models tool-calling machinery instead of hand-rolling JSON-mode parsing.
- **Unofficial pure-Swift SDK**: `SwiftClaude` (github.com/GeorgeLyon/SwiftClaude) — a community Swift SDK for the Claude API directly (no Foundation Models dependency), useful if you'd rather not take on the Foundation Models abstraction.
- **Fallback / simplest**: plain `URLSession` POST to `api.anthropic.com/v1/messages` with `tools` in the request body, model id `claude-sonnet-5` (fast, cheap) — for a "return MIDI notes as JSON" tool-calling flow, this is maybe 60-90 minutes of work including a `Codable` tool-input schema, and is the most predictable/controllable if you're worried about the Foundation Models package having rough edges on a brand-new iOS 27.1 toolchain the night before.
- **Recommendation**: use `claude-sonnet-5` via a hand-rolled `URLSession` tool-calling loop (skip the Foundation Models indirection) unless you specifically want to also demo on-device/cloud model-swapping — that adds a nice narrative ("agent DJ") but is extra integration surface you don't strictly need. Define one tool like `set_transition(fromDeck, toDeck, style, bars)` or `add_bassline(key, notes: [MIDINote])` and have Claude return structured JSON your app applies directly to the mixer/sequencer state.

### Voice input
- **SFSpeechRecognizer**: mature, definitely works in Simulator (uses on-device or server recognition depending on locale/settings) — safest choice if you want guaranteed simulator voice input tomorrow.
- **SpeechAnalyzer / SpeechTranscriber (iOS 26+)**: newer, nicer streaming API, MIT sample available at github.com/simplememofast/ios26-speechanalyzer-live-mic — but **confirmed NOT available on iOS 26 Simulator** in current tooling (explicit "SpeechTranscriber not supported" report on Apple dev forums), and it's gated by Neural Engine core count (16-core NE required; 8-core NE devices don't support it) — this restriction plausibly also constrains what the Simulator can emulate/proxy. **Risk flag: do not build your only voice-input path on SpeechTranscriber for tomorrow's simulator demo — use SFSpeechRecognizer as the primary, with SpeechAnalyzer only as a stretch goal if time remains.**
- **Apple Foundation Models framework in Simulator**: works, but with a hard gotcha — Simulator doesn't ship its own model copy; it calls out to the **host Mac's** on-device model store, and **Xcode version, Simulator runtime version, and host macOS version must all match (all ≥26.0)** for it to work at all. If your Mac's macOS version doesn't line up with the iOS 27.1 SDK/Simulator you're using, calls will silently fail to find model assets. **Verify macOS version compatibility on your M1 Max first thing tomorrow** before planning any on-device-LLM feature around it — this is the single highest-risk simulator gotcha found in this research.

## 4. Design inspiration (not for code reuse — build fresh tomorrow)
- **tnayuki/sujay** (github.com/tnayuki/sujay) — macOS SwiftUI DJ app, AVFoundation-based: 2 decks + crossfader, 8-second zoom waveform + full-track overview with click-to-seek, 3-band EQ. Closest architectural match to what you're building — worth a 5-minute skim for waveform/crossfader layout ideas.
- **1amageek/MusicPlaygournd** (github.com/1amageek/MusicPlaygournd) — SwiftUI, central crossfader mixing into master, draggable gain knobs — good reference for knob interaction gestures.
- **ali-khaled-949/easy-dj-mixer** — scrolling waveform with fixed center playhead + overview strip, per-deck filter knobs.
- Browser/JUCE projects (Pandiyarajk/dj, KVRNL/turnstyle, s4turns/opendj) — good for visual/UX inspiration only, not Swift code.

## Top risks flagged for tomorrow (check first, before architecting)
1. **Apple Foundation Models / on-device LLM simulator gating on macOS-version match** — verify before relying on it.
2. **SpeechTranscriber unsupported on Simulator** — use SFSpeechRecognizer as primary voice path.
3. **AudioKit + Swift 6 strict concurrency** — set language mode to Swift 5 / minimal strict-concurrency on the app target proactively, or just skip AudioKit and hand-roll AVAudioEngine (recommended anyway for speed).
4. **AVAudioPlayerNode/TimePitch latency (~50-100ms) and Simulator audio jitter/crackle** — build BPM-sync/quantize UI to tolerate slop; don't promise sample-accurate sync in the demo.
5. **Lyria RealTime WebSocket audio decode into AVAudioEngine** is the highest-integration-effort AI feature — only take it on if the rest of the app is done early.
