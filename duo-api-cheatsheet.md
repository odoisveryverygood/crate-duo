# iPhone Duo Developer Cheat Sheet — Bitrig Hacks (2026-09-25)

Confidence key: **[A]** = confirmed from an Apple-owned source (developer.apple.com, apple.com/newsroom) or a verbatim Tech Talk transcript. **[T]** = confirmed from third-party but reputable technical coverage (MacRumors, SwiftLee, swiftjective-c, Bitrig blog) — treat as very likely accurate but not primary-source. **[U]** = unverified / could not confirm from a primary source — do NOT trust the exact spelling, only the concept.

I did not invent any API name below. Where two sources disagreed slightly (e.g. exact aspect-ratio math), I noted both.

---

## 1. Device facts

| Fact | Value | Confidence |
|---|---|---|
| Outer display | 5.4" Super Retina XDR, ~1398×2034 px, ~460 ppi | [T] (macobserver breakdown of Apple's numbers; Apple newsroom itself only gives inches, "90% of iPhone 18 Pro screen area") |
| Inner display | 7.6" Super Retina XDR (folding), ~1878×2670 px, ~430 ppi | [T]/[A] size in inches from apple.com newsroom [A]; pixel numbers from secondary sites [T] |
| Aspect ratio | Apple states both displays share the same aspect ratio; third-party pixel math gives ~1.42 (inner) vs ~1.455 (outer) — small discrepancy, likely rounding | [A] (Apple's claim) / [T] (math) |
| Shared display features | ProMotion, Always-On, 3000 nits peak outdoor brightness; inner also has nano-texture finish option | [A] apple.com/newsroom |
| "1.42 problem" | Inner display's aspect ratio (~√2) is bad for 16:9 video (letterboxes ~1/5 of the screen) but great for two-pane/document layouts | [T] blakecrosley.com |
| Hinge | Precision hinge, "100+ components," integrated magnet array, support ribs, antenna ceramic-fiber inserts, titanium plate under the folding panel; located at the vertical center of the inner display, dividing it into two halves when folded | [A] apple.com/newsroom |
| Cameras (rear, shared) | 48MP Fusion Main (2x optical tele) + 48MP Fusion Ultra Wide; sensor-shift OIS, macro, zero shutter lag; 4K120 Dolby Vision | [A] apple.com/newsroom |
| Front cameras | Center Stage front camera (auto-orientation) + a second FaceTime camera hidden beneath the inner display (only visible/active when in use) | [A] apple.com/newsroom |
| Biometrics | **Touch ID, not Face ID** — apps with hardcoded "Use Face ID" strings/logic must branch on `biometryType` | [T] blakecrosley.com, swiftjectivec |
| Poses / fold states | **Closed** (outer display active, pocketable) · **Open/flat** (full inner display, "thinnest iPhone ever") · **Partially folded like a book** (portrait, hinge splits inner display left/right) · **Propped up like a tent** (top region for glanceable content, bottom region for touch controls) · **Laptop-like, sitting on a table** | [A] Tech Talks "Strike a Pose" + "Raise the Bar" transcripts, and Bitrig's simulator description (laptop/tent/folded) [T] |
| Release | Announced Sept 9, 2026; preorders Oct 16, 2026; ships Oct 23, 2026 (70+ countries), Oct 30 (28 more); from $1,999 (256GB–2TB) | [A] apple.com/newsroom |
| iOS version | iOS 27.1 (ships with the device; iOS 27 alone does NOT give full-screen/vertical-bar support — see SDK tiers below) | [A] |

**SDK tiers — important gotcha [A] (Prepare your app for iPhone Duo talk):**

| App built with | Behavior on Duo |
|---|---|
| Pre-iOS 27 SDK | Runs in compatibility box; on closed device uses space left of status bar/camera |
| iOS 27 SDK | Extends left of the status bar area on inner display |
| iOS 27.1 SDK | Extends to true screen edge; vertical nav/toolbar layout activates |

---

## 2. APIs — exact names, signatures, and verbatim example code

All code below is quoted from Apple's own Tech Talk transcripts (developer.apple.com/videos/play/tech-talks/111461–111464) unless marked otherwise. I could not fetch the raw DocC JSON for the reference pages (they require JS and my scraper couldn't get through), so I'm relying on the transcripts + secondary confirmations for exact spelling — flagged per item.

### 2.1 Hinge — `onHingeChange` / `UIHingeInteraction` [A]

