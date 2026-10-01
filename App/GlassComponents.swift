import SwiftUI

// MARK: - Buttons & cards

/// Full-width Liquid Glass action. Prominent actions get blue-tinted glass.
struct GlassActionButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var prominent = false
    var tint: Color = Aurora.violet
    let action: () -> Void

    var body: some View {
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
                .tint(tint)
                .controlSize(.extraLarge)
        } else {
            Button(action: action) { label }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
            }
            Text(title)
                .font(.headline)
        }
        .foregroundStyle(Aurora.frost)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

/// Card: Liquid Glass tinted navy with a faint blue hairline.
struct GlassCard<Content: View>: View {
    var tint: Color? = nil
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    private let radius: CGFloat = 20

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(tint.map { $0.opacity(0.22) } ?? Aurora.card.opacity(0.6)), in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder((tint ?? Aurora.violet).opacity(0.25), lineWidth: 1)
            }
    }
}

/// Section header: 13pt semibold, uppercase, white at 60%.
struct SectionLabel: View {
    let title: LocalizedStringKey
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Aurora.secondaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Aurora.secondaryText)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - App cells

/// App icon from a source, or a gradient tile with a symbol while it loads.
struct AppIconView: View {
    var url: URL?
    var symbol: String = "app.fill"
    var size: CGFloat = 56

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(Aurora.accentGradient)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(Aurora.frost)
                }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

/// Capsule button: a tiny caption over a bold value ("EXPIRES IN" / "5 DAYS"),
/// or a single word ("GET", "OPEN", "UPDATE").
struct PillButton: View {
    var caption: String? = nil
    let title: String
    var tint: Color = Aurora.violet
    var prominent = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if let caption {
                    Text(caption.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.75)
                }
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(prominent ? Aurora.frost : tint)
            .frame(minWidth: 72, minHeight: 34)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint.opacity(prominent ? 0.85 : 0.2)).interactive(), in: .capsule)
    }
}

/// An app row in an App Store-style banner: icon, name, detail line
/// and a pill on the right.
struct AppBannerRow<Trailing: View>: View {
    let name: String
    let detail: String
    var detailColor: Color = Aurora.secondaryText
    var iconURL: URL? = nil
    var symbol: String = "app.fill"
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(url: iconURL, symbol: symbol, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Aurora.frost)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(detailColor)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Aurora.hairline, lineWidth: 1)
        }
    }
}

// MARK: - Rows

/// Numbered step inside an instruction card.
struct GuideStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(Aurora.frost)
                .frame(width: 24, height: 24)
                .glassEffect(.regular.tint(Aurora.violet.opacity(0.6)), in: .circle)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Checklist row: done / pending / needs attention.
struct StatusRow: View {
    enum Status { case done, pending, attention }
    let title: LocalizedStringKey
    let detail: String
    let state: Status

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(color.opacity(0.22)), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var symbol: String {
        switch state {
        case .done: "checkmark"
        case .pending: "circle.dotted"
        case .attention: "exclamationmark"
        }
    }

    private var color: Color {
        switch state {
        case .done: Aurora.success
        case .pending: Aurora.lilac
        case .attention: Aurora.danger
        }
    }
}

// MARK: - Indicators

/// Each digit of a pairing code in its own glass tile; the halves merge.
struct GlassCodeView: View {
    let code: String
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(code.enumerated()), id: \.offset) { index, digit in
                    Text(String(digit))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Aurora.frost)
                        .frame(width: 44, height: 60)
                        .glassEffect(.regular.tint(Aurora.violet.opacity(0.25)).interactive(), in: .rect(cornerRadius: 14))
                        .glassEffectUnion(id: index < 3 ? "left" : "right", namespace: ns)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pairing code \(code.map(String.init).joined(separator: " "))")
    }
}

/// Circular progress. `value == nil` spins indefinitely.
struct ProgressRing: View {
    var value: Double?
    var lineWidth: CGFloat = 8
    var size: CGFloat = 64
    var showsPercent = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Aurora.frost.opacity(0.12), lineWidth: lineWidth)

            TimelineView(.animation(paused: value != nil)) { context in
                let spin = value == nil
                    ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1 * 360
                    : 0
                Circle()
                    .trim(from: 0, to: value.map { max(0.02, min($0, 1)) } ?? 0.28)
                    .stroke(
                        AngularGradient(colors: [Aurora.orchid, Aurora.violet, Aurora.orchid], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(spin - 90))
                    .animation(.spring(duration: 0.4), value: value)
            }

            if showsPercent, let value {
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Aurora.frost)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\(Int($0 * 100)) percent" } ?? "In progress")
    }
}

/// Linear progress in a glass capsule, violet fill with a soft glow.
struct GlassProgressBar: View {
    var value: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Aurora.accentGradient)
                    .frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
                    .shadow(color: Aurora.violet.opacity(0.6), radius: 8)
            }
        }
        .frame(height: height)
        .padding(3)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.5)), in: .capsule)
        .animation(.spring(duration: 0.5), value: value)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(Text(value.formatted(.percent.precision(.fractionLength(0)))))
    }
}

