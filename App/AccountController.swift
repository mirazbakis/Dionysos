import DionysosFFI
import Foundation

/// A development certificate on one of the user's own teams.
struct DevCertificate: Identifiable, Hashable, Decodable {
    let serial: String
    let certificateId: String
    let name: String
    let machineName: String
    let machineId: String
    let platform: String
    let type: String
    let maxActive: Int
    let status: String
    let expires: Int64

    var id: String { serial.isEmpty ? certificateId : serial }
    var expiration: Date? { expires > 0 ? Date(timeIntervalSince1970: TimeInterval(expires)) : nil }
    var isExpired: Bool { (expiration ?? .distantFuture) < .now }
    /// Made by Dionysos itself (the signer names the machine after the app).
    var isDionysos: Bool { machineName.caseInsensitiveCompare("Dionysos") == .orderedSame }
    var displayName: String { machineName.isEmpty ? (name.isEmpty ? "Unnamed certificate" : name) : machineName }
}

struct DevAppID: Identifiable, Hashable, Decodable {
    let id: String
    let identifier: String
    let name: String
    let expires: Int64
    var expiration: Date? { expires > 0 ? Date(timeIntervalSince1970: TimeInterval(expires)) : nil }
}

struct DevDevice: Identifiable, Hashable, Decodable {
    let name: String
    let udid: String
    let status: String
    var id: String { udid }
}

struct AccountOverview: Decodable, Equatable {
    struct Team: Decodable, Equatable {
        let id: String
        let name: String
    }
    struct AppIDs: Decodable, Equatable {
        let items: [DevAppID]?
        let max: Int?
        let available: Int?
        let error: String?
    }

    let team: Team
    let certificates: [DevCertificate]
    let appIds: AppIDs
    let devices: [DevDevice]

    var certificateLimit: Int? { certificates.map(\.maxActive).max().flatMap { $0 > 0 ? $0 : nil } }
}

/// Reads and manages what each of the user's own Apple IDs has on Apple's side:
/// development certificates (revoke), App IDs (delete) and registered devices.
/// Uses the same Rust session (and 2FA prompts) as installs. One request at a time.
@MainActor
final class AccountController: ObservableObject {
    static let shared = AccountController()

    @Published private(set) var overviews: [String: AccountOverview] = [:]
    @Published private(set) var lastUpdated: [String: Date] = [:]
    @Published private(set) var errors: [String: String] = [:]
    /// The account a request is running for, and what it's doing.
    @Published private(set) var busyEmail: String?
    @Published private(set) var stage = ""
    @Published var twoFactor: TwoFactorPrompt?

    private var session: OpaquePointer?
    /// Passwords typed this session for accounts that don't remember theirs.
    private var typed: [String: String] = [:]

    var isBusy: Bool { busyEmail != nil }

    private init() {}

    func credentials(for email: String) -> AppleIDCredentials? {
        if let saved = AccountStore.shared.credentials(for: email) { return saved }
        return typed[email].map { AppleIDCredentials(email: email, password: $0) }
    }

    /// Loads the overview, using `credentials` if given (and remembering the
    /// password for this session), otherwise the saved password. Returns false
    /// when there's no password, so the caller can ask for one.
    @discardableResult
    func load(_ email: String, with credentials: AppleIDCredentials? = nil) -> Bool {
        if let credentials { typed[credentials.email] = credentials.password }
        return run(email, request: ["op": "overview"])
    }

    @discardableResult
    func revoke(_ certificates: [DevCertificate], for email: String) -> Bool {
        let serials = certificates.map(\.serial).filter { !$0.isEmpty }
        guard !serials.isEmpty else { return true }
        return run(email, request: ["op": "revoke", "serials": serials])
    }

    @discardableResult
    func deleteAppIDs(_ appIDs: [DevAppID], for email: String) -> Bool {
        let ids = appIDs.map(\.id).filter { !$0.isEmpty }
        guard !ids.isEmpty else { return true }
        return run(email, request: ["op": "delete_app_ids", "ids": ids])
    }

    /// Drops cached data and any typed password (e.g. when the account is removed).
    func forget(_ email: String) {
        overviews[email] = nil
        lastUpdated[email] = nil
        errors[email] = nil
        typed[email] = nil
    }