- SwiftUI: `.onHingeChange { previous, context in ... }` — modifier takes a closure with **previous** and **current** hinge context.
- `context.hinge` is optional (`DeviceHinge?`) — **nil on devices without a hinge**, so always `if let`.
- `hinge.status` — cases confirmed: `.closed`, `.partiallyOpen`, `.fullyOpen`.
- `hinge.angle` — an `Angle` (used directly in `calculatePitchBend(angle: Angle)` in Apple's example — so it's the SwiftUI `Angle` type, not a raw Double). One third-party source (Flutter issue referencing Apple docs) links to `developer.apple.com/documentation/swiftui/devicehinge/angle`, confirming the type is called `DeviceHinge`.
- UIKit equivalent: `UIHingeInteraction` (delivers angle in radians per ecorpit.com [T], unconfirmed from Apple primary text but plausible).
- **Explicit Apple guidance: hinge data is for interactions/effects (e.g. pitch bend), NOT layout.** For layout use Arrangement + Reserved Region APIs instead.

Verbatim Apple example (from "Leverage multiple displays and scenes on iPhone Duo"):

```swift
struct InstrumentView: View {
    /// Normalized bend, 0 is no bend, 1 is deepest bend
    @State private var pitchBend: Double = 0

    var body: some View {
        GuitarView(pitchBend: pitchBend)
            .onHingeChange { _, context in
                if let hinge = context.hinge, hinge.status == .partiallyOpen {
                    pitchBend = calculatePitchBend(angle: hinge.angle)
                }
                else {
                    pitchBend = 0
                }
            }
    }

    private func calculatePitchBend(angle: Angle) -> Double { ... }
}
```

### 2.2 Reserved regions (`.division`, `.occlusion`) [A]

SwiftUI: query via `GeometryProxy.reservedRegions(kind:options:)` inside a `GeometryReader` (or `onGeometryChange`). UIKit: `UIView.reservedRegions(kind:)`.

- `.division` — backs the fold; **active only when folded**, width 0 when flat (still queryable via `.includeInactive` for coarse decisions like "prefer even column counts").
- `.occlusion` — backs camera cutouts (e.g. the inner FaceTime camera); active only while that camera is in use.
- Each region has a `.frame` you read to lay out around it.

Verbatim:

```swift
// SwiftUI
GeometryReader { proxy in
  let regions = proxy.reservedRegions(
    kind: .division)
}
```
```swift
// UIKit
let regions = view.reservedRegions(
  kind: .division)
let frames = regions.map(\.frame)
```
```swift
// Include inactive regions
GeometryReader { proxy in
  let regions = proxy.reservedRegions(
    kind: .division, options: .includeInactive)
  let frames = regions.map(\.frame)
}
```
```swift
// Occlusion (camera) regions
GeometryReader { proxy in
  let regions = proxy.reservedRegions(
    kind: .occlusion)
  let frames = regions.map(\.frame)
}
```

For UIKit, the parallel type name is **`UIViewReservedRegion`** per the "Prepare your app" transcript [A].

### 2.3 `ArrangementView` (SwiftUI) / `UIArrangementViewController` (UIKit) [A]

Layout container between navigation containers and content containers. Takes a **primary** and **secondary** view. Two built-in styles: `.split` and `.overlay`. **Does not provide navigation — never nest a `NavigationSplitView` inside it, and never put an `ArrangementView` inside a `List`/`ScrollView`.**

```swift
// SwiftUI — basic
var body: some View {
  NavigationStack {
    ArrangementView {
      PlayerView()
    } secondary: {
      UpNextView()
    }
  }
}
```
```swift
// UIKit — basic
let arrangementVC = UIArrangementViewController()
let navController = UINavigationController(rootViewController: arrangementVC)

let playerVC = PlayerViewController()
arrangementVC.setViewController(playerVC, for: .primary)

let upNextVC = UpNextViewController()
arrangementVC.setViewController(upNextVC, for: .secondary)
```
```swift
// Specify split style, restricted to one axis
var body: some View {
  NavigationStack {
    ArrangementView {
      PlayerView()
    } secondary: {
      UpNextView()
    }
    .arrangementViewStyle(
      .split.axes(.horizontal))
  }
}
```
```swift
// UIKit equivalent
let arrangementVC = UIArrangementViewController()
arrangementVC.updateArrangement(.split.axes(.horizontal))
```
```swift
// Switch to overlay style
var body: some View {
  NavigationStack {
    ArrangementView {
      UpNextView()
    } secondary: {
      PlayerView()
    }
    .arrangementViewStyle(.overlay)
  }
}
```
```swift
// Read the overlay z-index (SwiftUI environment key)
enum UpNextMinimization { case collapsed; case expanded }

struct UpNextView: View {
  @Environment(\.overlayArrangementZIndex)
  private var zIndex: Int

  var body: some View { UpNextList(minimization: minimization) }

  var minimization: UpNextMinimization {
    zIndex > 0 ? .collapsed : .expanded
  }
}
```
```swift
// UIKit equivalent
let primaryState = arrangementVC.state(for: .primary)
myModel.minimization = (primaryState?.zIndex ?? 0) > 0
  ? .collapsed : .expanded
```

