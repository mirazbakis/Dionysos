import SwiftUI

/// The user's own Apple IDs: add, switch the default, remove, and open one to
/// manage its certificates, App IDs and devices.
struct AccountsView: View {
    @StateObject private var accounts = AccountStore.shared
    @StateObject private var controller = AccountController.shared
    @StateObject private var install = InstallController.shared
    @State private var showAdd = false
    @State private var pendingRemove: SavedAccount?

    var body: some View {
        NavigationStack {
            AuroraScreen {
                header

                if accounts.accounts.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Apple IDs yet")
                                .font(.headline)
                            Text("Add your own Apple ID to sign apps. You can save more than one, like your main account and a spare one you made, and pick which signs each app.")
                                .font(.subheadline)
                                .foregroundStyle(Aurora.secondaryText)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        SectionLabel(title: "Saved", trailing: "\(accounts.accounts.count)")
                        GlassEffectContainer(spacing: 10) {
                            VStack(spacing: 10) {
                                ForEach(accounts.accounts) { account in
                                    accountRow(account)
                                }
                            }
                        }
                    }
                }

                GlassActionButton(title: "Add Apple ID", systemImage: "person.badge.plus", prominent: true) {
                    showAdd = true
                }

                Text("Free Apple IDs: 7-day signing, 3 active sideloaded apps and 10 new App IDs per week, per account. Only add accounts that are yours.")
                    .font(.system(size: 13))
                    .foregroundStyle(Aurora.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .navigationTitle("Accounts")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: String.self) { email in
                AccountDetailView(email: email)
            }
            .fullScreenCover(isPresented: $showAdd) {
                SignInSheet(anisetteURL: install.anisetteURL) { credentials, remember in
                    accounts.upsert(credentials.email, password: credentials.password, remember: remember)
                    controller.load(credentials.email, with: credentials)
                }
                .auroraTheme()
            }
            .fullScreenCover(item: $controller.twoFactor) { prompt in
                TwoFactorSheet(prompt: prompt) { controller.respond($0) }
                    .auroraTheme()
            }
            .confirmationDialog(
                "Remove this Apple ID?",
                isPresented: Binding(get: { pendingRemove != nil }, set: { if !$0 { pendingRemove = nil } }),
                presenting: pendingRemove
            ) { account in
                Button("Remove \(account.email)", role: .destructive) {
                    controller.forget(account.email)
                    accounts.remove(account)
                    pendingRemove = nil
                }
                Button("Cancel", role: .cancel) { pendingRemove = nil }
            } message: { _ in
                Text("Dionysos forgets the account and its saved password. Apps it signed keep working until they expire, and nothing changes on Apple's side.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            GlassBadge(systemImage: "person.2.fill", tint: Aurora.violet, size: 84)
            Text("Your Apple IDs")
                .font(.title2.bold())
                .foregroundStyle(Aurora.frost)
            Text("Switch which account signs, and manage each one's certificates, App IDs and devices.")
                .font(.subheadline)
                .foregroundStyle(Aurora.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private func accountRow(_ account: SavedAccount) -> some View {
        let isDefault = account.email == accounts.active?.email
        let signed = install.apps.filter { $0.accountEmail == account.email && !$0.isExpired }.count
        return NavigationLink(value: account.email) {
            HStack(spacing: 14) {
                Image(systemName: isDefault ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Aurora.frost)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint((isDefault ? Aurora.violet : Aurora.indigo).opacity(0.55)), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(account.email)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Aurora.frost)
                            .lineLimit(1)
                        if isDefault {
                            Text("Default")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Aurora.frost)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .glassEffect(.regular.tint(Aurora.violet.opacity(0.5)), in: .capsule)
                        }
                    }
                    Text(detail(account, signed: signed))
                        .font(.footnote)
                        .foregroundStyle(Aurora.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if controller.busyEmail == account.email {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)).interactive(), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isDefault ? Aurora.violet.opacity(0.6) : Aurora.hairline, lineWidth: 1)
        }
        .contextMenu {
            if !isDefault {
                Button("Use by Default", systemImage: "checkmark.circle") { accounts.activeEmail = account.email }
            }
            Button("Remove", systemImage: "trash", role: .destructive) { pendingRemove = account }
        }
    }

    private func detail(_ account: SavedAccount, signed: Int) -> String {
        var parts: [String] = []
        if let team = account.teamName, !team.isEmpty { parts.append(team) }
        parts.append("\(signed)/3 apps")
        parts.append(account.hasPassword ? "Password saved" : "Password not saved")
        return parts.joined(separator: " · ")
    }
}

/// One Apple ID: its team, development certificates (revoke), App IDs (delete),
/// registered devices, and the apps it signed on this iPhone.
struct AccountDetailView: View {
    let email: String

    @StateObject private var accounts = AccountStore.shared
    @StateObject private var controller = AccountController.shared
    @StateObject private var install = InstallController.shared
    @State private var askPassword = false
    @State private var pendingRevoke: DevCertificate?
    @State private var pendingDelete: DevAppID?