// MARK: - Marks

/// Symbol in a glass disc, used for status icons.
struct GlassBadge: View {
    let systemImage: String
    var tint: Color = Aurora.violet
    var size: CGFloat = 96

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Aurora.frost)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(tint.opacity(0.45))
                    .blur(radius: size * 0.35)
                    .scaleEffect(1.1)
            }
            .glassEffect(.regular.tint(tint.opacity(0.5)).interactive(), in: .circle)
    }
}

/// Small glass capsule for status text.
struct GlassChip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = Aurora.violet

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Aurora.frost)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(tint.opacity(0.3)), in: .capsule)
    }
}

/// Dionysos's logo drawn in SwiftUI: a grape cluster with a vine leaf and tendril
/// inside a soft ring. Matches the app icon (App/Dionysos.icon) and docs/assets/logo.svg,
/// which use a 1024-point design space.
struct DionysosMark: View {
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(Aurora.markGradient)
            RadialGradient(colors: [Aurora.lilac.opacity(0.45), .clear],
                           center: .init(x: 0.5, y: 0.53), startRadius: 0, endRadius: size * 0.37)
            MarkArtwork()
                .frame(width: size, height: size)
            LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
        .shadow(color: Aurora.violet.opacity(0.55), radius: size * 0.22, y: size * 0.06)
        .accessibilityLabel("Dionysos")
    }
}

/// The white glyphs, drawn with Canvas in the logo's 1024 × 1024 space.
private struct MarkArtwork: View {
    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 1024
            context.scaleBy(x: s, y: s)

            // Ring.
            context.stroke(Path(ellipseIn: CGRect(x: 172, y: 172, width: 680, height: 680)),
                           with: .color(.white.opacity(0.22)), lineWidth: 26)

            // Grapes: 3-2-1.
            let grapes: [CGPoint] = [
                .init(x: 392, y: 486), .init(x: 512, y: 486), .init(x: 632, y: 486),
                .init(x: 452, y: 592), .init(x: 572, y: 592),
                .init(x: 512, y: 698)
            ]
            var cluster = Path()
            for c in grapes { cluster.addEllipse(in: CGRect(x: c.x - 62, y: c.y - 62, width: 124, height: 124)) }
            context.fill(cluster, with: .color(.white))

            // Stem and tendril.
            var stem = Path()
            stem.move(to: .init(x: 512, y: 430))
            stem.addCurve(to: .init(x: 546, y: 330), control1: .init(x: 512, y: 392), control2: .init(x: 520, y: 362))
            context.stroke(stem, with: .color(.white), style: StrokeStyle(lineWidth: 30, lineCap: .round))
            var tendril = Path()
            tendril.move(to: .init(x: 556, y: 364))
            tendril.addCurve(to: .init(x: 648, y: 398), control1: .init(x: 606, y: 338), control2: .init(x: 652, y: 356))
            tendril.addCurve(to: .init(x: 603, y: 408), control1: .init(x: 645, y: 428), control2: .init(x: 610, y: 433))
            context.stroke(tendril, with: .color(.white), style: StrokeStyle(lineWidth: 20, lineCap: .round))

            // Vine leaf.
            var leaf = Path()
            leaf.move(to: .init(x: 0, y: 90))
            leaf.addCurve(to: .init(x: 122, y: -8), control1: .init(x: 40, y: 62), control2: .init(x: 108, y: 42))
            leaf.addLine(to: .init(x: 72, y: -28))
            leaf.addCurve(to: .init(x: 26, y: -122), control1: .init(x: 88, y: -70), control2: .init(x: 62, y: -112))
            leaf.addLine(to: .init(x: 0, y: -164))
            leaf.addLine(to: .init(x: -26, y: -122))
            leaf.addCurve(to: .init(x: -72, y: -28), control1: .init(x: -62, y: -112), control2: .init(x: -88, y: -70))
            leaf.addLine(to: .init(x: -122, y: -8))
            leaf.addCurve(to: .init(x: 0, y: 90), control1: .init(x: -108, y: 42), control2: .init(x: -40, y: 62))
            leaf.closeSubpath()
            let transform = CGAffineTransform(translationX: 446, y: 352)
                .rotated(by: -38 * .pi / 180)
                .scaledBy(x: 0.9, y: 0.9)
            context.fill(leaf.applying(transform), with: .color(.white))
        }
    }
}


// MARK: - Scaffold

/// Screen scaffold: navy + glow background edge to edge, scrolling content column.
struct AuroraScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(spacing: 22) {
                    content
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

#Preview("Mark") {
    ZStack {
        AuroraBackground()
        VStack(spacing: 30) {
            DionysosMark(size: 160)
            ProgressRing(value: 0.42, size: 80)
            ProgressRing(value: nil, size: 48)
        }
    }
    .auroraTheme()
}
