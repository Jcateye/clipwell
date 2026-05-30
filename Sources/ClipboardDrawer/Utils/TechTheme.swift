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
    let surfaceOpacity: Double
    let elevatedOpacity: Double
}

enum TechTheme {
    static var activeTheme: AppVisualTheme {
        AppVisualTheme(rawValue: UserDefaults.standard.string(forKey: "visual_theme") ?? "") ?? .glassNight
    }

    static var palette: ThemePalette {
        palette(for: activeTheme)
    }

    static func palette(for theme: AppVisualTheme) -> ThemePalette {
        switch theme {
        case .glassDay:
            ThemePalette(
                background: Color(hex: 0xF7F4EE),
                backgroundSecondary: Color(hex: 0xECE4D7),
                backgroundTertiary: Color(hex: 0xFFFCF6),
                surface: Color(hex: 0xFFFFFF),
                elevated: Color(hex: 0xF2ECE3),
                line: Color(hex: 0xD8CDC0),
                lineBright: Color(hex: 0x617070).opacity(0.36),
                accent: Color(hex: 0x526565),
                accentSecondary: Color(hex: 0x9B8065),
                onAccent: Color(hex: 0xFFFFFF),
                success: Color(hex: 0x607A61),
                warning: Color(hex: 0x9B6C42),
                text: Color(hex: 0x20201D),
                muted: Color(hex: 0x787068),
                gridOpacity: 0.008,
                glowOpacity: 0.04,
                surfaceOpacity: 0.58,
                elevatedOpacity: 0.66
            )
        case .glassNight:
            ThemePalette(
                background: Color(hex: 0x1F211F),
                backgroundSecondary: Color(hex: 0x171918),
                backgroundTertiary: Color(hex: 0x292B28),
                surface: Color(hex: 0x2A2D2A),
                elevated: Color(hex: 0x343731),
                line: Color(hex: 0x50554E),
                lineBright: Color(hex: 0xCAC4B8).opacity(0.3),
                accent: Color(hex: 0xD8D2C6),
                accentSecondary: Color(hex: 0xA68A6A),
                onAccent: Color(hex: 0x151716),
                success: Color(hex: 0x8DAA81),
                warning: Color(hex: 0xC7965C),
                text: Color(hex: 0xF3EFE8),
                muted: Color(hex: 0xA7A299),
                gridOpacity: 0.006,
                glowOpacity: 0.035,
                surfaceOpacity: 0.42,
                elevatedOpacity: 0.56
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
    var theme: AppVisualTheme = TechTheme.activeTheme

    var body: some View {
        let palette = TechTheme.palette(for: theme)

        ZStack {
            palette.background

            LinearGradient(
                colors: [palette.backgroundTertiary, palette.background, palette.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(theme == .glassDay ? 0.22 : 0.34)

            LinearGradient(
                colors: [palette.surface.opacity(theme == .glassDay ? 0.34 : 0.06), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

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
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(selected ? TechTheme.elevated.opacity(TechTheme.palette.elevatedOpacity) : TechTheme.surface.opacity(TechTheme.palette.surfaceOpacity))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(selected ? TechTheme.lineBright : TechTheme.line.opacity(0.75), lineWidth: selected ? 1.2 : 0.8)
                    }
                    .shadow(color: .black.opacity(selected ? 0.18 : 0.1), radius: selected ? 18 : 10, y: selected ? 8 : 5)
            }
    }
}

extension View {
    func techCard(selected: Bool = false, cornerRadius: CGFloat = 8) -> some View {
        modifier(TechCard(selected: selected, cornerRadius: cornerRadius))
    }
}
