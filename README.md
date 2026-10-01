# CRATE

Type a vibe. Play a beat. Fold the drop.

CRATE is an AI-assisted sampler and performance instrument designed for iPhone Duo, built by Aradhya, Mahin, and Steven.

## Try it

- [TestFlight invitation](https://testflight.apple.com/join/NTU9XppA)
- [Demo video](https://www.youtube.com/watch?v=tbkqIPaX97s&t=2s)

## The instrument

Describe a musical vibe, find samples, play the pads, and shape a sequence. Duo display layouts give the performer and audience different views, while hinge movement controls musical effects.

The native app uses Swift and SwiftUI. TypeSafe's Jev and OpenAI support musical decisions and arrangements; local retrieval supplies the samples. RevenueCat supports CRATE PRO offerings, purchases, restores, and the `pro` entitlement.

## Source and setup

This repository is a public source copy of [Shuhan-Zhang/crate-duo](https://github.com/Shuhan-Zhang/crate-duo), prepared for RevenueCat Shipaton. The original commit history and contributor attribution are preserved. The public branch is `codex/shipaton-public`.

See [BUILD.md](BUILD.md) and [project.yml](project.yml) for the build configuration. The current source targets iOS 27.1 and uses Duo-specific APIs. The TestFlight build's supported devices are determined by its invitation.

API credentials are not included. `Config/Base.xcconfig` optionally loads the ignored `Secrets.xcconfig`; configure your own credentials locally. See [RevenueCat setup](Sources/Paywall/README.md) for offerings and entitlement requirements. Source integration alone does not verify a completed purchase.

## Main components

- `Sources/Core`: audio and application state
- `Sources/AI`: musical intent and orchestration
- `Sources/Library`: sample discovery and retrieval
- `Sources/UI`: performer controls
- `Sources/Crowd`: audience display
- `Sources/Paywall`: RevenueCat subscription flow
- `Resources`: bundled sounds, projects, fonts, and app icon
