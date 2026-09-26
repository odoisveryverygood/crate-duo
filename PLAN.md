# Bitrig Hacks: iPhone Duo Edition — Sat 2026-09-26 @ YC

Doors 10:30 · opening 11:00 · **hacking 11:30–3:30** · demos 3:30–5:00 · awards 5:00.
Judging: creative use of what's unique to Duo (two displays, fold states, multitasking), "not possible before".
**All code written during hacking**; ideas/assets prepped ahead are fine. RevenueCat prize needs its SDK.

## What we're building
**CRATE (CR-16)**: an AI sampler for iPhone Duo. Teenage Engineering look, MPC Sample workflow.
Type a vibe ("4 bar loop, J Dilla laid-back drums + killer Nujabes piano sample"); it digs YOUR sample packs
instantly (Jev parse + local retrieval), then GPT composes the bassline/variation. The hinge is punch-in FX; snapping open = drop.
KEYS mode = chromatic keyboard for any pad.
Full spec: **BUILD.md**. Mockup: **design/mockup-laptop.png**.

## Prepared (assets/data only, no app code)
- `library/grooves.json`: 11 style grooves with microtiming, 8 fills, 9 bass rhythms (hand-written)
- `library/loops.json` + `library/loops/`: analyzed melodic loops (agent)
- `library/oneshots.json` + `library/oneshots/`: analyzed one-shots (agent)
- `assets/kits/boombap/`: 16-pad default kit; `assets/loops/`: 3 loops; `assets/fonts/`: Doto, Space Mono, JetBrains Mono
- `ai/jev-questions.json` (plan/perform/route), `ai/openai-arrange.md` (prompt + strict schema)
- Research: `research-mpc-te.md`, `research-jev.md`, `research-apis.md`, `duo-api-cheatsheet.md`, `audio-ai-stack.md`

## Setup checklist
- [x] macOS 27 + Xcode 27.1 (at ~/Downloads/Xcode.app, selected)
- [ ] `sudo xcodebuild -license accept` (blocks simctl, brew and the runtime download)
- [ ] iOS 27.1 simulator runtime + iPhone Duo device boots (`xcodebuild -downloadPlatform iOS`)
- [ ] brew: `hinge` (artemnovichkov/tap), `axe` (cameroncooke/axe); XcodeBuildMCP UI-automation workflow enabled
- [ ] Keys in `.secrets/keys.env`: TYPESAFE_API_KEY ✓, OPENAI_API_KEY ☐, (ELEVENLABS_API_KEY optional)
- [ ] Live-test Jev + OpenAI with curl (see research-jev.md §4; ONLY api.typesafe.ai, never jevapi.org)
- [ ] Throwaway toolchain smoke test (template app builds + runs on the Duo sim, reads a host file, plays a sound, hinge CLI moves it), then delete it
