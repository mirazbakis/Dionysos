import SwiftUI

/// Credits for the projects Dionysos is built on and inspired by.
struct AcknowledgmentsView: View {
    struct Credit: Identifiable {
        let name: String
        let author: String
        let role: String
        let symbol: String
        let tint: Color
        let url: URL
        var id: String { name }
        /// GitHub avatar of the author (or organisation).
        var avatar: URL? { URL(string: "https://github.com/\(author).png?size=160") }
    }

    private static func gh(_ path: String) -> URL { URL(string: "https://github.com/\(path)")! }

    static let author = Credit(
        name: "mbakis", author: "mirazbakis",
        role: "Designed and built Dionysos: the app, multi-account signing, account management, the interface and the logo. Also the author of AltLoad.",
        symbol: "sparkles", tint: Aurora.violet, url: gh("mirazbakis/Dionysos"))

    static let builtOn: [Credit] = [
        Credit(name: "AltLoad", author: "mirazbakis",
               role: "mbakis's on-device installer, whose pairing, signing and install engine Dionysos grew out of.",
               symbol: "arrow.down.app.fill", tint: Aurora.violet, url: gh("mirazbakis/AltLoad")),
        Credit(name: "isideload", author: "nab138",
               role: "Apple ID sign-in, the free developer portal API and code signing.",
               symbol: "signature", tint: Aurora.orchid, url: gh("nab138/isideload")),
        Credit(name: "idevice", author: "jkcoxson",
               role: "RemotePairing tunnel, AFC and installation_proxy to talk to this iPhone.",
               symbol: "cable.connector", tint: Aurora.success, url: gh("jkcoxson/idevice")),
        Credit(name: "StikPair", author: "StephenDev0",
               role: "The on-device pairing flow that creates this iPhone's pairing file.",
               symbol: "antenna.radiowaves.left.and.right", tint: Aurora.warning, url: gh("StephenDev0/StikPair")),
        Credit(name: "LocalDevVPN", author: "jkcoxson",
               role: "Loops traffic back into the iPhone so it can be reached like from a computer.",
               symbol: "network.badge.shield.half.filled", tint: Aurora.lilac, url: gh("jkcoxson/LocalDevVPN")),
        Credit(name: "SideStore", author: "SideStore",
               role: "The community list of anisette servers used for Apple ID sign-in.",
               symbol: "server.rack", tint: Aurora.danger, url: gh("SideStore/SideStore"))
    ]

    static let inspiredBy: [Credit] = [
        Credit(name: "AltStore", author: "rileytestut",
               role: "Pioneered signing apps with your own free Apple ID.",
               symbol: "square.stack.3d.up.fill", tint: Aurora.success, url: gh("altstoreio/AltStore")),
        Credit(name: "Feather", author: "khcrysalis",
               role: "On-device signing and a clean signing workflow.",
               symbol: "leaf.fill", tint: Aurora.orchid, url: gh("khcrysalis/Feather")),
        Credit(name: "Ksign", author: "Nyasami",
               role: "Library and certificate management ideas.",
               symbol: "checkmark.seal.fill", tint: Aurora.violet, url: gh("Nyasami/Ksign"))
    ]

    var body: some View {
        AuroraScreen {
            VStack(spacing: 12) {
                DionysosMark(size: 88)
                Text("Acknowledgments")
                    .font(.title2.bold())
                    .foregroundStyle(Aurora.frost)
                Text("Dionysos stands on the work of these open-source projects and the people behind them. Thank you.")
                    .font(.subheadline)
                    .foregroundStyle(Aurora.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                SectionLabel(title: "Created By")
                Link(destination: Self.gh("mirazbakis")) { row(Self.author) }
                    .buttonStyle(.plain)
            }

            section("Built On", Self.builtOn)
            section("Inspired By", Self.inspiredBy)

            Text("Dionysos, an app by mbakis. Licenses for the code it includes are in Settings › Legal › Third-Party Notices.")
                .font(.footnote)
                .foregroundStyle(Aurora.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .navigationTitle("Acknowledgments")
        .toolbarTitleDisplayMode(.inline)
    }

    private func section(_ title: LocalizedStringKey, _ credits: [Credit]) -> some View {
        VStack(spacing: 10) {
            SectionLabel(title: title)
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(credits) { credit in
                        Link(destination: credit.url) { row(credit) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ credit: Credit) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: credit.avatar) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: credit.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Aurora.frost)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(credit.tint.opacity(0.35))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(.circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }

                Image(systemName: credit.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Aurora.frost)
                    .frame(width: 22, height: 22)
                    .glassEffect(.regular.tint(credit.tint.opacity(0.7)), in: .circle)
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(credit.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Aurora.frost)
                    Text("@\(credit.author)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Aurora.orchid)
                }
                Text(credit.role)
                    .font(.footnote)
                    .foregroundStyle(Aurora.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(14)
        .contentShape(.rect)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)).interactive(), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Aurora.hairline, lineWidth: 1)
        }
    }
}