    private var account: SavedAccount? { accounts.account(email) }
    private var overview: AccountOverview? { controller.overviews[email] }
    private var isBusy: Bool { controller.busyEmail == email }

    var body: some View {
        AuroraScreen {
            header

            if isBusy {
                GlassCard {
                    HStack(spacing: 16) {
                        ProgressRing(value: nil, lineWidth: 6, size: 44)
                        Text(controller.stage)
                            .font(.headline)
                            .contentTransition(.opacity)
                        Spacer(minLength: 0)
                        Button("Cancel") { controller.cancel() }
                            .buttonStyle(.glass)
                    }
                }
            }

            if let error = controller.errors[email] {
                GlassCard(tint: Aurora.danger) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Something went wrong", systemImage: "xmark.octagon.fill")
                            .font(.headline)
                            .foregroundStyle(Aurora.danger)
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Aurora.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            }

            if let overview {
                summary(overview)
                certificates(overview)
                appIDs(overview)
                devices(overview)
            } else if !isBusy {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Load this account")
                            .font(.headline)
                        Text("Dionysos signs in to Apple to list this Apple ID's development certificates, App IDs and devices.")
                            .font(.subheadline)
                            .foregroundStyle(Aurora.secondaryText)
                    }
                }
                GlassActionButton(title: "Load Account", systemImage: "arrow.down.circle", prominent: true, action: load)
            }

            signedApps

