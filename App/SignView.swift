import SwiftUI
import UniformTypeIdentifiers

/// Home tab: pick the Apple ID that signs, import an IPA, and sign any IPA in
/// the library. The install itself runs in InstallFlowView.
struct SignView: View {
    @Binding var selectedTab: AppTab
    @ObservedObject private var router = SignRouter.shared
    @StateObject private var controller = InstallController.shared
    @StateObject private var pairings = PairingStore.shared
    @StateObject private var accounts = AccountStore.shared
    @State private var library: [IPAStore.Item] = IPAStore.list()
    @State private var showImporter = false
    @State private var importError: String?
    @State private var vpnActive = LocalDevVPN.isActive
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $router.path) {
            AuroraScreen {
                hero

                if pairings.selfPairing == nil {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            GlassCard(tint: Aurora.danger) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Pair this iPhone first", systemImage: "link.badge.plus")
                                        .font(.headline)
                                    Text("Dionysos needs this iPhone's pairing file to install apps on it, the way a computer would.")
                                        .font(.subheadline)
                                        .foregroundStyle(Aurora.secondaryText)
                                }
                            }
                            GlassActionButton(title: "Pair This iPhone", systemImage: "antenna.radiowaves.left.and.right", prominent: true) {
                                router.path = [.pair]
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    SectionLabel(title: "Signing As")
                    accountCard
                }

                GlassActionButton(title: "Import IPA", systemImage: "square.and.arrow.down.fill", prominent: true) {
                    showImporter = true
                }
                .disabled(pairings.selfPairing == nil)
                .opacity(pairings.selfPairing == nil ? 0.5 : 1)

                VStack(spacing: 10) {
                    SectionLabel(title: "IPA Library", trailing: library.isEmpty ? nil : "\(library.count)")
                    libraryCard
                }

                VStack(spacing: 10) {
                    SectionLabel(title: "Setup", trailing: "\(readyCount) of 3 ready")
                    checklist
                }

                Text("Dionysos signs apps with your own Apple ID and installs them straight onto this iPhone, no computer needed. With a free Apple ID, apps last 7 days. Dionysos reminds you the day before.")
                    .font(.system(size: 13))
                    .foregroundStyle(Aurora.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .navigationTitle("Sign")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.path = [.pair]
                    } label: {
                        Label("Pair", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .navigationDestination(for: SignRoute.self) { route in
                switch route {
                case .pair: PairView()
                }
            }
            .onAppear { library = IPAStore.list() }
            .onChange(of: controller.flow) { _, flow in
                if flow == nil { library = IPAStore.list() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { vpnActive = LocalDevVPN.isActive }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let copy = try IPAStore.importIPA(from: url)
                        library = IPAStore.list()
                        controller.begin(.ipa(copy), account: accounts.active?.email)
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Couldn't import the IPA", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        GlassCard(padding: 24) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Aurora.violet.opacity(0.45))
                        .frame(width: 120, height: 120)
                        .blur(radius: 38)
                    DionysosMark(size: 96)
                }
                VStack(spacing: 4) {
                    Text("Dionysos")
                        .font(.title.bold())
                        .foregroundStyle(Aurora.frost)
                    Text("Sign and install your apps with your own Apple ID")
                        .font(.subheadline)
                        .foregroundStyle(Aurora.secondaryText)
                        .multilineTextAlignment(.center)
                }
                statusChip
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        let active = controller.apps.filter { !$0.isExpired }.count
        let expiring = controller.apps.filter { $0.isExpired || ($0.daysLeft ?? 99) < 1 }.count
        if expiring > 0 {
            GlassChip(text: "\(expiring) app\(expiring == 1 ? "" : "s") need a refresh", systemImage: "exclamationmark.triangle.fill", tint: Aurora.danger)
        } else if active > 0 {
            GlassChip(text: "\(active) signed app\(active == 1 ? "" : "s") active", systemImage: "checkmark.seal.fill", tint: Aurora.success)
        } else {
            GlassChip(text: "No signed apps yet", systemImage: "circle.dashed")
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        Menu {
            if !accounts.accounts.isEmpty {
                Picker("Default Apple ID", selection: $accounts.activeEmail) {
                    ForEach(accounts.accounts) { account in
                        Text(account.email).tag(account.email)
                    }
                }
                Divider()
            }
            Button("Manage Accounts", systemImage: "person.2") { selectedTab = .accounts }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: accounts.active == nil ? "person.crop.circle.badge.plus" : "person.crop.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Aurora.frost)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(Aurora.violet.opacity(0.5)), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(accounts.active?.email ?? "No Apple ID yet")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Aurora.frost)
                        .lineLimit(1)
                    Text(accountDetail)
                        .font(.footnote)
                        .foregroundStyle(Aurora.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Aurora.secondaryText)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)).interactive(), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Aurora.hairline, lineWidth: 1)
        }
    }

    private var accountDetail: String {
        guard let account = accounts.active else { return "You'll add one when you sign your first app" }
        let count = accounts.accounts.count
        let signed = controller.apps.filter { $0.accountEmail == account.email && !$0.isExpired }.count
        var parts = ["\(signed) of 3 app slots used"]
        if count > 1 { parts.append("\(count) accounts saved") }
        return parts.joined(separator: " · ")
    }

    // MARK: - IPA library

    @ViewBuilder
    private var libraryCard: some View {
        if library.isEmpty {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "doc.zipper")
                        .font(.title2)
                        .foregroundStyle(Aurora.orchid)
                    Text("Imported IPAs stay here so you can sign them again with any of your accounts.")
                        .font(.subheadline)
                        .foregroundStyle(Aurora.secondaryText)
                }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(library) { item in
                    AppBannerRow(
                        name: item.name,
                        detail: "\(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)) · \(item.modified.formatted(.relative(presentation: .named)))",
                        detailColor: Aurora.secondaryText,
                        iconURL: nil,
                        symbol: "doc.zipper"
                    ) {
                        PillButton(title: "Sign") {
                            controller.begin(.ipa(item.url), account: accounts.active?.email)
                        }
                        .disabled(pairings.selfPairing == nil)
                    }
                    .contextMenu {
                        ShareLink(item: item.url)
                        Button("Delete IPA", systemImage: "trash", role: .destructive) {
                            IPAStore.delete(item)
                            library = IPAStore.list()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Checklist

    private var checklist: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                StatusRow(
                    title: "Pairing file",
                    detail: pairings.selfPairing.map { "\($0.displayName), saved \($0.date.formatted(.relative(presentation: .named)))" }
                        ?? "Tap Pair This iPhone above",
                    state: pairings.selfPairing == nil ? .attention : .done)
                StatusRow(
                    title: "LocalDevVPN",
                    detail: vpnActive ? "Connected, reaching this iPhone at \(LocalDevVPN.targetIP)"
                        : (LocalDevVPN.isInstalled ? "Installed but off. Dionysos will ask you to turn it on" : "Needed for installs. It's free on the App Store"),
                    state: vpnActive ? .done : .pending)
                StatusRow(
                    title: "Apple ID",
                    detail: accounts.active.map { "\($0.email) · \(accounts.accounts.count) saved" } ?? "Add your own Apple ID when you sign",
                    state: accounts.active == nil ? .pending : .done)
            }
        }
    }

    private var readyCount: Int {
        var n = 0
        if pairings.selfPairing != nil { n += 1 }
        if vpnActive { n += 1 }
        if accounts.active != nil { n += 1 }
        return n
    }
}