    func respond(_ response: String) {
        twoFactor = nil
        guard let session else { return }
        _ = response.withCString { dionysos_install_session_respond(session, $0) }
    }

    func cancel() {
        twoFactor = nil
        if let session { dionysos_install_session_cancel(session) }
    }

    // MARK: - Rust bridge

    private func run(_ email: String, request: [String: Any]) -> Bool {
        guard !isBusy else { return true }
        guard let credentials = credentials(for: email) else { return false }
        guard let requestData = try? JSONSerialization.data(withJSONObject: request),
              let requestJSON = String(data: requestData, encoding: .utf8),
              let session = dionysos_install_session_new() else {
            errors[email] = "Couldn't start a session."
            return true
        }
        self.session = session
        busyEmail = email
        errors[email] = nil
        switch request["op"] as? String {
        case "revoke": stage = "Revoking certificate…"
        case "delete_app_ids": stage = "Deleting App ID…"
        default: stage = "Signing in to Apple…"
        }

        let anisette = InstallController.shared.anisetteURL.isEmpty
            ? InstallController.defaultAnisette
            : InstallController.shared.anisetteURL
        let ctx = Unmanaged.passRetained(self).toOpaque()
        let ctxBits = UInt(bitPattern: ctx)
        let sessionBits = UInt(bitPattern: session)

        Task {
            let result: Result<Data, AccountError> = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let session = OpaquePointer(bitPattern: sessionBits) else {
                        continuation.resume(returning: .failure(.message("Invalid session.")))
                        return
                    }
                    var out: UnsafeMutablePointer<CChar>?
                    let rc = credentials.email.withCString { emailC in
                        credentials.password.withCString { passC in
                            anisette.withCString { aniC in
                                requestJSON.withCString { reqC in
                                    dionysos_account_session_run(
                                        session, emailC, passC, aniC, reqC,
                                        accountProgressCallback, accountPromptCallback,
                                        UnsafeMutableRawPointer(bitPattern: ctxBits), &out)
                                }
                            }
                        }
                    }
                    let text = out.map { String(cString: $0) } ?? ""
                    if let out { dionysos_string_free(out) }
                    continuation.resume(returning: rc == 0
                        ? .success(Data(text.utf8))
                        : .failure(.message(text.isEmpty ? "Request failed (code \(rc))." : text)))
                }
            }

            dionysos_install_session_free(session)
            self.session = nil
            Unmanaged<AccountController>.fromOpaque(ctx).release()
            twoFactor = nil
            busyEmail = nil

            switch result {
            case .success(let data):
                do {
                    let overview = try JSONDecoder().decode(AccountOverview.self, from: data)
                    overviews[email] = overview
                    lastUpdated[email] = .now
                    AccountStore.shared.updateTeam(email, teamID: overview.team.id, teamName: overview.team.name)
                } catch {
                    errors[email] = "Couldn't read the account data: \(error.localizedDescription)"
                }
            case .failure(.message(let message)):
                guard message != "Cancelled." else { return }
                errors[email] = message
                if message.localizedCaseInsensitiveContains("sign-in failed") { typed[email] = nil }
            }
        }
        return true
    }

    private enum AccountError: Error { case message(String) }

    fileprivate func updateProgress(_ text: String) {
        guard isBusy else { return }
        stage = text
    }

    fileprivate func presentTwoFactor(_ json: Data) {
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
    }
}

private let accountProgressCallback: DionysosProgressCb = { ctx, stage, _ in
    guard let ctx, let stage else { return }
    let controller = Unmanaged<AccountController>.fromOpaque(ctx).takeUnretainedValue()
    let text = String(cString: stage)
    DispatchQueue.main.async { controller.updateProgress(text) }
}

private let accountPromptCallback: DionysosPromptCb = { ctx, kind, json in
    guard let ctx, let json else { return }
    let controller = Unmanaged<AccountController>.fromOpaque(ctx).takeUnretainedValue()
    let data = Data(String(cString: json).utf8)
    DispatchQueue.main.async {
        if kind == 1 {
            controller.presentTwoFactor(data)
        } else {
            controller.respond("abort")
        }
    }
}
