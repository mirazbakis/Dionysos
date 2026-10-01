import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var store = PairingStore.shared
    @StateObject private var install = InstallController.shared
    @StateObject private var accounts = AccountStore.shared
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        List {
            Section {
                if install.apps.isEmpty {
                    ContentUnavailableView(
                        "No apps yet",
                        systemImage: "square.stack.3d.up",
                        description: Text("Sign an IPA from the Sign tab and it shows up here."))
                        .auroraRow()
                } else {
                    ForEach(install.apps) { app in
                        appRow(app)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                if let target = app.refreshTarget {
                                    Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
                                        install.begin(target, account: app.accountEmail)
                                    }
                                    Menu("Re-sign With…", systemImage: "person.2") {
                                        ForEach(accounts.accounts) { account in
                                            Button(account.email) { install.begin(target, account: account.email) }
                                        }
                                    }
                                }
                                Button("Remove from List", systemImage: "minus.circle", role: .destructive) {
                                    install.forget(app)
                                }
                            }
                            .swipeActions {
                                Button("Remove", systemImage: "minus.circle", role: .destructive) {
                                    install.forget(app)
                                }
                            }
                    }
                }
            } header: {
                Text("Installed by Dionysos")
            } footer: {
                Text("Tap the pill to refresh an app with the Apple ID that signed it. Long-press to re-sign it with another of your accounts. Removing an app here only stops Dionysos tracking it. Delete it from the Home Screen to uninstall.")
            }

            Section {
                if store.items.isEmpty {
                    ContentUnavailableView(
                        "No pairing files yet",
                        systemImage: "tray",
                        description: Text("Pair this iPhone from the Sign tab, or import a pairing file."))
                } else {
                    ForEach(store.items) { item in
                        row(item)
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    store.delete(item)
                                }
                            }
                            .contextMenu {
                                if !item.isAppleTV {
                                    Button("Use for Installs on This iPhone", systemImage: "iphone.gen3") {
                                        store.selfPairingID = item.id
                                    }
                                }
                                ShareLink(item: item.fileURL)
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    store.delete(item)
                                }
                            }
                    }
                }
            } header: {
                Text("Pairing files")
            } footer: {
                Text("The file marked **This iPhone** is used for installs. Long-press to change it. Files also appear in **Files › On My iPhone › Dionysos**.")
            }
            .auroraRow()
        }
        .auroraListBackground()
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showImporter = true
                } label: {
                    Label("Import Pairing File", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.propertyList, .xml, .data]) { result in
            switch result {
            case .success(let url):
                do { _ = try store.importFile(at: url) } catch { importError = error.localizedDescription }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Couldn't import", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func row(_ item: SavedPairing) -> some View {
        HStack(spacing: 14) {
            icon(item.isAppleTV ? "appletv" : "iphone.gen3", tint: Aurora.violet)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName).font(.headline)
                    if store.selfPairing?.id == item.id {
                        Text("This iPhone")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Aurora.frost)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassEffect(.regular.tint(Aurora.violet.opacity(0.5)), in: .capsule)
                    }
                }
                Text([item.model, item.date.formatted(date: .abbreviated, time: .shortened)]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            ShareLink(item: item.fileURL) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Export \(item.displayName) pairing file")
        }
        .padding(.vertical, 4)
    }

    private func icon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(Aurora.frost)
            .frame(width: 44, height: 44)
            .glassEffect(.regular.tint(tint.opacity(0.45)), in: .circle)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        AppBannerRow(
            name: app.name,
            detail: detail(app),
            detailColor: app.isExpired ? Aurora.danger : Aurora.secondaryText,
            iconURL: nil,
            symbol: "app.fill"
        ) {
            if let target = app.refreshTarget {
                if app.isExpired {
                    PillButton(caption: "Expired", title: "Refresh", tint: Aurora.danger) { install.begin(target, account: app.accountEmail) }
                } else if let days = app.daysLeft {
                    PillButton(caption: "Expires in", title: "\(days) day\(days == 1 ? "" : "s")") { install.begin(target, account: app.accountEmail) }
                } else {
                    PillButton(title: "Refresh") { install.begin(target, account: app.accountEmail) }
                }
            } else {
                // The IPA was deleted from the library: it has to be imported again.
                PillButton(caption: "Expires in", title: "\(app.daysLeft ?? 0) days", tint: Aurora.lilac, prominent: false) {}
                    .disabled(true)
            }
        }
    }

    private func detail(_ app: InstalledApp) -> String {
        if app.refreshTarget == nil {
            return "Version \(app.version) · Import the IPA again to refresh"
        }
        let who = app.accountEmail.map { " · \($0)" } ?? ""
        return "Version \(app.version) · \(expiryText(app))\(who)"
    }

    private func expiryText(_ app: InstalledApp) -> String {
        guard let expiration = app.expiration else { return "Installed \(app.installedAt.formatted(date: .abbreviated, time: .omitted))" }
        return app.isExpired
            ? "Expired \(expiration.formatted(.relative(presentation: .named)))"
            : "Expires \(expiration.formatted(.relative(presentation: .named)))"
    }
}
