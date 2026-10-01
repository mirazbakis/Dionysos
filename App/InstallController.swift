import DionysosFFI
import Foundation
import UIKit
import UserNotifications

/// Where to reach this iPhone's RemotePairing service (via LocalDevVPN).
struct SelfEndpoint: Sendable {
    let host: String
    let port: Int
}

/// What an install flow signs and installs: an IPA from the user's IPA library.
enum InstallTarget: Identifiable, Equatable {
    case ipa(URL)

    var id: String {
        switch self {
        case .ipa(let url): "ipa.\(url.lastPathComponent)"
        }
    }

    var url: URL {
        switch self {
        case .ipa(let url): url
        }
    }

    var title: String { url.deletingPathExtension().lastPathComponent }
}

/// The stages shown in the install flow's progress bar.
enum InstallStep: Int, CaseIterable, Identifiable, Comparable {
    case download, vpn, link, signIn, sign, install, pairing

    var id: Int { rawValue }

    func title(for target: InstallTarget) -> String {
        switch self {
        case .download: "Prepare the IPA"
        case .vpn: "Connect to LocalDevVPN"
        case .link: "Open device link"
        case .signIn: "Sign in to Apple"
        case .sign: "Sign the app"
        case .install: "Install the app"
        case .pairing: "Place pairing file"
        }
    }

    var symbol: String {
        switch self {
        case .download: "arrow.down.circle"
        case .vpn: "network.badge.shield.half.filled"
        case .link: "link"
        case .signIn: "person.crop.circle.badge.checkmark"
        case .sign: "signature"
        case .install: "square.and.arrow.down.on.square"
        case .pairing: "doc.badge.gearshape"
        }
    }

    /// Share of the whole bar each step takes.
    var weight: Double {
        switch self {
        case .download: 0.15
        case .vpn: 0.03
        case .link: 0.07
        case .signIn: 0.15
        case .sign: 0.2
        case .install: 0.35
        case .pairing: 0.05
        }
    }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// An app Dionysos signed and installed.
struct InstalledApp: Codable, Equatable, Identifiable {
    let bundleID: String
    let name: String
    let version: String
    let teamID: String
    let expiration: Date?
    let installedAt: Date
    /// The file in the IPA library, used to refresh it later.
    var ipaFile: String? = nil
    /// The Apple ID that signed it, so a refresh uses the same account.
    var accountEmail: String? = nil

    var id: String { bundleID }

    var daysLeft: Int? {
        guard let expiration else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: .now, to: expiration).day ?? 0)
    }

    var isExpired: Bool { (expiration ?? .distantFuture) < .now }

    /// How to sign this app again.
    var refreshTarget: InstallTarget? {
        guard let ipaFile else { return nil }
        let url = IPAStore.directory.appendingPathComponent(ipaFile)
        return FileManager.default.fileExists(atPath: url.path) ? .ipa(url) : nil
    }
}

struct TwoFactorPrompt: Identifiable, Equatable {
    struct TrustedNumber: Identifiable, Equatable, Decodable {
        let id: Int
        let number: String
    }

    let id = UUID()
    let sms: Bool
    let unknown: Bool
    let lastError: String?
    let numbers: [TrustedNumber]
    let selectedNumberID: Int?
}

struct RevokePrompt: Identifiable, Equatable {
    struct Certificate: Identifiable, Equatable, Decodable {
        let serial: String
        let name: String
        let machine: String
        var id: String { serial }
    }

    let id = UUID()
    let certificates: [Certificate]
}

