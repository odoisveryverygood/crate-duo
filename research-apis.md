# Research notes: sampler-app APIs (ElevenLabs SFX, OpenAI, CoreMIDI, XcodeBuildMCP, hinge)

Date: 2026-09-26. Target: iOS 27.1 SwiftUI sampler app, iPhone Duo Simulator, Xcode 27.1 beta, macOS 27, M1 Max.

Confidence key (same convention as `duo-api-cheatsheet.md`): **[A]** = confirmed from an official/primary doc (elevenlabs.io/docs, developers.openai.com, github.com/<project>). **[T]** = reputable third-party/secondary source, likely accurate but not primary. **[U]** = unverified, conflicting across sources, or inferred/composite — verify before relying on it tomorrow.

---

## 1. ElevenLabs Sound Effects (text-to-SFX) API

### Endpoint & auth **[A]**
```
POST https://api.elevenlabs.io/v1/sound-generation
```
Headers: `xi-api-key: <key>`, `Content-Type: application/json`.
Source: [Create sound effect — API reference](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert)

### Body fields **[A]** (from the API reference page)
| Field | Type | Default | Notes |
|---|---|---|---|
| `text` | string | — (required) | The prompt to convert to a sound |
| `model_id` | enum | `eleven_text_to_sound_v2` | Docs currently list only this value — no v1 shown |
| `duration_seconds` | double | `null` | Range **0.5–30 s**; if omitted, the model guesses duration from the prompt |
| `prompt_influence` | double | `0.3` | Range 0–1; higher = follows prompt more closely, less variation |
| `loop` | boolean | `false` | Smooth loop; **v2 model only** |

`output_format` is a **query parameter**, not a body field, formatted `codec_sample_rate_bitrate`. Confirmed enum values **[A]**:
`mp3_22050_32`, `mp3_24000_48`, `mp3_44100_32`, `mp3_44100_64`, `mp3_44100_96`, `mp3_44100_128`, `mp3_44100_192`, `pcm_8000`, `pcm_16000`, `pcm_22050`, `pcm_24000`, `pcm_32000`, `pcm_44100`, `pcm_48000`, `ulaw_8000`, `alaw_8000`, `opus_48000_{32,64,96,128,192}`.

