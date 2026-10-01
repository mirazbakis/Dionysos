import SwiftUI

/// Deep navy background with two slow blue glows, so the Liquid Glass above it
/// always has some colour to catch.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.039, green: 0.075, blue: 0.161), Aurora.night],
                startPoint: .top,
                endPoint: .bottom)

            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height) * 0.9
                    glow(size: size, colors: [Aurora.violet.opacity(0.34), Aurora.indigo.opacity(0.18), .clear])
                        .position(
                            x: geo.size.width * (0.5 + 0.08 * sin(t * 0.12)),
                            y: geo.size.height * (0.14 + 0.03 * cos(t * 0.1)))
                    glow(size: size * 0.8, colors: [Aurora.indigo.opacity(0.28), .clear])
                        .position(
                            x: geo.size.width * (0.15 + 0.05 * cos(t * 0.09)),
                            y: geo.size.height * (0.82 + 0.03 * sin(t * 0.11)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(size: CGFloat, colors: [Color]) -> some View {
        Circle()
            .fill(RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 40)
    }
}

#Preview {
    AuroraBackground()
}