/// Drives on-device installs: fetch → download → check LocalDevVPN →
/// Rust (tunnel via 10.7.0.1, Apple ID, sign, install) → remember the result.
@MainActor
final class InstallController: ObservableObject {
    static let shared = InstallController()

    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Double)
        /// Waiting for LocalDevVPN to be switched on. The install resumes from here.
        case needsVPN
        case working(String, Double?)
        case success(InstalledApp)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    /// The install flow on screen (full-screen cover), or nil.
    @Published var flow: InstallTarget?
    /// The Apple ID picked for the flow on screen (e.g. the one that signed an app being refreshed).
    @Published var flowAccount: String?
    /// Everything Dionysos installed, newest first.
    @Published private(set) var apps: [InstalledApp] = []
    @Published var twoFactor: TwoFactorPrompt?
    @Published var revoke: RevokePrompt?
    /// Where the install is, for the progress bar.
    @Published private(set) var step: InstallStep = .download
    /// Progress inside `step`, when known.
    @Published private(set) var stepFraction: Double?
    /// Steps this install goes through (the pairing step is added only for SideStore-family apps).
    @Published private(set) var steps: [InstallStep] = InstallStep.allCases
    /// Set after installing a SideStore-family app: whether the pairing file went in.
    @Published private(set) var pairingNote: String?

    @Published var anisetteURL: String = UserDefaults.standard.string(forKey: "anisette.url") ?? InstallController.defaultAnisette {
        didSet { UserDefaults.standard.set(anisetteURL, forKey: "anisette.url") }
    }

    static let defaultAnisette = "https://ani.sidestore.io"

    private var session: OpaquePointer?
    /// Install parked at `.needsVPN`, with the IPA already downloaded.
    private var pending: (credentials: AppleIDCredentials, target: InstallTarget, ipa: URL)?
    private let appsKey = "installed.apps"

    var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .working: true
        default: false
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: appsKey),
           let saved = try? JSONDecoder().decode([InstalledApp].self, from: data) {
            apps = saved
        }
    }

    /// Stable ID passed to the signer as ALTServerID (only used if the IPA is an AltStore-family app).
    nonisolated static var serverID: String {
        if let id = UserDefaults.standard.string(forKey: "dionysos.serverID") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "dionysos.serverID")
        return id
    }

    // MARK: - Library

    /// Stops listing an app. It stays on the iPhone until the user deletes it there.
    func forget(_ app: InstalledApp) {
        apps.removeAll { $0.bundleID == app.bundleID }
        save()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID(app)])
    }

    private func save() {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: appsKey)
        }
    }

    // MARK: - Flow

    /// Opens the full-screen install flow for `target`.
    func begin(_ target: InstallTarget, account: String? = nil) {
        guard !isBusy else { return }
        flowAccount = account
        pending = nil
        phase = .idle
        pairingNote = nil
        configureSteps(for: target)
        flow = target
    }

    private func configureSteps(for target: InstallTarget) {
        steps = InstallStep.allCases.filter { $0 != .pairing }
        step = .download
        stepFraction = nil
    }

    private func enter(_ newStep: InstallStep, _ fraction: Double? = nil) {
        if newStep == .pairing && !steps.contains(.pairing) { steps.append(.pairing) }
        step = newStep
        stepFraction = fraction
    }

    /// 0…1 across all steps, for the progress bar.
    var overallProgress: Double {
        let total = steps.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        if case .success = phase { return 1 }
        let done = steps.filter { $0 < step }.reduce(0) { $0 + $1.weight }
        return min(1, (done + step.weight * (stepFraction ?? 0)) / total)
    }

    /// Closes the flow. Ignored while an install is running.
    func finish() {
        guard !isBusy else { return }
        pending = nil
        phase = .idle
        flow = nil
        flowAccount = nil
    }

    // MARK: - Install

    /// Signs and installs the flow's target with this Apple ID.
    func install(with credentials: AppleIDCredentials, remember: Bool) {
        guard !isBusy, let target = flow else { return }
        AccountStore.shared.upsert(credentials.email, password: credentials.password, remember: remember)
        Task { await run(credentials, target: target) }
    }

    /// Back to the sign-in step of the current flow.
    func reset() {
        guard !isBusy else { return }
        pending = nil
        phase = .idle
    }

    /// Waits up to ~6 s for the VPN interface to come up (LocalDevVPN hands control
    /// back before the tunnel is fully configured), then resumes.
    func resumeWhenVPNReady() {
        guard case .needsVPN = phase else { return }
        Task {
            for _ in 0..<12 {
                if LocalDevVPN.isActive {
                    resumeAfterVPN()
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// Continue an install parked at `.needsVPN`, e.g. when LocalDevVPN sends
    /// the user back via `dionysos://`.
    func resumeAfterVPN(skipCheck: Bool = false) {
        guard case .needsVPN = phase, let pending else { return }
        self.pending = nil
        Task { await run(pending.credentials, target: pending.target, ipaOverride: pending.ipa, skipVPNCheck: skipCheck) }
    }

    func respond(_ response: String) {
        twoFactor = nil
        revoke = nil
        guard let session else { return }
        _ = response.withCString { dionysos_install_session_respond(session, $0) }
    }

    func cancel() {
        twoFactor = nil
        revoke = nil
        if let session { dionysos_install_session_cancel(session) }
    }

    private func run(_ credentials: AppleIDCredentials, target: InstallTarget, ipaOverride: URL? = nil, skipVPNCheck: Bool = false) async {
        guard let pairing = PairingStore.shared.selfPairing else {
            phase = .failed("There's no pairing file for this iPhone yet. Create one in Sign › Pair This iPhone first.")
            return
        }

        phase = .checking
        pairingNote = nil
        enter(.download)
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        // 1. The IPA.
        let ipa = ipaOverride ?? target.url
        guard FileManager.default.fileExists(atPath: ipa.path) else {
            phase = .failed("The IPA is no longer in your library. Import it again.")
            return
        }

        // 2. LocalDevVPN has to be on so 10.7.0.1 loops back into this iPhone.
        enter(.vpn)
        if !skipVPNCheck && !LocalDevVPN.isActive {
            pending = (credentials, target, ipa)
            phase = .needsVPN
            return
        }
        let endpoints = [SelfEndpoint(host: LocalDevVPN.targetIP, port: LocalDevVPN.remotePairingPort)]

        // 3. Rust does the rest.
        enter(.link)
        phase = .working("Connecting to this device…", nil)
        let outcome = await runSession(
            credentials: credentials,
            pairingPath: pairing.fileURL.path,
            endpoints: endpoints,
            ipa: ipa,
            fallbackName: target.title)

        switch outcome {
        case .installed(var app):
            app.ipaFile = target.url.lastPathComponent
            app.accountEmail = credentials.email
            AccountStore.shared.noteUsed(credentials.email, teamID: app.teamID)
            // SideStore-family apps need this iPhone's pairing file in their Documents.
            if PairingDestination.isSideStoreFamily(app.bundleID) {
                await placePairingFile(in: app.bundleID, pairing: pairing.fileURL)
            }
            apps.removeAll { $0.bundleID == app.bundleID }
            apps.insert(app, at: 0)
            save()
            scheduleExpiryReminder(for: app)
            phase = .success(app)
        case .failed(let message):
            if message == "Cancelled." {
                phase = .idle
            } else if message.localizedCaseInsensitiveContains("anisette") {
                phase = .failed(message + "\n\nThe anisette server may be down. Pick another one in Settings › Anisette server and try again.")
            } else {
                phase = .failed(message)
            }
        }
    }

    private enum Outcome {
        case installed(InstalledApp)
        case failed(String)
    }

    private func runSession(
        credentials: AppleIDCredentials,
        pairingPath: String,
        endpoints: [SelfEndpoint],
        ipa: URL,
        fallbackName: String
    ) async -> Outcome {
        guard let session = dionysos_install_session_new() else {
            return .failed("Couldn't start an install session.")
        }
        self.session = session
        let ctx = Unmanaged.passRetained(self).toOpaque()
        let ctxBits = UInt(bitPattern: ctx)
        let sessionBits = UInt(bitPattern: session)
        let anisette = anisetteURL.isEmpty ? Self.defaultAnisette : anisetteURL
        let serverID = Self.serverID
        let deviceName = UIDevice.current.name

        let outcome: Outcome = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let session = OpaquePointer(bitPattern: sessionBits) else {
                    continuation.resume(returning: .failed("Invalid session."))
                    return
                }
                var owned: [UnsafeMutablePointer<CChar>] = []
                func c(_ s: String) -> UnsafePointer<CChar>? {
                    guard let p = strdup(s) else { return nil }
                    owned.append(p)
                    return UnsafePointer(p)
                }

                let endpointBuffer = UnsafeMutablePointer<DionysosEndpoint>.allocate(capacity: max(endpoints.count, 1))
                for (i, e) in endpoints.enumerated() {
                    endpointBuffer[i] = DionysosEndpoint(
                        host: c(e.host),
                        port: UInt16(clamping: e.port),
                        identifier: nil,
                        auth_tag: nil)
                }

                var config = DionysosInstallConfig(
                    apple_id: c(credentials.email),
                    password: c(credentials.password),
                    anisette_url: c(anisette),
                    pairing_file_path: c(pairingPath),
                    host_name: c("Dionysos"),
                    endpoints: UnsafePointer(endpointBuffer),
                    endpoint_count: endpoints.count,
                    ipa_path: c(ipa.path),
                    device_name: c(deviceName),
                    machine_name: c("Dionysos"),
                    server_id: c(serverID))

                var result = DionysosInstallResult()
                let rc = dionysos_install_session_run(
                    session, &config,
                    installProgressCallback, installPromptCallback,
                    UnsafeMutableRawPointer(bitPattern: ctxBits), &result)

                let outcome: Outcome
                if rc == 0 {
                    let expiry = result.expiration_unix > 0
                        ? Date(timeIntervalSince1970: TimeInterval(result.expiration_unix))
                        : Calendar.current.date(byAdding: .day, value: 7, to: .now)
                    outcome = .installed(InstalledApp(
                        bundleID: string(result.bundle_id),
                        name: string(result.app_name).isEmpty ? fallbackName : string(result.app_name),
                        version: string(result.app_version),
                        teamID: string(result.team_id),
                        expiration: expiry,
                        installedAt: .now))
                } else {
                    let message = string(result.error)
                    outcome = .failed(message.isEmpty ? "Install failed (code \(rc))." : message)
                }
                dionysos_install_result_free(&result)

                // Wipe secrets before freeing.
                for p in owned {
                    memset(p, 0, strlen(p))
                    free(p)
                }
                endpointBuffer.deallocate()
                continuation.resume(returning: outcome)
            }
        }

        dionysos_install_session_free(session)
        self.session = nil
        Unmanaged<InstallController>.fromOpaque(ctx).release()
        twoFactor = nil
        revoke = nil
        return outcome
    }

    // MARK: - Callbacks from Rust (hopped to main)

    /// Copies the pairing file into a freshly installed SideStore-family app. Not fatal:
    /// the user can add it to the app by hand.
    private func placePairingFile(in bundleID: String, pairing: URL) async {
        enter(.pairing)
        phase = .working("Placing pairing file…", nil)
        do {
            try await DeviceOps.placeFile(pairing, in: bundleID, as: PairingDestination.path(for: bundleID))
            pairingNote = "This iPhone's pairing file is already inside the app."
        } catch {
            pairingNote = "Couldn't place the pairing file (\(error.localizedDescription)). Add it to the app by hand."
        }
    }

    fileprivate func updateProgress(_ stage: String, _ fraction: Double) {
        guard isBusy else { return }
        let value: Double? = fraction < 0 ? nil : fraction
        let lower = stage.lowercased()
        if lower.hasPrefix("signing in") || lower.hasPrefix("registering") {
            enter(.signIn, value)
        } else if lower.hasPrefix("signing") || lower.hasPrefix("preparing") {
            enter(.sign, value)
        } else if lower.hasPrefix("installing") {
            enter(.install, value)
        } else {
            enter(.link, value)
        }
        phase = .working(stage, fraction < 0 ? nil : fraction)
    }

    fileprivate func presentPrompt(kind: Int32, json: Data) {
        switch kind {
        case 1:
            struct Payload: Decodable {
                let unknown: Bool
                let sms: Bool
                let lastError: String?
                let selectedNumberId: Int?
                let numbers: [TwoFactorPrompt.TrustedNumber]
            }
            guard let p = try? JSONDecoder().decode(Payload.self, from: json) else {
                respond("devices")
                return
            }
            twoFactor = TwoFactorPrompt(
                sms: p.sms, unknown: p.unknown, lastError: p.lastError,
                numbers: p.numbers, selectedNumberID: p.selectedNumberId)
        case 2:
            let certs = (try? JSONDecoder().decode([RevokePrompt.Certificate].self, from: json)) ?? []
            revoke = RevokePrompt(certificates: certs)
        default:
            respond("abort")
        }
    }

    // MARK: - Reminder

    private func reminderID(_ app: InstalledApp) -> String {
        "dionysos.expiry.\(app.bundleID)"
    }

    private func scheduleExpiryReminder(for app: InstalledApp) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID(app)])
        guard let expiration = app.expiration else { return }
        let fireDate = expiration.addingTimeInterval(-24 * 60 * 60)
        guard fireDate > .now else { return }

        let identifier = reminderID(app)
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(app.name) expires tomorrow"
            content.body = "Open Dionysos and tap Refresh to keep it working."
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            UNUserNotificationCenter.current().add(request)
        }
    }
}

private let installProgressCallback: DionysosProgressCb = { ctx, stage, fraction in
    guard let ctx, let stage else { return }
    let controller = Unmanaged<InstallController>.fromOpaque(ctx).takeUnretainedValue()
    let text = String(cString: stage)
    DispatchQueue.main.async {
        controller.updateProgress(text, fraction)
    }
}

private let installPromptCallback: DionysosPromptCb = { ctx, kind, json in
    guard let ctx, let json else { return }
    let controller = Unmanaged<InstallController>.fromOpaque(ctx).takeUnretainedValue()
    let data = Data(String(cString: json).utf8)
    DispatchQueue.main.async {
        controller.presentPrompt(kind: kind, json: data)
    }
}

private func string(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr else { return "" }
    return String(cString: ptr)
}
