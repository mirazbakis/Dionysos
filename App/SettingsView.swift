import SwiftUI

struct SettingsView: View {
    @StateObject private var pairing = PairingController.shared
    @StateObject private var install = InstallController.shared
    @StateObject private var anisette = AnisetteServers.shared
    @State private var anisetteChoice = ""
    private static let customTag = "custom"
    @StateObject private var accounts = AccountStore.shared
    @State private var targetIP = LocalDevVPN.targetIP
    @State private var vpnActive = LocalDevVPN.isActive

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        DionysosMark(size: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Dionysos")
                                .font(.title2.bold())
                                .foregroundStyle(Aurora.frost)
                            Text("Version \(version)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Your apps, signed with your own Apple ID")
                                .font(.caption)
                                .foregroundStyle(Aurora.lilac.opacity(0.8))
                            Text("An app by mbakis")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Aurora.orchid)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)

                Section {
                    LabeledContent("Default", value: accounts.active?.email ?? "None yet")
                    LabeledContent("Saved accounts", value: "\(accounts.accounts.count)")
                    Button("Forget All Apple IDs and Passwords", role: .destructive) {
                        for account in accounts.accounts { AccountController.shared.forget(account.email) }
                        accounts.removeAll()
                    }
                    .disabled(accounts.accounts.isEmpty)
                } header: {
                    Text("Apple IDs")
                } footer: {
                    Text("Add, switch and manage accounts in the Accounts tab. \(AccountDisclaimer.body)")
                }
                .auroraRow()

                Section {
                    LabeledContent("Status", value: vpnActive ? "Connected" : "Not connected")
                    TextField("10.7.0.1", text: $targetIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .onChange(of: targetIP) { _, value in LocalDevVPN.targetIP = value }
                    Button(LocalDevVPN.isInstalled ? "Turn On LocalDevVPN" : "Get LocalDevVPN") {
                        LocalDevVPN.turnOn()
                    }
                } header: {
                    Text("LocalDevVPN")
                } footer: {
                    Text("Installs go through LocalDevVPN, which loops this address back into the iPhone. Only change it if you changed LocalDevVPN's peer IP.")
                }
                .auroraRow()

                Section {
                    Picker("Server", selection: $anisetteChoice) {
                        ForEach(anisette.servers) { server in
                            Text(server.name).tag(server.address)
                        }
                        Text("Custom…").tag(Self.customTag)
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: anisetteChoice) { _, choice in
                        if choice != Self.customTag { install.anisetteURL = choice }
                    }

                    if anisetteChoice == Self.customTag {
                        TextField("https://…", text: $install.anisetteURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        LabeledContent("Address") {
                            Text(install.anisetteURL)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack {
                        Text("Anisette server")
                        if anisette.isLoading { ProgressView().controlSize(.mini) }
                    }
                } footer: {
                    Text("Apple requires device-identity headers (\"anisette\") to sign in. The server never sees your password. If sign-in fails, try another server. The list comes from SideStore's community servers.")
                }
                .auroraRow()


                Section {
                    Toggle("Silent audio", systemImage: "speaker.wave.2", isOn: $pairing.keepAliveAudio)
                    Toggle("Location", systemImage: "location", isOn: $pairing.keepAliveLocation)
                } header: {
                    Text("Background keep-alive")
                } footer: {
                    Text("Turn one on if the Live Activity doesn't start while you pair from Settings.")
                }
                .auroraRow()

                Section {
                    LabeledContent("Version", value: version)
                    NavigationLink {
                        AcknowledgmentsView()
                    } label: {
                        Label("Acknowledgments", systemImage: "heart.text.square.fill")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Dionysos isn't affiliated with Apple, AltStore, SideStore or any of the projects it credits. Only use it with Apple IDs you own.")
                }
                .auroraRow()

                Section("Legal") {
                    Link("Dionysos License", destination: URL(string: "https://github.com/mirazbakis/Dionysos/blob/main/LICENSE.md")!)
                    Link("Third-Party Notices", destination: URL(string: "https://github.com/mirazbakis/Dionysos/blob/main/THIRD_PARTY_NOTICES.md")!)
                    Link("Security Policy", destination: URL(string: "https://github.com/mirazbakis/Dionysos/blob/main/SECURITY.md")!)
                }
                .auroraRow()
            }
            .auroraListBackground()
            .navigationTitle("Settings")
            .task {
                await anisette.refresh()
                syncAnisetteChoice()
            }
            .onAppear {
                syncAnisetteChoice()
                vpnActive = LocalDevVPN.isActive
            }
        }
    }

    private func syncAnisetteChoice() {
        anisetteChoice = anisette.servers.contains { $0.address == install.anisetteURL }
            ? install.anisetteURL : Self.customTag
    }

}
