import SwiftUI

/// CRATE / CR-16 design tokens (Teenage Engineering look). Flat, no shadows, radius 4–6, animations ≤ 100 ms linear.
enum Theme {
    static func hex(_ v: UInt32, _ alpha: Double = 1) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255,
              opacity: alpha)
    }

    // Chassis (deck)
    static let chassis = hex(0xC9C9CB)
    static let button = hex(0xE4E4E6)
    static let buttonBorder = hex(0x9D9DA2)
    static let silk = hex(0x16161D)
    static let pad = hex(0x2F2F36)
    static let padPressed = hex(0x3A3A42)
    static let padEdge = hex(0x484850)
    static let padLabel = hex(0xAFAFB3)
    static let whiteKey = hex(0xEDEDEF)
    static let whiteKeyOff = hex(0xD3D3D7)
    static let blackKeyOff = hex(0x24242A)

    // Display (lid)
    static let display = Color.black
    static let text = hex(0xF6F4F4)
    static let mid = hex(0x797982)
    static let dim = hex(0x484850)
    static let rule = hex(0x2F2F36)
    static let dotOff = hex(0x1C1C24)
    static let ghost = hex(0x5A5A64)

    // Accents
    static let orange = hex(0xFA5B1C)
    static let blue = hex(0x5B8DEF)
    static let ochre = hex(0xE0A92E)
    static let grey = hex(0xAFAFB3)
    static let red = hex(0xE5484D)

    static let radius: CGFloat = 4
    static let padRadius: CGFloat = 6
    /// Pad / key flash length (seconds).
    static let flash: Double = 0.1
    static let quick = Animation.linear(duration: 0.08)

    static func bank(_ b: Bank) -> Color { [orange, blue, ochre, grey][b.rawValue] }

    static func tint(_ t: Tint) -> Color {
        switch t {
        case .orange: return orange
        case .blue: return blue
        case .ochre: return ochre
        case .grey: return grey
        case .red: return red
        }
    }

    // Fonts (PostScript names; fixed size so Dynamic Type never reflows the hardware).
    static func doto(_ size: CGFloat) -> Font { .custom("Doto-Black", fixedSize: size) }
    static func label(_ size: CGFloat) -> Font { .custom("SpaceMono-Bold", fixedSize: size) }
    static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", fixedSize: size)
    }
}

extension Text {
    /// Uppercase tracked Space Mono label (TE silk-screen style).
    func crateLabel(_ size: CGFloat, tracking: CGFloat = 0.16) -> Text {
        font(Theme.label(size)).tracking(size * tracking)
    }
}

/// Silk-screened label on the chassis / display.
struct SilkLabel: View {
    let text: String
    var size: CGFloat = 8.5
    var color: Color = Theme.silk
    var tracking: CGFloat = 0.16

    init(_ text: String, size: CGFloat = 8.5, color: Color = Theme.silk, tracking: CGFloat = 0.16) {
        self.text = text
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased())
            .crateLabel(size, tracking: tracking)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// The ✦ glyph (no bundled font has it), drawn as a 4-point star.
struct SparkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let o = min(r.width, r.height) / 2
        let i = o * 0.28
        for k in 0..<8 {
            let a = Double(k) * .pi / 4 - .pi / 2
            let rad = k.isMultiple(of: 2) ? o : i
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Play triangle (U+25B6 can render as an emoji on iOS, so it's drawn).
struct PlayShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