**Discrepancy flag [U]:** the [Sound effects overview](https://elevenlabs.io/docs/overview/capabilities/sound-effects) page separately claims "WAV at 48kHz (non-looping only)" is available, but no `wav_*` string appears in the `/convert` endpoint's own enum. Possibly a playground-only download option, or an enum value not surfaced in the fetch. **Test both `output_format=pcm_48000` and check for a `wav` value at build time** rather than assuming.

### curl example **[A]**
```bash
curl -X POST "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
        "text": "single dry drum kick, one-shot, no reverb, no tail",
        "duration_seconds": 1.2,
        "prompt_influence": 0.6
      }' \
  --output kick.mp3
```
200 → raw audio bytes. 422 → validation error JSON.

### Easiest format for `AVAudioFile`/`AVAudioPCMBuffer` on iOS **[T]/reasoned**
- `pcm_*` values return **raw headerless samples** ("zero container metadata" per [ElevenLabs' PCM output post](https://elevenlabs.io/blog/pcm-output-format)) — fast, no decode step, but you must hardcode the exact bit depth/endianness/channel count to build an `AVAudioFormat` manually and fill an `AVAudioPCMBuffer` yourself; ElevenLabs' TTS docs describe their PCM as 16-bit signed little-endian mono, and it's reasonable but **unconfirmed for this specific endpoint** that sound-generation PCM matches.
- **Recommended for the hackathon:** request `mp3_44100_128`, write the response bytes to a temp `.mp3` file, then `AVAudioFile(forReading:)` — iOS decodes mp3 natively and `read(into:)` hands you a ready `AVAudioPCMBuffer` with zero manual format bookkeeping. Decode overhead for a 1–2 s clip is negligible (single-digit ms). Only drop to raw `pcm_44100` if you hit measurable overhead, since you'd then own format correctness yourself.

### Latency **[T]**
No official SLA published. ElevenLabs' own soundboard build-log states "typical generation time is under two seconds" for short one-shot SFX ([how-we-created-a-soundboard-using-elevenlabs-sfx-api](https://elevenlabs.io/blog/how-we-created-a-soundboard-using-elevenlabs-sfx-api)). Note that blog's example request used a different shape (`prompt`/`n`/`format:"wav"`, `Authorization: Bearer`) than the current official `/convert` reference (`text`/`xi-api-key`/`output_format` query) — likely an older API version or a simplified paraphrase in the post. Trust the official reference for the request shape; trust the blog only for the "~2s" ballpark and prompt-style examples ("tight snare snap", "super bassy 808 kick").

### Credit cost **[A]/[T]**
- Sound Effects: **200 credits** per generation when duration is AI-decided; **40 credits/second** when you set `duration_seconds` explicitly (max 30 s → max 1200 credits). ([How much does it cost to generate sound effects?](https://help.elevenlabs.io/hc/en-us/articles/25735337678481-How-much-does-it-cost-to-generate-sound-effects))
- **Actionable tip:** for a 1–2 s drum one-shot, always pass `duration_seconds` explicitly — e.g. 1.2 s = ~48 credits, versus 200 credits if you let it guess. 4x+ cheaper.
- A separate figure floating around, "$0.12/min" for API sound-effect billing, appears to be a pay-as-you-go framing rather than the credit system — reconcile against [elevenlabs.io/pricing/api](https://elevenlabs.io/pricing/api) at build time. **[U]**

### Rate / concurrency limits **[T], numbers conflict across sources — treat as approximate**
Concurrency (simultaneous in-flight generations) scales by plan tier; one set of sources gives Free=2, Starter=3, Creator=5, Pro=10, Scale/Business=15; another gives noticeably higher numbers per tier. Enterprise is custom/negotiated. ([API Error Code 429](https://help.elevenlabs.io/hc/en-us/articles/19571824571921-API-Error-Code-429), [ElevenLabs Limits at Scale](https://deepgram.com/learn/elevenlabs-production-limits-concurrency-credits-compliance)) The binding constraint is concurrency, not requests/minute. **Confirm your actual tier's number in the ElevenLabs dashboard before assuming you can fire 8 SFX generations in parallel for a full drum kit** — if you're on Free/Starter, batch/stagger the 8 one-shot requests instead of firing all at once.

### Prompt-writing tips for clean drum one-shots **[T] — synthesized, no single official "recipe" page found**
No dedicated prompt-engineering page for one-shots was found; the closest is the [Sound effects overview](https://elevenlabs.io/docs/overview/capabilities/sound-effects) terminology glossary (Impact, Whoosh, Ambience, **One-shot**: "single, non-repeating sound", Loop, Stem, Braam, Glitch, Drone) plus real examples from the soundboard blog ("tight snare snap", "super bassy 808 kick"). Practical synthesis for this app:
- State the hit type + timbre + explicit dryness: `"single dry kick drum hit, one-shot, tight, no reverb, no tail, no reverb decay"`.
- Front-load "single"/"one-shot" — the model appears to respond to it as a duration/character cue, corroborated by it being a defined term in ElevenLabs' own glossary.
- Push `prompt_influence` up (0.5–0.7) for one-shots — you want low variance/tight adherence, not the creative drift a lower value encourages.
- Set `duration_seconds` short (0.6–1.5 s for a hit) — this both trims cost and discourages the model from generating a decaying/evolving tail.

### ElevenLabs Music API (brief — "generate a loop" stretch feature)
- Endpoint **[A]**: `POST https://api.elevenlabs.io/v1/music` ([Compose music](https://elevenlabs.io/docs/api-reference/music/compose)). Body: `prompt` OR `composition_plan` (mutually exclusive), `music_length_ms`, `model_id` (`music_v1`/`music_v2`/`music_v2_5`), `force_instrumental`, `seed`, output_format enum shares the mp3/pcm/opus values above plus higher-bitrate `mp3_48000_{128,192,240,320}`.
- **Min duration 3,000 ms (3 s), max 600,000 ms (10 min)** for prompt-based generation; composition-plan sections cap at 120,000 ms each. **[A]**
- Latency not published for short clips; general guidance says end-to-end latency "varies with location and endpoint type" ([Latency optimization](https://elevenlabs.io/docs/eleven-api/guides/how-to/best-practices/latency-optimization)) — budget it as a background/async request, not something you await synchronously in a tap gesture.

---

## 2. OpenAI API as of September 2026

### Model landscape — **naming is genuinely in flux this month, flag prominently [U]**
Two overlapping generations turned up in search, with real contradictions across sources:
- **GPT-5.6 family** (mid-2026): **Sol** (flagship, "complex professional work"), **Terra** (balance of intelligence/cost), **Luna** (cost-sensitive/high-throughput). Confirmed via OpenAI's own [deprecations page](https://developers.openai.com/api/docs/deprecations), which lists `gpt-5.6-sol` / `gpt-5.6-terra` / `gpt-5.6-luna` as the official replacement IDs for retired `gpt-5-2025-08-07` family models. **[A]**
- **GPT-6 family** (GPT-6 Astra shipped Sept 3, 2026; "GPT-6 Sol and Luna" announced Sept 22, 2026, 4 days before this research): **Astra** (most capable, XL), **Sol** (reused name, now "complex coding/agentic" tier), **Luna** (reused name, "efficient/high-volume" tier) — one source explicitly says "no GPT-6 Terra." **[T]**, corroborated by [9to5Mac](https://9to5mac.com/2026/09/22/openai-upgrading-chatgpt-and-codex-with-two-more-gpt-6-models/) and OpenAI's own ["Introducing GPT-6 Sol and Luna"](https://openai.com/index/introducing-gpt-6-sol-and-luna/) index page (fetch of the article itself 403'd, title/date confirmed via search only).
- **Your own memory file already references `gpt-5.6-luna`** as a working, currently-integrated model (flatfinder project) — that's your one **confirmed-good** anchor point tonight.
- **Action before coding tomorrow:** hit `https://developers.openai.com/api/docs/models/all` live and copy the exact current ID rather than trusting this doc — the family got a second rename within the last 3–4 weeks and may move again by morning.

### Recommendation
- **Task A — "16-step × 8-track drum pattern + velocities as JSON from a vibe prompt, under ~3 s":** use the **fastest/cheapest tier** — `gpt-5.6-luna` (confirmed-working per your own prior usage) or its GPT-6 successor if you verify the ID live. The schema is small and fixed-shape (128 cells, ints), which plays to a nano-tier model's strength (routing/classification-style structured tasks) rather than needing flagship reasoning depth. Pair with `reasoning: {"effort": "none"}` (see below) and Responses API `text.format` strict JSON schema. **Do one throwaway warm-up call before the demo** — OpenAI's own structured-outputs docs state the *first* request against a new schema carries extra compile latency, cached for all subsequent calls with that schema. **[A]**
- **Task B — "8 short SFX prompts for a drum kit from a vibe":** a mid tier (`gpt-5.6-terra` or its successor) is the safer pick — it's a creative-writing task (short strings, needs some taste), less latency-critical since it's one call per session rather than per-interaction, and Terra is explicitly positioned as the "balance of intelligence and cost" tier. **[T]**

### Responses API + `text.format` json_schema strict — curl example **[A]** (structure), model ID **[U]** (verify at build time)
```bash
curl https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.6-luna",
    "reasoning": { "effort": "none" },
    "input": [
      { "role": "system", "content": "Generate a 16-step, 8-track drum pattern from the vibe." },
      { "role": "user", "content": "dark trap, half-time, sparse hats" }
    ],
    "text": {
      "format": {
        "type": "json_schema",
        "name": "drum_pattern",
        "strict": true,
        "schema": {
          "type": "object",
          "properties": {
            "bpm": { "type": "integer" },
            "tracks": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "steps": { "type": "array", "items": { "type": "integer" }, "minItems": 16, "maxItems": 16 },
                  "velocities": { "type": "array", "items": { "type": "integer" }, "minItems": 16, "maxItems": 16 }
                },
                "required": ["name", "steps", "velocities"],
                "additionalProperties": false
              },
              "minItems": 8, "maxItems": 8
            }
          },
          "required": ["bpm", "tracks"],
          "additionalProperties": false
        }
      }
    }
  }'
```
Source for the `text.format`/`strict` shape: [Structured model outputs](https://developers.openai.com/api/docs/guides/structured-outputs). Note one fetch of this exact curl pattern returned a model string `gpt-6-astra` in a live doc example — another data point that the docs themselves are actively being edited toward GPT-6 naming; don't be surprised if the example model changes underneath you.

### Reasoning effort ladder **[A]/[T]**
Values confirmed across docs: **`none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`**. Default is `medium` on GPT-5.5/5.6-class models. Critical gotcha: **`none` is not universally supported** — the flagship `gpt-6-astra` explicitly **rejects `reasoning.effort: none` with HTTP 400** per [Reasoning models](https://developers.openai.com/api/docs/guides/reasoning); official guidance for latency-sensitive `gpt-5.5`-class use is "try `low` first, then `none` if required." This is a real argument for using a Luna/Terra-class (smaller) model for your <3s pattern-gen call — the small models are the ones that actually accept `none`. For structured JSON specifically, `none` fits "latency-critical tasks that don't benefit from reasoning... classification"; `low` is the docs' suggestion when you want "a modest latency increase" for slightly more judgment.

### Deprecations / Chat Completions status **[A]**
Chat Completions **as an API surface is not deprecated** — only the **Assistants API** has a sunset date (Aug 26, 2026 removal, migrate to Responses + Conversations APIs). Specific old *model snapshots* are what's actually being retired on a rolling schedule: `gpt-5-2025-08-07`, `gpt-5-mini-2025-08-07`, `gpt-5-nano-2025-08-07`, `gpt-5-pro-2025-10-06` (all → replace with `gpt-5.6-sol`/`terra`/`luna` as appropriate) shut down Dec 11, 2026; `gpt-5-chat-latest`, `gpt-5-codex`, `gpt-5.1-*`, `gpt-5.2-chat-latest`, `gpt-5.2-codex`, `gpt-5.3-chat-latest` shut down July 23, 2026 (already past, don't use these); `gpt-5.4-cyber` shuts down Oct 1, 2026 (5 days from now). None of this blocks using Chat Completions generically — just don't pin to any of the listed dead snapshot strings. Source: [Deprecations](https://developers.openai.com/api/docs/deprecations).

---

## 3. CoreMIDI in the iOS Simulator

### Can the Simulator receive MIDI from a USB keyboard on the host Mac?
Breaking your question into the three mechanisms you named:

- **Direct (USB passthrough into the sim process): No.** This has been true since CoreMIDI's iOS debut and nothing found contradicts it for 2026 — the Simulator has no USB-hardware transport; class-compliant USB MIDI only enumerates on real devices. **[T]**, longstanding community consensus (e.g. Pete Goodliffe's CoreMIDI-on-iOS writeup, multiple forum threads).
- **IAC alone: No, not a direct bridge.** IAC (Inter-Application Communication) buses route MIDI between processes *on the same CoreMIDI context*; the Simulator is a separate process/context, so an IAC bus doesn't reach into it by itself. **[U]/reasoned** — no source explicitly says "IAC doesn't reach the simulator," but nothing describes IAC as a sim-bridging mechanism either; every confirmed working recipe uses Network MIDI instead.
- **Network Session (RTP-MIDI/AppleMIDI): Yes, this is the real bridge — but it's fiddly.** Recipe confirmed across multiple sources: enable `MIDINetworkSession.default().isEnabled = true` in-app, then in macOS **Audio MIDI Setup → MIDI Studio → Network**, the booted simulator shows up as a directory peer you connect to (port defaults to 5004). Once connected, MIDI reaches the sim over the loopback network transport. **[T]**, e.g. [JUCE forum](https://forum.juce.com/t/receiving-midi-from-network-session-1-on-ios/47629), [Loopy Pro forum](https://forum.loopypro.com/discussion/4651/midi-and-ios-simulator).
  - **Known friction, straight from Apple's own forum thread 672445** ([Send MIDI to iOS Simulator](https://developer.apple.com/forums/thread/672445)): Bonjour/`NSNetServiceBrowser`-based auto-discovery of the simulator peer frequently just doesn't fire; the reporter had to manually connect via the Mac's own IP + port, and even then got only the *first* MIDI message through before audio cut out and subsequent messages were silently dropped ("buzzing" reported). **No fully-working end-to-end recipe was found in that thread** — it ends unresolved.
  - Separate build-config gotcha **[T]**: if CoreMIDI gets linked twice (e.g. via a CocoaPod like MIKMIDI *and* directly), the "iPhone Simulator" entry disappears entirely from Audio MIDI Setup's directory. Keep CoreMIDI linked exactly once.
  - **Getting the actual USB keyboard's notes into that network session is a second, separate hop** that no source explicitly documents end-to-end: the Mac reads the USB keyboard via CoreMIDI trivially, but relaying those events into `MIDINetworkSession`'s destination endpoint needs either a small custom Mac-side relay (a `MIDIPortConnectSource`-based forwarder, or CLI tools like `sendmidi`/`receivemidi` piped together) — this composite pipeline is **[U], plausible but not found as a documented recipe**.
- **Practical recommendation for a 4-hour hackathon:** given the confirmed flakiness (auto-discovery unreliable, message-drop bug reported), **do not make live USB-MIDI-keyboard input a load-bearing demo feature.** If you want it as a stretch goal, test the network-session bridge in the first 15 minutes with a hard fallback to on-screen touch pads (which your existing plan already uses for the DJ deck).

### AVAudioUnitSampler / AVAudioEngine issues in iOS 26/27 Simulator
No new, iOS-26/27-specific simulator regressions were found. What's confirmed is a **long-standing, never-fixed framework bug**: running **multiple `AVAudioUnitSampler` instances loading different sample sets** triggers undefined behavior / `ExtAudioFile` errors, reproducing on **both device and simulator** — [Apple Developer Forums thread 709564](https://forums.developer.apple.com/forums/thread/709564). **[T]** For an 8-track drum sampler this is directly relevant if your architecture is "one `AVAudioUnitSampler` per track" — safer pattern is one sampler per *voice group* or route distinct one-shot buffers through `AVAudioPlayerNode`s instead of stacking many live `AVAudioUnitSampler`s. This complements (doesn't replace) what's already in `audio-ai-stack.md` §1 — that file's crackle-in-simulator (Mar 2025) and `AVAudioUnitTimePitch` ~90ms latency findings still stand; nothing found here changes them.

---

## 4. XcodeBuildMCP v2 configuration

**Caveat up front:** `xcodebuildmcp.com` failed to resolve from this sandbox's DNS (confirmed via both `WebFetch` and a direct `curl`/`dig` — `Can't find xcodebuildmcp.com: No answer`), so the canonical docs site itself could not be fetched directly. Everything below is reconstructed from GitHub mirrors, DeepWiki, and third-party write-ups — **re-check the live docs site once you have real network access tomorrow.** **[U]** for exact current wording, **[T]** for the substance.

### Enabling via Claude Code
Baseline install (this matches the form in your prompt):
```bash
claude mcp add -s user XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
```
The `mcp` subcommand at the end is required in v2.0.0+ to start server mode (bare `xcodebuildmcp` without `mcp` runs it as a CLI, not an MCP server). **[T]**

### Enabling specific workflows (UI automation, logging)
Two mechanisms exist, with a stated precedence order **session tool-call overrides > config file > environment variables** (config file is described as "the canonical home for structured, repo-scoped settings"):
- **Env var route:** `XCODEBUILDMCP_ENABLED_WORKFLOWS` set to a comma-separated list of workflow IDs, e.g. `simulator,ui-automation,logging`. Confirmed workflow IDs seen across sources: `simulator` (on by default), `device`, `macos`/`macOS`, `debugging`, `ui-automation`, `project-discovery`. **A distinct `logging` workflow ID was not independently confirmed** — log capture may already ship bundled inside `simulator`/`device` rather than being its own toggle; treat `logging` in your env-var string as best-effort and verify by listing the tools Claude Code actually receives after install. **[U]**
  ```bash
  claude mcp add -s user XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp \
    -e XCODEBUILDMCP_ENABLED_WORKFLOWS=simulator,ui-automation,logging
  ```
- **Config file route (canonical):** `.xcodebuildmcp/config.yaml` at the workspace root, `schemaVersion: 1` required, with an `enabledWorkflows` array key. Other documented top-level keys: `sessionDefaults`, `sessionDefaultsProfiles`, `activeSessionDefaultsProfile`, `customWorkflows`, `debug` (bool), `sentryDisabled` (bool), `debuggerBackend` (`"dap"`|`"lldb-cli"`), `dapRequestTimeoutMs`, `dapLogEvents` (bool — this is likely your actual logging knob), `launchJsonWaitMs`, `experimentalWorkflowDiscovery`. **[T]**, via DeepWiki mirror of the getsentry/XcodeBuildMCP wiki — no verbatim full-file example was recovered, so key names are solid but a complete worked example wasn't confirmed.
  ```yaml
  schemaVersion: 1
  enabledWorkflows: [simulator, ui-automation]
  debug: true
  dapLogEvents: true
  ```
- AXe path override, if you install AXe separately, is exposed as env var `XCODEBUILDMCP_AXE_PATH` (also seen as a config key `axePath` pointing at e.g. `/opt/axe/bin/axe` in one source — the two may be aliases of each other). **[U]**

### Does UI automation require AXe installed separately, or is it bundled?
**Bundled — confirmed across multiple sources, no separate brew tap needed for the standard install path.** "AXe binary and frameworks are now included in the npm package for zero-setup UI automation" and, separately, Homebrew/portable distributions bundle a pinned AXe version (one source cites `1.5.2`). The `brew tap cameroncooke/axe && brew install axe` route (your prompt's phrasing) is the **developer/from-source path** — relevant if you're building XcodeBuildMCP from a git clone rather than installing via `npx`/Homebrew's own formula, or if you want a system-wide AXe on `PATH` independent of the MCP server's bundle. For a straight `npx -y xcodebuildmcp@latest mcp` install tonight, **you should not need to `brew tap` anything separately.** **[T]**

### Logging workflow — likely tools
XcodeBuildMCP's own capability blurb (visible in this session's MCP server instructions) describes "Log capture: Stream and capture logs from simulators and devices" as a standing capability alongside simulator/device/UI-automation workflows — so functionally it exists; whether it's gated by its own workflow-ID string or ships automatically with `simulator`/`device` is the part left unconfirmed above.

---

## 5. `hinge` CLI (github.com/artemnovichkov/hinge)

### Install **[A]** (README)
```bash
brew install artemnovichkov/tap/hinge
```
or from source:
```bash
git clone https://github.com/artemnovichkov/hinge.git
ln -s "$PWD/hinge/bin/hinge" /usr/local/bin/hinge
```
First run compiles a small helper with Xcode's `clang` and caches it in `~/.cache/hinge` — **implies you need Xcode's command-line tools/license already accepted** (`xcode-select -p` resolving, license accepted) even though the README doesn't spell out "accept the Xcode license" as its own bullet. **[U]/inferred.**

### Commands **[A]**
```
hinge [-d <device>] <command>
```
- `<degrees>` — set angle directly, 0 (closed) – 180 (flat)
- `set <degrees>` — explicit form of the above
- `open` — 180° (fully unfolded)
- `close` — 0° (fully closed)
- `half` — 90°
- `sweep <from> <to> [seconds]` — animate between two angles (default 1s)
- `get` — print current angle
- `help`
- Flags: `-d/--device <udid|name|booted>` (default `booted`), `-v/--version`

### Requirements **[A]/[U]**
- macOS with **Xcode 27.1+ and a foldable iOS Simulator runtime** booted. **[A]**
- **No explicit Accessibility permission requirement found in the README** — the tool talks to the simulator via a private/undocumented protocol plus a self-compiled helper, not via macOS Accessibility APIs, so it plausibly doesn't need the Accessibility permission grant that UI-automation tools (like AXe/XcodeBuildMCP) do. **This is an absence-of-evidence, not confirmed-absent — verify by just running it; if it silently no-ops, check System Settings → Privacy & Security → Accessibility.** **[U]**
- No Xcode "license" step is mentioned explicitly, but per above, the helper-compile step implies working command-line tools.

### Known issues **[A]** (stated directly in README)
- "Simulator only. Physical devices are not supported."
- "The protocol is private and undocumented. It was verified with Xcode 27.1 and the iOS 27.1 runtime and may break with future releases." — i.e. this is reverse-engineered, not an Apple API; treat as fragile if you update Xcode mid-hackathon.
- "The Device Hub slider doesn't move when the angle changes from hinge" — visual desync between the CLI-driven fold state and the Device Hub's own UI slider; the simulator's actual hinge state changes even if the slider widget doesn't reflect it.

### AI agent integration **[A]**
Ships as an installable Agent Skill for Claude Code/Codex/Cursor-style tools:
```bash
npx skills add artemnovichkov/hinge
```
or manually copy `hinge/skills/hinge` into `~/.claude/skills/` (Claude Code) or `~/.codex/skills/` (Codex) — lets an agent fold/unfold the simulator itself while verifying your app, which pairs naturally with XcodeBuildMCP's screenshot/UI-snapshot tools from §4 for a scripted "fold → screenshot → assert" loop.

---

## Summary of what to verify first thing tomorrow (highest-uncertainty items)
1. **OpenAI model IDs** — literally check `developers.openai.com/api/docs/models/all` live; naming shifted twice in the last month (GPT-5.6 → GPT-6). Your `gpt-5.6-luna` from the flatfinder project is the one confirmed-working anchor.
2. **XcodeBuildMCP workflow env var / config keys** — the docs site was unreachable from this sandbox; re-fetch `xcodebuildmcp.com/docs/configuration` yourself and confirm the exact `logging` workflow ID (or that it's bundled) before wiring your MCP config.
3. **CoreMIDI network-session bridge** — don't build a demo around it; the one primary-source forum thread describing it ends unresolved (message drops after first note).
4. **ElevenLabs `output_format` WAV support and exact concurrency numbers for your tier** — two internally-inconsistent details, check your dashboard/account tier directly.
5. **`hinge` Accessibility permission** — untested claim; just run `hinge open` once against a booted sim and confirm.