Selection heuristic straight from Apple: if you already use `HStack`/`VStack` → use `.split`; if you already use `ZStack` → use `.overlay`. Use `.overlay` when there's a clear foreground/background relationship (occlusion is OK); use `.split` when both views must always stay fully visible (main/detail).

**Behavior note [T, ecorpit]:** restricting `.split` to one `.axes()` can cause the arrangement to *silently hide* the secondary view entirely if that axis can't fit both — a deliberate product decision Apple flags, not a bug.

### 2.4 Size classes per pose [A]

Read the same way as always:

```swift
// SwiftUI
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@Environment(\.verticalSizeClass) private var verticalSizeClass

// UIKit
traitCollection.horizontalSizeClass
traitCollection.verticalSizeClass
```

- **Outer display**: portrait = compact-horizontal / regular-vertical (like any iPhone); landscape = compact/compact.
- **Inner display**: **regular-horizontal / regular-vertical** — new combination never seen on iPhone before. Inner display does **not** honor your `UISupportedInterfaceOrientations` — don't branch on interface orientation, use size classes instead.
- Never reference `UIScreen.main` (ambiguous with two displays, will be deprecated) — get the screen dynamically: `let screen = window?.windowScene?.screen`. Similarly replace `UIScreen.main.scale` with `traitCollection.displayScale`.

### 2.5 Vertical toolbars — `toolbarVerticalBehavior` family [A]

From "Raise the Bar with iPhone Duo." Confirmed exact names:

- `.toolbarVerticalBehavior(.disabled)` (SwiftUI) / `override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }` (UIKit) — opt a view/VC out of vertical bar layout entirely.
- `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` (SwiftUI) / `navigationItem.verticalBarCompressionBehavior = .prefersBarItems` (UIKit) — controls whether the toolbar or the tab bar compresses first when space is tight.
- `.axisBehavior(.verticalPreferred)` / `.axisBehavior(.horizontalOnly)` on a `ToolbarItem`, or `item.axisBehavior = ...` in UIKit — controls whether a custom toolbar item/view is allowed onto the vertical axis.
- `ToolbarOverflowMenu { ... }` (SwiftUI) / `navigationItem.additionalOverflowItems = UIDeferredMenuElement {...}` (UIKit) — consolidate your own overflow UI into the system-managed overflow menu.
- `.visibilityPriority(.high)` on a `ToolbarItem` / `item.visibilityPriority` (UIKit) — controls collapse order into overflow (default: bottom-to-top).
- `@Environment(\.toolbarVerticalEdge)` (SwiftUI) / `traitCollection.verticalBarEdge` (UIKit) — tells a custom view which edge the vertical bar is on (nil/unspecified if not vertical).
- Placements: `.cancellationAction` (back/close), `.topBarPinnedTrailing` (SwiftUI) / `pinnedTrailingGroup` (UIKit) for prominent pinned actions.
- Badges: `.badge(7)` (SwiftUI) / `item.badge = .count(7)` (UIKit) — prefer symbol+badge over title+symbol so items can go vertical.

```swift
// Disable vertical bar for a view
var body: some View {
    NavigationStack {
        ContentView()
            .toolbarVerticalBehavior(.disabled)
    }
}
```
```swift
// Configure toolbar-vs-tab-bar compression preference
var body: some View {
    TabView {
        Tab("Recents", systemImage: "clock") {
            ContentView()
                .toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        }
    }
}
```
```swift
// System overflow menu
var body: some View {
    ContentView()
        .toolbar {
            ToolbarOverflowMenu {
                Button("Scan") { ... }
                Button("Connect") { ... }
            }
        }
}
```
```swift
// Custom view allowed onto vertical axis
var body: some View {
    ContentView()
        .toolbar {
            ToolbarItem { CompassView() }
                .axisBehavior(.verticalPreferred)
        }
}
```