            VStack(spacing: 12) {
                if account?.email != accounts.active?.email {
                    GlassActionButton(title: "Use by Default", systemImage: "checkmark.circle") {
                        accounts.activeEmail = email
                    }
                }
                if account?.hasPassword == true {
                    GlassActionButton(title: "Forget Saved Password", systemImage: "key.slash") {
                        AppleIDStore.deletePassword(for: email)
                        accounts.objectWillChange.send()
                    }
                }
            }
        }
        .navigationTitle(account?.teamName ?? "Apple ID")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: load) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(controller.isBusy)
            }
        }
        .fullScreenCover(isPresented: $askPassword) {
            SignInSheet(anisetteURL: install.anisetteURL, prefill: email) { credentials, remember in
                accounts.upsert(credentials.email, password: credentials.password, remember: remember)
                controller.load(credentials.email, with: credentials)
            }
            .auroraTheme()
        }
        .confirmationDialog(
            "Revoke this certificate?",
            isPresented: Binding(get: { pendingRevoke != nil }, set: { if !$0 { pendingRevoke = nil } }),
            presenting: pendingRevoke
        ) { cert in
            Button("Revoke \(cert.displayName)", role: .destructive) {
                controller.revoke([cert], for: email)
                pendingRevoke = nil
            }
            Button("Cancel", role: .cancel) { pendingRevoke = nil }
        } message: { _ in
            Text("Apps signed with this certificate stop opening until they're signed again. This can't be undone.")
        }
        .confirmationDialog(
            "Delete this App ID?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { appID in
            Button("Delete \(appID.identifier)", role: .destructive) {
                controller.deleteAppIDs([appID], for: email)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("The app using it stops opening once its profile is gone. With a free account, deleting doesn't give the weekly slot back. It frees up when the App ID would have expired.")
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: isBusy)
        .task {
            if overview == nil, !controller.isBusy, controller.credentials(for: email) != nil {
                controller.load(email)
            }
        }
    }

    private func load() {
        if !controller.load(email) { askPassword = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            GlassBadge(systemImage: "person.crop.circle.fill", tint: Aurora.violet, size: 80)
            Text(email)
                .font(.title3.bold())
                .foregroundStyle(Aurora.frost)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let team = overview?.team ?? account.flatMap({ a in a.teamID.map { AccountOverview.Team(id: $0, name: a.teamName ?? "") } }) {
                Text(team.name.isEmpty ? "Team \(team.id)" : "\(team.name) · \(team.id)")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Aurora.secondaryText)
            }
            if let updated = controller.lastUpdated[email] {
                Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(Aurora.secondaryText)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Overview sections

    private func summary(_ overview: AccountOverview) -> some View {
        let certs = overview.certificates.filter { !$0.isExpired }.count
        let certLimit = overview.certificateLimit.map { "/\($0)" } ?? ""
        let appIDText: String = {
            if let max = overview.appIds.max, let available = overview.appIds.available {
                return "\(max - available)/\(max)"
            }
            return "\(overview.appIds.items?.count ?? 0)"
        }()
        return HStack(spacing: 10) {
            stat("\(certs)\(certLimit)", "Certificates", "checkmark.seal.fill")
            stat(appIDText, "App IDs", "app.badge")
            stat("\(overview.devices.count)", "Devices", "iphone.gen3")
        }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Aurora.orchid)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(Aurora.frost)
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Aurora.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular.tint(Aurora.card.opacity(0.6)), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Aurora.hairline, lineWidth: 1)
        }
    }

    private func certificates(_ overview: AccountOverview) -> some View {
        VStack(spacing: 10) {
            SectionLabel(title: "Certificates", trailing: "\(overview.certificates.count)")
            GlassCard {
                if overview.certificates.isEmpty {
                    Text("No development certificates. Dionysos makes one the first time it signs with this account.")
                        .font(.subheadline)
                        .foregroundStyle(Aurora.secondaryText)
                } else {
                    VStack(spacing: 14) {
                        ForEach(overview.certificates) { cert in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: cert.isExpired ? "seal" : "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(cert.isExpired ? Aurora.danger : Aurora.success)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(cert.displayName).font(.subheadline.weight(.semibold))
                                        if cert.isDionysos {
                                            GlassChip(text: "Dionysos", tint: Aurora.violet)
                                                .scaleEffect(0.85)
                                        }
                                    }
                                    Text(certDetail(cert))
                                        .font(.caption)
                                        .foregroundStyle(Aurora.secondaryText)
                                    Text(cert.serial)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Aurora.secondaryText.opacity(0.7))
                                        .textSelection(.enabled)
                                }
                                Spacer(minLength: 0)
                                Button(role: .destructive) {
                                    pendingRevoke = cert
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Aurora.danger)
                                }
                                .buttonStyle(.plain)
                                .disabled(controller.isBusy || cert.serial.isEmpty)
                                .accessibilityLabel("Revoke \(cert.displayName)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func certDetail(_ cert: DevCertificate) -> String {
        var parts: [String] = []
        if !cert.type.isEmpty { parts.append(cert.type) }
        if let expiration = cert.expiration {
            parts.append(cert.isExpired ? "Expired \(expiration.formatted(date: .abbreviated, time: .omitted))"
                                        : "Expires \(expiration.formatted(date: .abbreviated, time: .omitted))")
        }
        if !cert.status.isEmpty { parts.append(cert.status) }
        return parts.joined(separator: " · ")
    }

    private func appIDs(_ overview: AccountOverview) -> some View {
        let items = overview.appIds.items ?? []
        return VStack(spacing: 10) {
            SectionLabel(title: "App IDs", trailing: overview.appIds.available.map { "\($0) left this week" })
            GlassCard {
                if let error = overview.appIds.error {
                    Text("Apple didn't return the App IDs: \(error)")
                        .font(.footnote)
                        .foregroundStyle(Aurora.secondaryText)
                } else if items.isEmpty {
                    Text("No App IDs yet. Each app you sign registers one.")
                        .font(.subheadline)
                        .foregroundStyle(Aurora.secondaryText)
                } else {
                    VStack(spacing: 14) {
                        ForEach(items) { appID in
                            HStack(spacing: 12) {
                                Image(systemName: "app.badge")
                                    .font(.title3)
                                    .foregroundStyle(Aurora.orchid)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(appID.name.isEmpty ? appID.identifier : appID.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(appID.identifier)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Aurora.secondaryText)
                                        .textSelection(.enabled)
                                    if let expiration = appID.expiration {
                                        Text("Expires \(expiration.formatted(.relative(presentation: .named)))")
                                            .font(.caption2)
                                            .foregroundStyle(Aurora.secondaryText)
                                    }
                                }
                                Spacer(minLength: 0)
                                Button(role: .destructive) {
                                    pendingDelete = appID
                                } label: {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Aurora.danger)
                                }
                                .buttonStyle(.plain)
                                .disabled(controller.isBusy)
                                .accessibilityLabel("Delete \(appID.identifier)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func devices(_ overview: AccountOverview) -> some View {
        VStack(spacing: 10) {
            SectionLabel(title: "Devices", trailing: "\(overview.devices.count)")
            GlassCard {
                if overview.devices.isEmpty {
                    Text("No devices registered yet. This iPhone is added the first time you sign.")
                        .font(.subheadline)
                        .foregroundStyle(Aurora.secondaryText)
                } else {
                    VStack(spacing: 12) {
                        ForEach(overview.devices) { device in
                            HStack(spacing: 12) {
                                Image(systemName: "iphone.gen3")
                                    .font(.title3)
                                    .foregroundStyle(Aurora.orchid)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name.isEmpty ? "Unnamed device" : device.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(device.udid)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Aurora.secondaryText)
                                        .textSelection(.enabled)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Apps on this iPhone

    @ViewBuilder
    private var signedApps: some View {
        let apps = install.apps.filter { $0.accountEmail == email }
        if !apps.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(title: "Signed on This iPhone", trailing: "\(apps.count)")
                ForEach(apps) { app in
                    AppBannerRow(
                        name: app.name,
                        detail: app.isExpired ? "Expired" : "\(app.daysLeft ?? 0) day\(app.daysLeft == 1 ? "" : "s") left",
                        detailColor: app.isExpired ? Aurora.danger : Aurora.secondaryText,
                        iconURL: nil,
                        symbol: "app.fill"
                    ) {
                        if let target = app.refreshTarget {
                            PillButton(title: "Refresh") { install.begin(target, account: email) }
                        }
                    }
                }
            }
        }
    }
}
