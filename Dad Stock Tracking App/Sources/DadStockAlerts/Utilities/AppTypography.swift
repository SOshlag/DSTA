import SwiftUI

extension Font {
    static func appArialBold(_ size: CGFloat) -> Font {
        .custom("Arial", size: size).weight(.bold)
    }
}

enum AppTheme {
    static let canvasTop = Color(red: 0.025, green: 0.040, blue: 0.070)
    static let canvasBottom = Color(red: 0.055, green: 0.078, blue: 0.125)
    static let surface = Color(red: 0.055, green: 0.075, blue: 0.115).opacity(0.96)
    static let surfaceRaised = Color(red: 0.075, green: 0.102, blue: 0.155)
    static let inputSurface = Color(red: 0.035, green: 0.052, blue: 0.085)
    static let border = Color(red: 0.25, green: 0.48, blue: 0.72).opacity(0.38)
    static let grid = Color(red: 0.20, green: 0.50, blue: 0.76).opacity(0.055)
    static let ink = Color(red: 0.91, green: 0.95, blue: 1.00)
    static let muted = Color(red: 0.49, green: 0.60, blue: 0.72)
    static let accent = Color(red: 0.16, green: 0.53, blue: 0.96)
    static let cyan = Color(red: 0.25, green: 0.78, blue: 1.00)
    static let buy = Color(red: 0.18, green: 0.84, blue: 0.57)
    static let sell = Color(red: 0.98, green: 0.35, blue: 0.40)
    static let navy = Color(red: 0.025, green: 0.040, blue: 0.070)
    static let gold = Color(red: 0.93, green: 0.73, blue: 0.30)

    static var canvas: LinearGradient {
        LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct TechGridBackground: View {
    var body: some View {
        ZStack {
            AppTheme.canvas
            Canvas { context, size in
                var path = Path()
                let spacing: CGFloat = 36
                stride(from: CGFloat.zero, through: size.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat.zero, through: size.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(AppTheme.grid), lineWidth: 0.5)
            }
        }
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border))
            .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
    }
}

extension View {
    func appCard() -> some View { modifier(AppCardModifier()) }
}
