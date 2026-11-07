import SwiftUI
import UIKit

/// Clarity Vaults design tokens.
/// Every colour, radius and spacing used in the app comes from here, so the
/// look can be matched to the final brand guide by editing this one file.
enum Theme {
    // MARK: Colours (light / dark)
    static let ink        = dynamic(light: 0x0F1C33, dark: 0xEEF2F8)   // headings, primary text
    static let muted      = dynamic(light: 0x5B6B82, dark: 0x9AA8BD)   // secondary text
    static let background = dynamic(light: 0xF4F6F9, dark: 0x0A1222)
    static let surface    = dynamic(light: 0xFFFFFF, dark: 0x14203A)
    static let hairline   = dynamic(light: 0xE3E8EF, dark: 0x22304D)
    static let navy       = Color(hex: 0x0F1C33)                        // vault / hero cards
    static let navySoft   = Color(hex: 0x1C2E4F)
    static let accent     = dynamic(light: 0x1F8A84, dark: 0x3DBFB6)   // teal: primary actions
    static let gold       = dynamic(light: 0xB8872E, dark: 0xD9AE5B)   // highlights, milestones
    static let positive   = dynamic(light: 0x2E7D4F, dark: 0x5CC88A)   // money in
    static let caution    = dynamic(light: 0xC07A1C, dark: 0xF0B25A)   // due soon
    static let negative   = dynamic(light: 0xB54A3C, dark: 0xF07F6E)   // money out / overdue (used sparingly)

    /// Categorical palette for charts (spending categories, individual debts).
    static let chartPalette: [Color] = [
        Color(hex: 0x1F8A84), Color(hex: 0xD9AE5B), Color(hex: 0x4C6FBF), Color(hex: 0xC2637A),
        Color(hex: 0x6AA84F), Color(hex: 0x8E6CC4), Color(hex: 0xE08A3C), Color(hex: 0x3E9CC9),
        Color(hex: 0x9C8A6E), Color(hex: 0x5B6B82)
    ]

    // MARK: Shape & spacing
    static let corner: CGFloat = 18
    static let smallCorner: CGFloat = 12
    static let padding: CGFloat = 16

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

// MARK: - Reusable styling

struct CardModifier: ViewModifier {
    var background: Color = Theme.surface
    func body(content: Content) -> some View {
        content
            .padding(Theme.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .stroke(Theme.hairline, lineWidth: background == Theme.surface ? 1 : 0))
    }
}

/// The dark navy "vault" card used for headline numbers.
struct VaultCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Theme.navy, Theme.navySoft], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
            )
            .foregroundStyle(.white)
    }
}

extension View {
    func card(_ background: Color = Theme.surface) -> some View { modifier(CardModifier(background: background)) }
    func vaultCard() -> some View { modifier(VaultCardModifier()) }
    func screenBackground() -> some View { background(Theme.background.ignoresSafeArea()) }
}

struct CardHeader<Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(Theme.accent)
            }
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            Spacer()
            trailing()
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}