Rule of thumb: build bars via `NavigationStack`/`NavigationSplitView`/`TabView` toolbar modifiers (SwiftUI) or `UINavigationController`/`UITabBarController` (UIKit) — a bare custom `UIToolbar`/`UINavigationBar`/`UITabBar` instance is **not** considered for vertical layout at all.

### 2.6 Multi-scene / multi-window, and putting different content on each display [A]

- iPhone Duo is the first iPhone that supports **multiple instances of your app's UI** (same rules as iPad) and **Split View multitasking** (two different apps side by side — first for iPhone).
- **New windows can only be created on the inner display** — the outer display cannot spawn new scenes. Handle failures with `UIWindowSceneActivationAction`/`UIWindowScene.ActivationAction` (hides itself automatically when unavailable).
- **Scene accessories** (`sceneAccessory` modifier) let a scene put extra UI on a *second* display while its main UI stays on the first — this is the actual "different content on each display" mechanism, distinct from opening a second window.
  - `CameraCaptureAccessory` — the Duo-specific accessory: shows extra UI (e.g. a subject-facing preview or teleprompter) on the **outer** display while your camera app's main UI is full-screen on the **inner** display. Requires the app be full-screen on the inner display with an active camera session.
  - `.onAvailabilityChange { newValue in ... }` on the accessory — availability toggles dynamically (e.g. when device is closed) — always observe it via **observation tracking** rather than assuming it's constant.

```swift
// Register a camera capture accessory, wire up enable + availability
struct CameraRootView: View {
    @State private var model = TeleprompterModel()

    var body: some View {
        CameraView(model: model)
            .sceneAccessory {
                CameraCaptureAccessory(isEnabled: $model.isEnabled) {
                    TeleprompterView(model: model)
                }
                .onAvailabilityChange { newValue in
                    model.isAvailable = newValue
                }
            }
            .toolbar {
                TeleprompterToggle(isEnabled: $model.isEnabled)
                    .disabled(!model.isAvailable)
            }
    }
}
```

### 2.7 `ConcentricRectangle` [A]

Introduced in iOS 26, **updated to work with Duo's screen shapes** so your corner radii match the physical screen corners on either display:

```swift
// SwiftUI
ConcentricRectangle()
    .fill(Color.green)
    .padding(8.0)
    .ignoresSafeArea()

// UIKit equivalent: UICornerConfiguration
```

### 2.8 StandBy [A/T]

- StandBy can now trigger just by setting the device down on **either display face-up, without being plugged into power** (new vs iPhone/iPad StandBy which needs power). New Calendar and Weather faces added alongside Clock/Modular; Photos face can show Shared Albums.
- **Gotcha [T, swiftjectivec/blakecrosley]: StandBy is not available in the Device Hub simulator runtime** — you can only really test it on hardware.
- I could not find a distinct public StandBy *developer API* beyond the existing StandBy widget/Lock Screen APIs — treat any specific new StandBy API name as **[U]** unless you find it yourself in the 27.1 docs.

---

## 3. Simulator (Xcode 27.1 / Device Hub)

- **[A]** Download Xcode 27.1 (beta). In Settings → Components, install/update the iOS 27.1 platform if needed. iPhone Duo then appears as a normal run destination inside **Device Hub**.
- **[A]** Bottom-of-screen control buttons let you open, close, rotate, and fold the device; drag with the home-indicator area to test Split View multitasking (drag app to one side, drop zone appears, drag second app to other side).
- **[T, avanderlee]** Hold **Option (⌥)** while interacting with the simulator to reveal a **slider for precise hinge-angle control**, instead of just discrete open/closed/folded clicks.
- **[T, Bitrig blog]** Bitrig's own third-party 3D simulator (separate product, not Apple's) supports the same pose set — laptop, tent, folded shut, plus portrait/landscape partial-fold — and streams live hinge data as you drag it; useful for demos but it's not Apple's Device Hub.
- **Known simulator limitations [T, multiple sources — avanderlee, ecorpit, swiftjectivec]:**
  - No real camera hardware — camera views launch empty; can't test camera transitions between inner/outer/rear cameras or direction-aware switching.
  - No haptics.
  - No StandBy runtime.
  - Cannot validate real touch reachability in partially folded poses, thermal behavior, or performance/memory characteristics.
  - Good for: layout, safe areas, vertical toolbars, hinge-angle-driven interactions, Split View drag-and-drop testing, error-handling code paths.
