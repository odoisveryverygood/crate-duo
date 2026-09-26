import SwiftUI

enum TouchPhaseUI { case began, moved, ended }

#if canImport(UIKit)
import UIKit

/// Transparent multi-touch layer. SwiftUI gestures serialize fingers across sibling views, so pads and keys
/// use this: every finger is tracked on its own, `began` fires on touch-down (lowest latency), `moved` allows
/// glissando. Visuals (and accessibility elements) sit underneath; AXe taps land here by coordinate.
struct TouchSurface: UIViewRepresentable {
    var handler: (TouchPhaseUI, ObjectIdentifier, CGPoint) -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let v = TouchTrackingView()
        v.handler = handler
        return v
    }

    func updateUIView(_ v: TouchTrackingView, context: Context) {
        v.handler = handler
    }
}

final class TouchTrackingView: UIView {
    var handler: ((TouchPhaseUI, ObjectIdentifier, CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { handler?(.began, ObjectIdentifier(t), t.location(in: self)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { handler?(.moved, ObjectIdentifier(t), t.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { handler?(.ended, ObjectIdentifier(t), t.location(in: self)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { handler?(.ended, ObjectIdentifier(t), t.location(in: self)) }
    }
}
#else
/// macOS (UI snapshot harness only): no touch handling.
struct TouchSurface: View {
    var handler: (TouchPhaseUI, ObjectIdentifier, CGPoint) -> Void
    var body: some View { Color.clear }
}
#endif
