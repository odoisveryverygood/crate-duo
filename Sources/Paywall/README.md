# WP1 · CRATE PRO

Drop-in `.paywallGate(state:)` for the stable performer root. All implementation and verification files stay in `Sources/Paywall/`; the lead owns integration elsewhere.

## Behavior

- Counts one timed `JEV`/`KW` plan log per accepted DIG. The separate `JEV` timeout diagnostic has no `ms` and does not count. Superseded requests that never log a plan do not count; a plan that later fails to load audio does count. FLIP and other scopes submitted through the DIG orchestrator count too.
- After the third plan, waits for `state.isDigging` to become false, checks RevenueCat customer info, then loads the current offering and presents `RevenueCatUI.PaywallView` unless entitlement `pro` is active. Existing subscribers are checked before any purchase UI is shown.
- A local, installation-wide allowance survives launches. Recent plan IDs prevent recounting on view recreation and cope with the rolling 40-line log. Attach the modifier **once**, outside pose changes; do not also attach it to the audience display.
- Purchase and restore callbacks dismiss only when `pro` is active. RevenueCat's paywall owns transaction UI and errors. A restore without `pro` keeps the sheet open with an explanation.
- Close/swipe dismisses the sheet; the next DIG checks again. This is the requested upgrade prompt, not hard enforcement of DIG/PERFORM/crowd-screen access. Audio keeps playing. Strict feature enforcement would need changes in lead-owned action paths.
- Missing SDK/key/offering or customer-info failure shows an unavailable/retry message. It never grants an entitlement or pretends a transaction succeeded. No RevenueCat calls occur before the threshold.

## Lead integration

Merge these root-level XcodeGen package lines into `project.yml` (5.39.0 is the verified API baseline):

```yaml
packages:
  RevenueCat:
    url: https://github.com/RevenueCat/purchases-ios.git
    exactVersion: 5.39.0
```

Add dependencies under the existing `targets.Crate` entry:

```yaml
    dependencies:
      - package: RevenueCat
        product: RevenueCat
      - package: RevenueCat
        product: RevenueCatUI
```

Keep the existing `Sources` entry and exclude the verification assets:

```yaml
    sources:
      - path: Sources
        excludes:
          - Paywall/Verification
      # retain existing resource entries
```

In the existing, gitignored `Config/Secrets.xcconfig`, set the RevenueCat **public iOS SDK key** (not a secret REST API key):

```xcconfig
REVENUECAT_API_KEY = <public iOS SDK key>
```

`Config/Base.xcconfig` already includes this file. Add this entry to `Resources/Info.plist` so `AppConfig` can read the build setting:

```xml
<key>REVENUECAT_API_KEY</key>
<string>$(REVENUECAT_API_KEY)</string>
```

At the stable performer root, using the existing `AppState`:

```swift
RootView(state: state, hinge: hinge)
    .paywallGate(state: state)
```

Retain the existing URL and appearance modifiers. Run `xcodegen generate` after changing package configuration. Configuration is lazy and reuses `Purchases.shared` if the lead already configured it.

In RevenueCat/App Store Connect, the account owner must configure the matching app, subscription product, current offering containing a package, and entitlement named **`pro`** attached to that product. Configure the paywall's purchase/restore controls, terms and privacy links. No dashboard or store configuration was performed in this branch.

## Verification

Run from the repository root:

```sh
bash Sources/Paywall/Verification/check.sh
```

Uses `/Applications/Xcode.app/Contents/Developer` by default; override `DEVELOPER_DIR` if needed. It does not run `xcodebuild`, change the lead project, read keys, or make purchases. Temporary stub modules and test binaries are deleted on exit.

Verified locally with Xcode 27.1:

- **PASS:** Core + Paywall iOS 27.1 simulator typecheck, with SDK imports absent.
- **PASS:** same typecheck with temporary RevenueCat/RevenueCatUI API-surface stubs matching the used 5.39.0 signatures.
- **PASS:** executable allowance checks for the third-DIG threshold, timeout filtering, zero-ms keyword parsing, repeated observations, log truncation, view recreation and restart persistence.
- **Not verified:** linking the actual RevenueCat package, rendering in the running Duo app, dashboard setup, StoreKit sandbox purchases/restores. Stub checks are compile evidence only.

After lead integration, verify with a StoreKit sandbox account:

1. Fresh installation: DIGs 1–2 show no sheet; DIG 3 shows CRATE PRO after loading finishes.
2. Cancel/close: performance continues; the next DIG offers the paywall again.
3. Purchase `pro`: the sheet dismisses; subsequent DIGs do not show it, including after relaunch.
4. Restore with `pro`: dismiss; restore without `pro`: remain open with explanation.
5. Existing subscriber on a fresh install: no paywall at the threshold.
6. Missing key/offering and offline customer-info failure: unavailable/retry, no fake success. Failed/cancelled purchases retain the paywall.
7. Rotate/change Duo poses and verify only the performer root presents one sheet.

For a development-only reset, remove `crate.paywall.digCount.v1` and `crate.paywall.seenPlans.v1` from the app's UserDefaults or reinstall. This local allowance is not tamper-proof billing enforcement.

API references: [displaying paywalls](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls), [customer info](https://www.revenuecat.com/docs/customers/customer-info), [5.39.0 PaywallView](https://github.com/RevenueCat/purchases-ios/blob/5.39.0/RevenueCatUI/PaywallView.swift), [purchase/restore callbacks](https://github.com/RevenueCat/purchases-ios/blob/5.39.0/RevenueCatUI/View%2BPurchaseRestoreCompleted.swift).