- **[T, blakecrosley]** Version trap: only **Xcode 27.1** has the Duo SDK — the Xcode 27 GA/RC releases and even the (higher-numbered but unrelated) Xcode 27.2 beta reportedly do **not** include it. Double check your installed toolchain before the hackathon.

---

## 4. Minimal SwiftUI sample app skeleton

This composes only APIs verified above (`ArrangementView`, `.arrangementViewStyle`, `reservedRegions`, `.onHingeChange`, size classes). It shows content A on top / content B on bottom when partially folded like a laptop, and reacts to hinge angle for a visual effect. I have **not** run this in Xcode 27.1 — verify at the hackathon; the parts marked [A] above (the modifiers/types) are attested but this exact combination is my own composition, not copied from a single Apple sample.

```swift
import SwiftUI

@main
struct DuoDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    // Continuous hinge angle drives a purely cosmetic effect (per Apple's
    // guidance: hinge data is for interactions/effects, not layout).
    @State private var hingeTilt: Double = 0

    var body: some View {
        NavigationStack {
            ArrangementView {
                ContentAView()      // primary: e.g. video / camera preview
            } secondary: {
                ContentBView()      // secondary: e.g. controls / chat / notes
            }
            .arrangementViewStyle(.split.axes(.vertical))
            // .split with a vertical axis puts primary above secondary when
            // the device is folded like a laptop (regions stacked, not
            // side-by-side). Swap to .axes(.horizontal) for a book-style
            // left/right split instead.
            .onHingeChange { _, context in
                if let hinge = context.hinge, hinge.status == .partiallyOpen {
                    hingeTilt = normalizedTilt(from: hinge.angle)
                } else {
                    hingeTilt = 0
                }
            }
            .rotation3DEffect(.degrees(hingeTilt * 5), axis: (x: 1, y: 0, z: 0))
            .toolbar {
                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("Sync") { }
                }
            }
        }
    }

    private func normalizedTilt(from angle: Angle) -> Double {
        // Map hinge angle (0...180) to a 0...1 range for the cosmetic tilt.
        min(max(angle.degrees / 180.0, 0), 1)
    }
}

struct ContentAView: View {
    var body: some View {
        GeometryReader { proxy in
            let division = proxy.reservedRegions(kind: .division)
            ZStack {
                Color.blue.opacity(0.15).ignoresSafeArea()
                Text("Content A (top / primary)")
                // Keep controls clear of the fold by insetting from the
                // division region's frame if present.
                    .padding(.bottom, division.first != nil ? 24 : 0)
            }
        }
    }
}

struct ContentBView: View {
    var body: some View {
        ZStack {
            Color.green.opacity(0.15).ignoresSafeArea()
            Text("Content B (bottom / secondary)")
        }
    }
}
```

Notes on the skeleton:
- Using `.split.axes(.vertical)` is my inference for "stack A above B in laptop pose" from Apple's statement that `.split` defaults to horizontal-when-wider-than-tall and lets you force an axis with `.axes(...)`; I did **not** find a transcript example that explicitly restricts to `.vertical` — verify the exact stacking direction on the Device Hub before you rely on it. **[U]** for that specific detail, everything else in the API surface is **[A]**.
- Reserved-region usage here is illustrative; real apps should also handle `.occlusion` (camera) regions per section 2.2.

---

## 5. Gotchas checklist (quick scan before you code)

