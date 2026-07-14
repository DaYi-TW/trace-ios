import SwiftUI

enum TraceTheme {
    static let paper = Color(red: 0.961, green: 0.957, blue: 0.929)
    static let ink = Color(red: 0.118, green: 0.165, blue: 0.137)
    static let moss = Color(red: 0.192, green: 0.302, blue: 0.239)
    static let muted = Color(red: 0.396, green: 0.443, blue: 0.412)
    static let rust = Color(red: 0.729, green: 0.357, blue: 0.239)
    static let line = Color(red: 0.82, green: 0.835, blue: 0.807)
    static let vault = Color(red: 0.063, green: 0.125, blue: 0.098)

    static func titleFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

struct TraceWordmark: View {
    var light: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("留痕")
                .font(TraceTheme.titleFont(21))
            Text("TRACE")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.2)
                .opacity(0.58)
        }
        .foregroundStyle(light ? .white : TraceTheme.ink)
    }
}

struct TracePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(TraceTheme.moss.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
