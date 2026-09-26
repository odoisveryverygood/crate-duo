# Crowd stage integration

`CrowdStageView(state:)` is the audience-facing outer-screen view. The optional
`rotate: Angle` flips its content if the simulator or hardware faces the other
direction. It automatically turns portrait content 90° when given landscape
bounds. `NowPlayingCard(state:)` is reusable in the closed pose.

The lead can replace `CrowdView(state: state)` inside `OuterCrowdHost` with
`CrowdStageView(state: state)`. The app's `project.yml` includes all of `Sources`,
so these files need no project edits.

`AppState` currently has no GPT arrangement title property. The card displays
the current sample label, falling back to the style label. If Core gains a
title property later, use it in `NowPlayingCard.title`.