1. **Touch ID, not Face ID** — check `biometryType`, don't hardcode Face ID strings/UI. [T]
2. **Rebuild with iOS 27.1 SDK**, not just 27, to get full-screen + vertical bars. Xcode 27 GA and the unrelated 27.2 beta reportedly lack the Duo SDK — use Xcode 27.1 specifically. [A]/[T]
3. Don't reference `UIScreen.main` — get the screen from `window?.windowScene?.screen`; use `traitCollection.displayScale` not `UIScreen.main.scale`. [A]
4. Don't branch on interface orientation on the inner display — it doesn't honor supported orientations; use size classes. [A]
5. New windows/scenes can only be created from the **inner** display, not the outer one. [A]
6. Hinge angle/status (`onHingeChange`) is for interactions/effects only — use `reservedRegions` + `ArrangementView` for actual layout decisions. [A]
7. Don't nest `NavigationSplitView` inside `ArrangementView`; don't put `ArrangementView` inside `List`/`ScrollView` — these are layout bugs, not compile errors. [A]
8. Safe-area insets are **asymmetric** (vertical bar can be on either the left or right depending on Split View placement/RTL) — never assume opposite-side insets are equal; compute each side independently. [A]
9. Custom `UIToolbar`/`UINavigationBar`/`UITabBar` instances are ignored for vertical bar layout — must use `UINavigationController`/`UITabBarController` or SwiftUI's container `.toolbar`. [A]
10. Simulator can't test cameras, haptics, StandBy, thermal/performance, or real touch reachability — budget real-device time if your hack depends on any of those. [T]
11. `.division` reserved region has zero width/is inactive when the device is flat — query `.includeInactive` if you need to make layout decisions ahead of an actual fold (e.g., choosing grid column parity). [A]
12. The inner display's aspect ratio (~1.42, near √2) is bad for 16:9 video (letterboxing) but good for two-pane/document UIs — plan your content type accordingly. [T]

---

## 6. Sources

**Apple (primary):**
- https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/ — device facts, cameras, release dates, pricing
- https://developer.apple.com/iphone-duo/ — dev hub landing page, links to all sessions
- https://developer.apple.com/videos/play/tech-talks/111461/ — "Prepare your app for iPhone Duo" (size classes, safe areas, reserved regions intro, screen references, Concentricity, Device Hub basics)
- https://developer.apple.com/videos/play/tech-talks/111462/ — "Raise the Bar with iPhone Duo" (vertical toolbar API family, axisBehavior, overflow, badges)
- https://developer.apple.com/videos/play/tech-talks/111463/ — "Strike a Pose with Adaptive Layouts on iPhone Duo" (reserved regions .division/.occlusion, ArrangementView deep dive, displacement patterns)
- https://developer.apple.com/videos/play/tech-talks/111464/ — "Leverage multiple displays and scenes on iPhone Duo" (onHingeChange, split-view multitasking, scene accessories, CameraCaptureAccessory)
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo — HIG page (could not scrape full text — requires JS rendering; not independently verified beyond title)
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo — overview doc (same scraping limitation)
- https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:) and .../swiftui/devicehinge/angle — referenced by the Flutter issue below; I could not render the DocC page content itself, so the exact `DeviceHinge` type name is corroborated only via that secondary reference, not read directly. **[T, not A, for the type name specifically.]**

**Third-party (secondary, used for simulator/gotcha details and cross-checks):**
- https://bitrig.com/blog/iphone-duo-app-development
- https://www.avanderlee.com/swiftui/iphone-duo-simulator/ — Device Hub launch steps, Option-key hinge slider, limitations
- https://www.swiftjectivec.com/iphone-duo-first-developer-good-to-knows/
- https://blakecrosley.com/blog/iphone-duo-for-developers — "1.42 problem," SDK gap/version tiers, gotchas
- https://ecorpit.com/iphone-duo-sdk-new-apis-xcode-27-1-developer-guide-2026/
- https://ecorpit.com/iphone-duo-adaptive-layout-arrangementview-reserved-regions-2026/
- https://www.macrumors.com/2026/09/10/apple-details-how-ios-27-adapts-to-iphone-duo/
- https://github.com/flutter/flutter/issues/193054 — cross-check for `onHingeChange`/`DeviceHinge` naming
- https://gist.github.com/frankschlegel/6356a059426b2393528691822edfdae6 — consolidated Group Lab Q&A (Touch ID note, size classes, ArrangementView notes)
- https://www.macobserver.com/tips/round-ups/iphone-duo-display-resolutions-explained-1878-x-2670-inside-1398-x-2034-outside-aspect-rat/ and https://www.whatismyscreensize.com/device/iphone-duo — pixel-resolution figures (Apple itself only states inches)

**Not independently verified — treat as [U] if you see it elsewhere:** any specific StandBy *developer* API name beyond existing StandBy/widget APIs; exact UIKit hinge-angle unit (radians) — plausible but only sourced from ecorpit, not an Apple transcript; the precise stacking axis for "laptop pose" in `ArrangementView` (my sample code's `.axes(.vertical)` choice is inference, not a quoted Apple example).
