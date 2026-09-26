# CRATE: demo script (90 s) + pitch

**One-liner:** CRATE turns the iPhone Duo into an AI sampler. Say a vibe; it digs your own sample crates instantly and hands you a playable beat. The hinge is an instrument.

## Setup before going on stage
- Simulator: iPhone Duo, laptop pose (rotated), hinge ~110°. App freshly launched, volume up, Wi-Fi checked (fallback works offline anyway).
- Backup: the recorded demo video in `~/crate-build/demo/` if anything misbehaves.

## Script
1. **(0:00) Hook, phone closed.** "Every producer has 50 GB of sample packs and still spends an hour digging for the right kick. What if your phone just knew your crates?"
2. **(0:10) Type the vibe** (outer screen or chip): *"4 bar loop, J Dilla laid-back drums and a killer Nujabes piano sample."*
   → pads fill **instantly**; the loop plays. Point at the lid: `JEV 140 ms`. "TypeSafe's Jev read that in 140 milliseconds and picked a dusty kit and a Freddie Joachim–style piano from *my own* packs. No generation wait."
3. **(0:25) GPT lands on the next bar:** `GPT 3.8 s ✓ walking bass under Am9–Dm9`. "Then GPT-6 composes: a bassline that follows the piano's actual chords, a 4-bar variation. Jev reacts, GPT composes, your crates supply the sound."
4. **(0:35) Unfold to laptop pose:** "Top screen is the lid display, bottom is the deck. It's an MPC Sample, except the MPC can't do any of this." Finger-drum a few pads.
5. **(0:45) KEYS mode:** the 808 across a keyboard, scale-locked to the sample's key; the lid shows the notes. "Both screens working together."
6. **(0:55) Swap drums live:** *"fill up the pads with some house drums"*. Only the drum bank swaps; the loop never stops.
7. **(1:05) The hinge:** slowly fold, the filter closes and reverb swells into a breakdown… **snap it open: DROP.** "The hinge is a punch-in FX. That's only possible on this device."
8. **(1:15) AI PERFORM:** Jev decides a fill every bar (`PERFORM ▸ ROLL`). "It plays with me in real time: 70–500 ms decisions, inside the beat."
9. **(1:25) Close:** "CRATE: your crates, instantly, on the first phone with a hinge."

## Judge Q&A crib
- **Why Duo?** Two screens = a lid display + a deck, like real hardware. The hinge angle is a continuous controller (Apple's own Duo tech talk uses hinge → pitch bend). The outer screen = a pocket sketchpad.
- **Why these models?** Jev returns typed decisions, not text, so it's fast enough for real-time musical decisions and can't hallucinate a format. GPT-6-luna (3.8 s measured) does real composition in the background. Sounds come from local retrieval over a pre-analyzed library (555 one-shots + 77 loops with BPM/key/chords), so it's instant and offline-capable.
- **Is the music generated?** The sounds are the user's own samples (no uncanny AI audio); the *arrangement* (patterns, bass, flips, fills) is AI.
- **Offline?** Yes: keyword parser + groove templates + rule-based bass. Network AI only upgrades it.
- **What's next?** Import any pack from Files, AI stem-splitting of a record straight to pads, resampling, and a real Duo device.
