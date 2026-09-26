#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
flags=(-sdk "$sdk" -target arm64-apple-ios27.1-simulator -swift-version 5)
# Compile with no SDK dependency, as in the unmodified lead project.
xcrun swiftc -typecheck "${flags[@]}" Sources/Core/*.swift Sources/Paywall/*.swift
# API-surface stubs: compile checks only, never included in the app or used to
# claim a real purchase. Signatures checked against purchases-ios 5.39.0.
cat > "$tmp/RevenueCat.swift" <<'SWIFT'
import Foundation
public struct EntitlementInfo { public let isActive: Bool }
public struct CustomerInfo { public let entitlements: [String: EntitlementInfo] }
public struct Package {}
public struct Offering { public let availablePackages: [Package] }
public struct Offerings { public let current: Offering? }
public final class Purchases {
    public static var isConfigured: Bool { false }
    public static let shared = Purchases()
    @discardableResult public static func configure(withAPIKey: String) -> Purchases { shared }
    public func customerInfo() async throws -> CustomerInfo { fatalError("typecheck only") }
    public func offerings() async throws -> Offerings { fatalError("typecheck only") }
}
SWIFT
cat > "$tmp/RevenueCatUI.swift" <<'SWIFT'
import SwiftUI
import RevenueCat
public struct PaywallView: View {
    public init(offering: Offering, displayCloseButton: Bool) {}
    public var body: some View { EmptyView() }
}
extension View {
    public func onPurchaseCompleted(_ handler: @escaping @MainActor @Sendable (CustomerInfo) -> Void) -> some View { self }
    public func onRestoreCompleted(_ handler: @escaping @MainActor @Sendable (CustomerInfo) -> Void) -> some View { self }
}
SWIFT
xcrun swiftc "${flags[@]}" -emit-module -module-name RevenueCat "$tmp/RevenueCat.swift" -emit-module-path "$tmp/RevenueCat.swiftmodule"
xcrun swiftc "${flags[@]}" -I "$tmp" -emit-module -module-name RevenueCatUI "$tmp/RevenueCatUI.swift" -emit-module-path "$tmp/RevenueCatUI.swiftmodule"
xcrun swiftc -typecheck "${flags[@]}" -I "$tmp" Sources/Core/*.swift Sources/Paywall/*.swift
cp Sources/Paywall/Verification/AllowanceChecks.swift.txt "$tmp/main.swift"
xcrun swiftc -swift-version 5 Sources/Core/*.swift Sources/Paywall/DigAllowance.swift "$tmp/main.swift" -o "$tmp/checks"
"$tmp/checks"
echo 'PASS: iOS 27.1 typecheck (without SDK and with RevenueCat stubs)'
