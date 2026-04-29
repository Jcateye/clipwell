import SwiftUI

struct ThemePalette {
    let background: Color
    let backgroundSecondary: Color
    let backgroundTertiary: Color
    let surface: Color
    let elevated: Color
    let line: Color
    let lineBright: Color
    let accent: Color
    let accentSecondary: Color
    let onAccent: Color
    let success: Color
    let warning: Color
    let text: Color
    let muted: Color
    let gridOpacity: Double
    let glowOpacity: Double
}

enum TechTheme {
    static var activeTheme: AppVisualTheme {
        AppVisualTheme(rawValue: UserDefaults.standard.string(forKey: "visual_theme") ?? "") ?? .graphite
    }

    static var palette: ThemePalette {
        palette(for: activeTheme)
    }

    static func palette(for theme: AppVisualTheme) -> ThemePalette {
        switch theme {
        case .light:
            ThemePalette(
                background: Color(hex: 0xF8F1E7),
                backgroundSecondary: Color(hex: 0xF1E3D3),
                backgroundTertiary: Color(hex: 0xFFF9F0),
                surface: Color(hex: 0xFFF8EE),
                elevated: Color(hex: 0xEBD8C5),
                line: Color(hex: 0xD8BFA7),
                lineBright: Color(hex: 0xA7673F).opacity(0.34),
                accent: Color(hex: 0x8B4F2F),
                accentSecondary: Color(hex: 0xC99068),
                onAccent: Color(hex: 0xFFFFFF),
                success: Color(hex: 0x4F6530),
                warning: Color(hex: 0x914D22),
                text: Color(hex: 0x2E2118),
                muted: Color(hex: 0x7E6A5B),
                gridOpacity: 0.022,
                glowOpacity: 0.12
            )
        case .graphite:
            ThemePalette(
                background: Color(hex: 0x1B1C1F),
                backgroundSecondary: Color(hex: 0x24262A),
                backgroundTertiary: Color(hex: 0x202226),
                surface: Color(hex: 0x2A2C31),
                elevated: Color(hex: 0x34373D),
                line: Color(hex: 0x464A52),
                lineBright: Color(hex: 0xAEB4BE).opacity(0.3),
                accent: Color(hex: 0xAEB4BE),
                accentSecondary: Color(hex: 0x7E858F),
                onAccent: Color(hex: 0x111316),
                success: Color(hex: 0x9AAE9A),
                warning: Color(hex: 0xC3A06D),
                text: Color(hex: 0xF0F1F2),
                muted: Color(hex: 0xA6ABB2),
                gridOpacity: 0.014,
                glowOpacity: 0.06
            )
        case .slate:
            ThemePalette(
                background: Color(hex: 0x131B24),
                backgroundSecondary: Color(hex: 0x1B2835),
                backgroundTertiary: Color(hex: 0x172331),
                surface: Color(hex: 0x203040),
                elevated: Color(hex: 0x2A3D50),
                line: Color(hex: 0x3C5268),
                lineBright: Color(hex: 0x91B3D6).opacity(0.34),
                accent: Color(hex: 0x91B3D6),
                accentSecondary: Color(hex: 0x6384A3),
                onAccent: Color(hex: 0x101820),
                success: Color(hex: 0x7FB3AA),
                warning: Color(hex: 0xC6A77B),
                text: Color(hex: 0xEEF4F9),
                muted: Color(hex: 0x9FB0BF),
                gridOpacity: 0.024,
                glowOpacity: 0.1
            )
        case .warm:
            ThemePalette(
                background: Color(hex: 0x211812),
                backgroundSecondary: Color(hex: 0x2E2118),
                backgroundTertiary: Color(hex: 0x281C14),
                surface: Color(hex: 0x38281D),
                elevated: Color(hex: 0x463326),
                line: Color(hex: 0x5B4434),
                lineBright: Color(hex: 0xD6A874).opacity(0.34),
                accent: Color(hex: 0xD6A874),
                accentSecondary: Color(hex: 0xA97B50),
                onAccent: Color(hex: 0x16100C),
                success: Color(hex: 0xA7A36E),
                warning: Color(hex: 0xE0A15E),
                text: Color(hex: 0xF4ECE3),
                muted: Color(hex: 0xB29D8B),
                gridOpacity: 0.015,
                glowOpacity: 0.08
            )
        case .tech:
            ThemePalette(
                background: Color(hex: 0x071018),
                backgroundSecondary: Color(hex: 0x0B1B29),
                backgroundTertiary: Color(hex: 0x10151F),
                surface: Color(hex: 0x102130),
                elevated: Color(hex: 0x152D42),
                line: Color(hex: 0x24445D),
                lineBright: Color(hex: 0x4ADDE8).opacity(0.36),
                accent: Color(hex: 0x4ADDE8),
                accentSecondary: Color(hex: 0x327EA8),
                onAccent: Color(hex: 0x061015),
                success: Color(hex: 0x78D7B4),
                warning: Color(hex: 0xE2B86B),
                text: Color(hex: 0xEAF7FA),
                muted: Color(hex: 0x8FA8B8),
                gridOpacity: 0.048,
                glowOpacity: 0.18
            )
        }
    }

    static var background: Color { palette.background }
    static var surface: Color { palette.surface }
    static var elevated: Color { palette.elevated }
    static var line: Color { palette.line }
    static var lineBright: Color { palette.lineBright }
    static var cyan: Color { palette.accent }
    static var blue: Color { palette.accentSecondary }
    static var onAccent: Color { palette.onAccent }
    static var green: Color { palette.success }
    static var amber: Color { palette.warning }
    static var text: Color { palette.text }
    static var muted: Color { palette.muted }

    static let displayFont = Font.custom("Avenir Next Condensed", size: 18).weight(.bold)
    static let labelFont = Font.custom("Avenir Next", size: 12).weight(.semibold)
    static let monoFont = Font.system(.caption, design: .monospaced).weight(.medium)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct TechBackground: View {
    var body: some View {
        let palette = TechTheme.palette

        ZStack {
            LinearGradient(
                colors: [
                    palette.background,
                    palette.backgroundSecondary,
                    palette.backgroundTertiary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.accentSecondary.opacity(palette.glowOpacity))
                .blur(radius: 58)
                .frame(width: 180, height: 180)
                .offset(x: -150, y: -280)

            Circle()
                .fill(palette.accent.opacity(palette.glowOpacity * 0.75))
                .blur(radius: 70)
                .frame(width: 220, height: 220)
                .offset(x: 160, y: 180)

            GridOverlay()
                .stroke(palette.accent.opacity(palette.gridOpacity), lineWidth: 0.8)
        }
        .ignoresSafeArea()
    }
}

struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 28

        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }

        return path
    }
}

struct TechCard: ViewModifier {
    var selected = false
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(selected ? TechTheme.elevated.opacity(0.92) : TechTheme.surface.opacity(0.78))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(selected ? TechTheme.lineBright : TechTheme.line.opacity(0.75), lineWidth: selected ? 1.2 : 0.8)
                    }
                    .shadow(color: selected ? TechTheme.cyan.opacity(0.14) : .black.opacity(0.22), radius: selected ? 16 : 8, y: 6)
            }
    }
}

extension View {
    func techCard(selected: Bool = false, cornerRadius: CGFloat = 16) -> some View {
        modifier(TechCard(selected: selected, cornerRadius: cornerRadius))
    }
}
