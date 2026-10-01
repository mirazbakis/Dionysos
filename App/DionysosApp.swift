import SwiftUI

@main
struct DionysosApp: App {
    init() {
        PairingController.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .auroraTheme()
        }
    }
}

enum AppTab: Hashable {
    case sign, library, accounts, settings
}

enum SignRoute: Hashable {
    case pair
}

/// Lets other screens open Pair (e.g. "Go to Pair" from the install flow).
@MainActor
final class SignRouter: ObservableObject {
    static let shared = SignRouter()
    @Published var path: [SignRoute] = []
    private init() {}
}

struct RootView: View {
    @State private var tab: AppTab = .sign
    @StateObject private var install = InstallController.shared

    var body: some View {
        TabView(selection: $tab) {
            Tab("Sign", systemImage: "signature", value: AppTab.sign) {
                SignView(selectedTab: $tab)
            }
            Tab("Library", systemImage: "square.stack.3d.up.fill", value: AppTab.library) {
                NavigationStack { LibraryView() }
            }
            .badge(expiringSoon)
            Tab("Accounts", systemImage: "person.2.fill", value: AppTab.accounts) {
                AccountsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Installs and refreshes run full screen over whichever tab started them.
        .fullScreenCover(item: $install.flow) { target in
            InstallFlowView(target: target) { RootView.openPair(tab: $tab) }
                .auroraTheme()
        }
        .onOpenURL { url in
            // LocalDevVPN returns here via dionysos:// after switching the VPN on.
            guard url.scheme == "dionysos" else { return }
            install.resumeWhenVPNReady()
        }
    }

    /// Apps that expire within a day (or already have), shown on the Library tab.
    private var expiringSoon: Int {
        install.apps.filter { $0.isExpired || ($0.daysLeft ?? 99) < 1 }.count
    }

    /// Switches to Sign and opens Pair.
    static func openPair(tab: Binding<AppTab>) {
        tab.wrappedValue = .sign
        SignRouter.shared.path = [.pair]
    }
}
