import SwiftUI
import UIKit
import GameController

/// What CRATE is running on. There is no public "is this a Duo" check, so the Duo is recognised by its fold
/// (`.division` reserved region) or its hinge (`onHingeChange`), remembered per device model once seen.
enum DeviceInfo {
    /// A hardware keyboard is attached (the computer-key legends on the KEYS keyboard only help then).
    static var hasHardwareKeyboard: Bool { GCKeyboard.coalesced != nil }

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// `utsname.machine`, e.g. "iPhone18,1" ("arm64" in the simulator).
    static let machine: String = {
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()

    /// Duo simulators ("iPhone Duo", "Duo-Video-3", Bitrig's "iPhone Duo").
    static let simulatorDuo: Bool = {
        #if targetEnvironment(simulator)
        let e = ProcessInfo.processInfo.environment
        return ["SIMULATOR_DEVICE_NAME", "SIMULATOR_MODEL_IDENTIFIER"]
            .contains { (e[$0] ?? "").localizedCaseInsensitiveContains("duo") }
        #else
        return false
        #endif
    }()

    /// The model that last reported a fold or hinge (a backup restored onto another model doesn't count).
    private static let duoMachineKey = "crateDuoMachine"
    static var rememberedDuo: Bool { UserDefaults.standard.string(forKey: duoMachineKey) == machine }

    /// The key window's safe-area insets (Dynamic Island, home indicator), readable even under `.ignoresSafeArea()`.
    static var windowInsets: UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.windows.first(where: \.isKeyWindow)?.safeAreaInsets ?? scene?.windows.first?.safeAreaInsets ?? .zero
    }

    /// `windowInsets` for SwiftUI padding (the root ignores the safe area, so its GeometryProxy reports zero).
    static var windowEdgeInsets: EdgeInsets {
        let i = windowInsets
        return EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
    }

    static func rememberDuo() {
        guard !rememberedDuo else { return }
        UserDefaults.standard.set(machine, forKey: duoMachineKey)
    }
}

extension GeometryProxy {
    /// The Duo's fold: `active` only while folded, `any` also when flat. Both nil on phones, iPads and iOS < 27.1.
    var crateFold: (active: CGRect?, any: CGRect?) {
        #if !NO_DUO_SDK
        if #available(iOS 27.1, *) {
            return (reservedRegions(kind: .division).map(\.frame).first,
                    reservedRegions(kind: .division, options: .includeInactive).map(\.frame).first)
        }
        #endif
        return (nil, nil)
    }
}
