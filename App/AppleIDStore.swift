import Foundation
import Security

/// One of the user's own Apple IDs saved in Dionysos.
struct SavedAccount: Codable, Identifiable, Hashable {
    let email: String
    var teamID: String?
    var teamName: String?
    var addedAt: Date = .now
    var lastUsed: Date?

    var id: String { email }

    /// Name shown in pickers: the team name if known, else the email.
    var title: String { teamName?.isEmpty == false ? teamName! : email }
    var hasPassword: Bool { AppleIDStore.password(for: email) != nil }
}

/// The saved Apple IDs and which one signs by default. The list lives in
/// UserDefaults; passwords (only if the user opts in) live in the Keychain,
/// readable only while this device is unlocked and never synced.
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    private static let listKey = "appleID.accounts"
    private static let activeKey = "appleID.active"
    private static let legacyEmailKey = "appleID.email"

    @Published private(set) var accounts: [SavedAccount] = []
    @Published var activeEmail: String {
        didSet { UserDefaults.standard.set(activeEmail, forKey: Self.activeKey) }
    }

    var active: SavedAccount? { accounts.first { $0.email == activeEmail } ?? accounts.first }

    private init() {
        activeEmail = UserDefaults.standard.string(forKey: Self.activeKey) ?? ""
        if let data = UserDefaults.standard.data(forKey: Self.listKey),
           let saved = try? JSONDecoder().decode([SavedAccount].self, from: data) {
            accounts = saved
        } else if let legacy = UserDefaults.standard.string(forKey: Self.legacyEmailKey), !legacy.isEmpty {
            accounts = [SavedAccount(email: legacy)]
            activeEmail = legacy
            save()
        }
        if active == nil || activeEmail.isEmpty { activeEmail = accounts.first?.email ?? "" }
    }

    func account(_ email: String) -> SavedAccount? {
        accounts.first { $0.email.caseInsensitiveCompare(email) == .orderedSame }
    }

    /// Adds the account (or updates it) and optionally remembers its password.
    func upsert(_ email: String, password: String?, remember: Bool, makeActive: Bool = false) {
        let email = email.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { return }
        if account(email) == nil { accounts.append(SavedAccount(email: email)) }
        if let password, remember {
            AppleIDStore.savePassword(password, for: email)
        } else if !remember {
            AppleIDStore.deletePassword(for: email)
        }
        if makeActive || activeEmail.isEmpty { activeEmail = email }
        save()
    }

    /// Records the team this Apple ID belongs to and when it last signed something.
    func noteUsed(_ email: String, teamID: String? = nil, teamName: String? = nil) {
        guard let i = accounts.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) else { return }
        if let teamID, !teamID.isEmpty { accounts[i].teamID = teamID }
        if let teamName, !teamName.isEmpty { accounts[i].teamName = teamName }
        accounts[i].lastUsed = .now
        save()
    }

    /// Stores the team name and ID read from Apple, without touching `lastUsed`.
    func updateTeam(_ email: String, teamID: String, teamName: String) {
        guard let i = accounts.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) else { return }
        accounts[i].teamID = teamID
        accounts[i].teamName = teamName
        save()
    }

    func remove(_ account: SavedAccount) {
        AppleIDStore.deletePassword(for: account.email)
        accounts.removeAll { $0.email == account.email }
        if activeEmail == account.email { activeEmail = accounts.first?.email ?? "" }
        save()
    }

    func removeAll() {
        for account in accounts { AppleIDStore.deletePassword(for: account.email) }
        accounts = []
        activeEmail = ""
        save()
    }

    func credentials(for email: String) -> AppleIDCredentials? {
        guard let password = AppleIDStore.password(for: email) else { return nil }
        return AppleIDCredentials(email: email, password: password)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.listKey)
        }
        objectWillChange.send()
    }
}

/// Keychain access for Apple ID passwords, plus the default account's email.
enum AppleIDStore {
    private static let service = "Dionysos.AppleID"

    /// The account that signs by default.
    @MainActor static var email: String {
        get { AccountStore.shared.active?.email ?? "" }
        set { AccountStore.shared.activeEmail = newValue }
    }

    static func password(for email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func savePassword(_ password: String, for email: String) {
        deletePassword(for: email)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func deletePassword(for email: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct AppleIDCredentials {
    let email: String
    let password: String
}

/// Shown wherever an Apple ID is added. Dionysos is for your own accounts only.
enum AccountDisclaimer {
    static let acceptedKey = "disclaimer.ownAccounts.accepted"

    static let title = "Only use your own Apple IDs"
    static let body = "Sign in only with Apple IDs that belong to you, such as your main account or a spare one you created yourself. Never sign in with someone else's Apple ID, a shared or bought account, or an account you don't have permission to use. Apps are signed with that account's own free development certificate, and following Apple's terms for that account is your responsibility."
}
