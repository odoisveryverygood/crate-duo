import SwiftUI
import Observation
#if canImport(RevenueCat) && canImport(RevenueCatUI)
import RevenueCat
import RevenueCatUI
#endif

@MainActor
@Observable
final class CratePaywall {
    var isPresented = false
    var message: String?
    private(set) var isChecking = false
    @ObservationIgnored private let allowance: DigAllowance
    @ObservationIgnored private var pending = false
    #if canImport(RevenueCat) && canImport(RevenueCatUI)
    var offering: Offering?
    #endif

    init(defaults: UserDefaults = .standard) {
        allowance = DigAllowance(defaults: defaults)
    }

    func observe(_ log: [LogLine]) {
        if allowance.consume(log) { pending = true }
    }

    func presentIfNeeded(isDigging: Bool) async {
        guard pending, !isDigging, !isChecking, !isPresented else { return }
        pending = false
        isChecking = true
        defer { isChecking = false }
        #if canImport(RevenueCat) && canImport(RevenueCatUI)
        do {
            guard configure() else {
                message = "CRATE PRO is not available yet. Please try again later."
                isPresented = true
                return
            }
            let info = try await Purchases.shared.customerInfo()
            guard !Task.isCancelled else { pending = true; return }
            guard info.entitlements["pro"]?.isActive != true else { return }
            let current = try await Purchases.shared.offerings().current
            guard !Task.isCancelled else { pending = true; return }
            guard let current, !current.availablePackages.isEmpty else {
                offering = nil
                message = "CRATE PRO is not available yet. Please try again later."
                isPresented = true
                return
            }
            offering = current
            message = nil
            isPresented = true
        } catch {
            guard !Task.isCancelled else { pending = true; return }
            offering = nil
            message = "We couldn’t load CRATE PRO. Check your connection and try again."
            isPresented = true
        }
        #else
        message = "CRATE PRO is not available in this build."
        isPresented = true
        #endif
    }

    func retry() async {
        isPresented = false
        pending = true
        await presentIfNeeded(isDigging: false)
    }

    #if canImport(RevenueCat) && canImport(RevenueCatUI)
    private func configure() -> Bool {
        if Purchases.isConfigured { return true }
        guard let key = AppConfig.string("REVENUECAT_API_KEY")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return false }
        Purchases.configure(withAPIKey: key)
        return true
    }

    func completed(_ info: CustomerInfo) {
        if info.entitlements["pro"]?.isActive == true {
            pending = false
            isPresented = false
        } else {
            message = "No active CRATE PRO subscription was found for this account."
        }
    }
    #endif
}

@MainActor
private struct PaywallGateModifier: ViewModifier {
    let state: AppState
    @State private var gate = CratePaywall()

    func body(content: Content) -> some View {
        @Bindable var gate = gate
        content
            .onChange(of: ObservationKey(ids: state.log.map(\.id), digging: state.isDigging), initial: true) { _, _ in
                gate.observe(state.log)
                Task { await gate.presentIfNeeded(isDigging: state.isDigging) }
            }
            .sheet(isPresented: $gate.isPresented) {
                CrateProSheet(gate: gate)
            }
    }

    private struct ObservationKey: Equatable {
        let ids: [UUID]
        let digging: Bool
    }
}

extension View {
    /// Attach once to the stable performer root, outside the Duo pose branches.
    @MainActor
    func paywallGate(state: AppState) -> some View {
        modifier(PaywallGateModifier(state: state))
    }
}

@MainActor
private struct CrateProSheet: View {
    let gate: CratePaywall
    private let orange = Color(red: 250 / 255, green: 91 / 255, blue: 28 / 255)

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("CRATE PRO")
                    .font(.custom("Doto-Black", size: 32, relativeTo: .title))
                    .foregroundStyle(orange)
                Spacer()
                Button("Close") { gate.isPresented = false }
                    .accessibilityLabel("Close CRATE PRO")
            }
            Text("unlimited digs, AI PERFORM, crowd screen")
                .font(.custom("SpaceMono-Bold", size: 13, relativeTo: .subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let message = gate.message {
                Text(message).multilineTextAlignment(.center)
                Button("Try again") { Task { await gate.retry() } }
                    .disabled(gate.isChecking)
            }
            #if canImport(RevenueCat) && canImport(RevenueCatUI)
            if let offering = gate.offering {
                PaywallView(offering: offering, displayCloseButton: false)
                    .onPurchaseCompleted { info in gate.completed(info) }
                    .onRestoreCompleted { info in gate.completed(info) }
            } else {
                Spacer()
            }
            #else
            Spacer()
            #endif
        }
        .padding(20)
        .background(Color.black)
        .foregroundStyle(Color.white)
        .tint(orange)
        .preferredColorScheme(.dark)
    }
}
