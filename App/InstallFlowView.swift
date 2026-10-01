import SwiftUI

/// Full-screen install flow, SideStore style: sign in → download → LocalDevVPN →
/// sign & install → done. Presented over every tab by RootView, so Sign and
/// Library (refresh) share it.
struct InstallFlowView: View {
    let target: InstallTarget
    var onGoToPair: () -> Void = {}

    @ObservedObject private var controller = InstallController.shared
    @ObservedObject private var pairings = PairingStore.shared
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var accounts = AccountStore.shared
    @AppStorage(AccountDisclaimer.acceptedKey) private var disclaimerAccepted = false
    /// Email of the saved account to sign with, or "" to add a new one.
    @State private var selected = ""
    @State private var email = ""
    @State private var password = ""
    @State private var remember = true
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(spacing: 26) {
                        header
                        GlassEffectContainer(spacing: 16) {
                            step
                                .id(phaseKey)
                                .transition(.blurReplace.combined(with: .scale(0.97)))
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    GlassEffectContainer(spacing: 12) {
                        actions
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { controller.finish() }
                        .disabled(controller.isBusy)
                }
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(item: $controller.twoFactor) { prompt in
            TwoFactorSheet(prompt: prompt) { controller.respond($0) }
                .auroraTheme()
        }
        .fullScreenCover(item: $controller.revoke) { prompt in
            RevokeSheet(prompt: prompt) { controller.respond($0) }
                .auroraTheme()
        }
        .onAppear {
            selected = controller.flowAccount ?? accounts.active?.email ?? ""
            pick(selected)
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from LocalDevVPN with the VPN on: carry on automatically.
            if phase == .active { controller.resumeWhenVPNReady() }
        }
        .animation(.spring(duration: 0.5, bounce: 0.2), value: controller.phase)
        .sensoryFeedback(trigger: controller.phase) { _, newPhase in
            switch newPhase {
            case .success: return .success
            case .failed: return .error
            default: return nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Aurora.violet.opacity(0.5))
                    .frame(width: 130, height: 130)
                    .blur(radius: 42)
                AppIconView(url: iconURL, symbol: symbol, size: 104)
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            }
            VStack(spacing: 4) {
                Text(target.title)
                    .font(.title.bold())
                    .foregroundStyle(Aurora.frost)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Aurora.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private var iconURL: URL? { nil }

    private var symbol: String { "doc.zipper" }

    private var subtitle: String {
        if let email = signingEmail, !email.isEmpty { return "Signed with \(email)" }
        return "Signed with your own Apple ID"
    }

    private var signingEmail: String? {
        selected.isEmpty ? (email.isEmpty ? nil : email) : selected
    }

    private var navigationTitle: String {
        switch controller.phase {
        case .success: "Installed"
        case .failed: "Install Failed"
        case .idle: actionVerb
        default: "Installing"
        }
    }

    private var actionVerb: String {
        let file = target.url.lastPathComponent
        return controller.apps.contains { $0.ipaFile == file } ? "Refresh" : "Sign & Install"
    }

    // MARK: - Steps

    @ViewBuilder
    private var step: some View {
        switch controller.phase {
        case .idle:
            if pairings.selfPairing == nil {
                GlassCard(tint: Aurora.danger) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Pair this iPhone first", systemImage: "link.badge.plus")
                            .font(.headline)
                        Text("Dionysos needs this iPhone's pairing file to talk to it, the way a computer would.")
                            .font(.subheadline)
                            .foregroundStyle(Aurora.secondaryText)
                    }
                }
            } else {
                signInForm
            }

        case .checking:
            stepsCard(detail: "Getting ready…")

        case .downloading:
            stepsCard(detail: "Downloading \(target.title)…")

        case .needsVPN:
            VStack(spacing: 16) {
                stepsCard(detail: nil)
                GlassCard(tint: Aurora.violet) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Turn on LocalDevVPN", systemImage: "network.badge.shield.half.filled")
                            .font(.headline)
                        Text("LocalDevVPN loops traffic for \(LocalDevVPN.targetIP) back into this iPhone, so Dionysos can reach it like a computer would. It only carries that one address, and your normal internet traffic isn't affected.")
                            .font(.subheadline)
                            .foregroundStyle(Aurora.secondaryText)
                        if !LocalDevVPN.isInstalled {
                            Text("It's free on the App Store. Install it, open it once to add the VPN configuration, then come back here.")
                                .font(.footnote)
                                .foregroundStyle(Aurora.secondaryText)
                        }
                    }
                }
            }

        case .working(let stage, _):
            stepsCard(detail: stage)

        case .success(let app):
            VStack(spacing: 18) {
                GlassBadge(systemImage: "checkmark", tint: Aurora.success, size: 88)
                GlassCard(tint: Aurora.success) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(app.name) \(app.version) is on your Home Screen")
                            .font(.headline)
                        if let expiration = app.expiration {
                            Text("Signed until \(expiration.formatted(date: .abbreviated, time: .shortened)) with \(app.accountEmail ?? "your Apple ID"). Dionysos reminds you the day before.")
                                .font(.subheadline)
                                .foregroundStyle(Aurora.secondaryText)
                        }
                        if let note = controller.pairingNote {
                            Label(note, systemImage: "doc.badge.gearshape")
                                .font(.footnote)
                                .foregroundStyle(Aurora.lilac)
                        }
                        Text("First launch: if iOS says the developer isn't trusted, open **Settings › General › VPN & Device Management**, tap your Apple ID and choose **Trust**.")
                            .font(.footnote)
                            .foregroundStyle(Aurora.secondaryText)
                    }
                }
            }

        case .failed(let message):
            VStack(spacing: 18) {
                GlassBadge(systemImage: "xmark", tint: Aurora.danger, size: 88)
                GlassCard(tint: Aurora.danger) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Stopped at: \(controller.step.title(for: target))", systemImage: controller.step.symbol)
                            .font(.subheadline.weight(.semibold))
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Aurora.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    /// Progress bar over every step (LocalDevVPN, device link, sign in, sign, install…)
    /// with a checklist underneath.
    private func stepsCard(detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(controller.step.title(for: target))
                    .font(.headline)
                    .contentTransition(.opacity)
                Spacer()
                Text(controller.overallProgress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Aurora.secondaryText)
                    .contentTransition(.numericText())
            }

            GlassProgressBar(value: controller.overallProgress)

            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Aurora.secondaryText)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(controller.steps) { item in
                    stepRow(item)
                }
            }
            .padding(.top, 2)

            Text("Keep Dionysos open until this finishes.")
                .font(.caption)
                .foregroundStyle(Aurora.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Aurora.hairline, lineWidth: 1)
        }
        .animation(.spring(duration: 0.4), value: controller.step)
    }

    private func stepRow(_ item: InstallStep) -> some View {
        let current = controller.step
        let waitingForVPN = controller.phase == .needsVPN && item == .vpn
        return HStack(spacing: 12) {
            ZStack {
                if item < current {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Aurora.success)
                } else if item == current {
                    if waitingForVPN {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Aurora.orchid)
                    } else {
                        ProgressRing(value: controller.stepFraction, lineWidth: 3, size: 20, showsPercent: false)
                    }
                } else {
                    Image(systemName: item.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Aurora.secondaryText.opacity(0.6))
                }
            }
            .frame(width: 24, height: 24)

            Text(item.title(for: target))
                .font(.subheadline.weight(item == current ? .semibold : .regular))
                .foregroundStyle(item > current ? Aurora.secondaryText : Aurora.frost)
            Spacer(minLength: 0)
            if item == current, let fraction = controller.stepFraction {
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Aurora.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sign in

    private var isNewAccount: Bool { selected.isEmpty }

    private func pick(_ choice: String) {
        email = choice
        password = choice.isEmpty ? "" : (AppleIDStore.password(for: choice) ?? "")
        remember = true
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Sign With")
            if !accounts.accounts.isEmpty { accountMenu }

            VStack(spacing: 0) {
                if isNewAccount {
                    TextField("Apple ID email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                    Divider()
                        .overlay(Color.white.opacity(0.15))
                        .padding(.horizontal, 16)
                }
                SecureField(isNewAccount || password.isEmpty ? "Password" : "Password (saved)", text: $password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(start)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                Divider()
                    .overlay(Color.white.opacity(0.15))
                    .padding(.horizontal, 16)
                Toggle("Remember password", isOn: $remember)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
            }
            .glassEffect(.regular.tint(Aurora.card.opacity(0.6)), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Aurora.hairline, lineWidth: 1)
            }

            DisclaimerCard(accepted: $disclaimerAccepted)

            Text("Your password goes only to Apple, and a remembered one stays in this iPhone's Keychain. Apple also needs device-identity headers (\"anisette\"), which Dionysos gets from \(anisetteHost). With a free Apple ID an app lasts 7 days, 3 sideloaded apps can be active at once, and you can register 10 App IDs per week.")
                .font(.system(size: 13))
                .foregroundStyle(Aurora.secondaryText)
                .padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accountMenu: some View {
        Menu {
            Picker("Apple ID", selection: $selected) {
                ForEach(accounts.accounts) { account in
                    Text(account.email).tag(account.email)
                }
                Label("Add Another Apple ID", systemImage: "person.badge.plus").tag("")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isNewAccount ? "person.badge.plus" : "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Aurora.frost)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.tint(Aurora.violet.opacity(0.5)), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isNewAccount ? "New Apple ID" : selected)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Aurora.frost)
                        .lineLimit(1)
                    Text(accountDetail)
                        .font(.caption)
                        .foregroundStyle(Aurora.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Aurora.secondaryText)
            }
            .padding(12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)).interactive(), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Aurora.hairline, lineWidth: 1)
        }
        .onChange(of: selected) { _, value in pick(value) }
    }

    private var accountDetail: String {
        guard let account = accounts.account(selected) else { return "Enter the email and password below" }
        var parts: [String] = []
        if let team = account.teamName ?? account.teamID { parts.append("Team \(team)") }
        let signed = controller.apps.filter { $0.accountEmail == account.email && !$0.isExpired }.count
        parts.append("\(signed) active app\(signed == 1 ? "" : "s")")
        if selected == accounts.active?.email { parts.append("Default") }
        return parts.joined(separator: " · ")
    }

    private var anisetteHost: String {
        URL(string: controller.anisetteURL)?.host() ?? controller.anisetteURL
    }

    private var canStart: Bool {
        disclaimerAccepted && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func start() {
        guard canStart else { return }
        focus = nil
        controller.install(
            with: AppleIDCredentials(email: email.trimmingCharacters(in: .whitespaces), password: password),
            remember: remember)
    }

    // MARK: - Bottom actions

    @ViewBuilder
    private var actions: some View {
        switch controller.phase {
        case .idle:
            if pairings.selfPairing == nil {
                GlassActionButton(title: "Go to Pair", systemImage: "antenna.radiowaves.left.and.right", prominent: true) {
                    controller.finish()
                    onGoToPair()
                }
            } else {
                GlassActionButton(title: LocalizedStringKey(actionVerb), systemImage: "signature", prominent: true, action: start)
                    .disabled(!canStart)
                    .opacity(canStart ? 1 : 0.55)
            }

        case .checking, .downloading, .working:
            GlassActionButton(title: "Cancel", systemImage: "xmark") { controller.cancel() }

        case .needsVPN:
            VStack(spacing: 12) {
                GlassActionButton(
                    title: LocalDevVPN.isInstalled ? "Turn On LocalDevVPN" : "Get LocalDevVPN",
                    systemImage: LocalDevVPN.isInstalled ? "power" : "arrow.down.app",
                    prominent: true
                ) {
                    LocalDevVPN.turnOn()
                }
                GlassActionButton(title: "It's On, Continue", systemImage: "arrow.right") {
                    controller.resumeAfterVPN(skipCheck: true)
                }
            }

        case .success:
            GlassActionButton(title: "Done", systemImage: "checkmark", prominent: true, tint: Aurora.success) {
                controller.finish()
            }

        case .failed:
            VStack(spacing: 12) {
                GlassActionButton(title: "Try Again", systemImage: "arrow.clockwise", prominent: true) {
                    controller.reset()
                }
                GlassActionButton(title: "Close") { controller.finish() }
            }
        }
    }

    private var phaseKey: String {
        switch controller.phase {
        case .idle: "idle"
        case .checking: "checking"
        case .downloading: "downloading"
        case .needsVPN: "vpn"
        case .working: "working"
        case .success: "success"
        case .failed: "failed"
        }
    }
}
