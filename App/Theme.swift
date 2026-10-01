import SwiftUI

/// Dionysos's palette: deep navy background, one bright blue accent for buttons
/// and highlights, navy glass cards with a faint blue hairline, near-white text.
/// The enum keeps the name `Aurora` (and the old colour names) so every screen
/// shares one set of tokens.
enum Aurora {
    // Base, from darkest to lightest.
    static let night = Color(red: 0.020, green: 0.043, blue: 0.102)      // #050B1A
    static let card = Color(red: 0.055, green: 0.102, blue: 0.200)       // #0E1A33
    static let deepBlue = Color(red: 0.071, green: 0.137, blue: 0.290)   // #12234A
    static let indigo = Color(red: 0.118, green: 0.227, blue: 0.541)     // #1E3A8A
    static let dusk = Color(red: 0.086, green: 0.173, blue: 0.361)       // #162C5C

    // Highlights. `violet` is the accent everywhere (buttons, tints, rings).
    static let violet = Color(red: 0.184, green: 0.482, blue: 0.965)     // #2F7BF6
    static let orchid = Color(red: 0.357, green: 0.608, blue: 1.000)     // #5B9BFF
    static let lilac = Color(red: 0.749, green: 0.839, blue: 1.000)      // #BFD6FF
    static let frost = Color.white

    static let success = Color(red: 0.431, green: 0.906, blue: 0.718)    // #6EE7B7
    static let danger = Color(red: 0.984, green: 0.443, blue: 0.522)     // #FB7185
    static let warning = Color(red: 0.992, green: 0.792, blue: 0.369)    // #FDCA5E

    /// Secondary text (white at 60%).
    static let secondaryText = Color.white.opacity(0.6)
    /// Hairline around cards (accent at 25%).
    static let hairline = violet.opacity(0.25)

    /// Row fill for Lists and Forms.
    static let rowFill = card

    static let accentGradient = LinearGradient(
        colors: [orchid, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    /// App-icon background: bright blue at the top fading into navy.
    static let markGradient = LinearGradient(
        colors: [Color(red: 0.231, green: 0.522, blue: 1.000), Color(red: 0.035, green: 0.075, blue: 0.188)],
        startPoint: .top,
        endPoint: .bottom)
}

extension View {
    /// Dionysos look for every screen: forced dark, blue tint.
    func auroraTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(Aurora.violet)
    }

    /// Navy cell background for Lists and Forms.
    func auroraRow() -> some View {
        listRowBackground(Aurora.rowFill)
    }

    /// Hides the default grouped background so the navy + glow shows through.
    func auroraListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AuroraBackground())
    }
}
