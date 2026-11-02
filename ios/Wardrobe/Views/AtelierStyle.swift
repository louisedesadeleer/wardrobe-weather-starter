import SwiftUI
import UIKit

/// Cobalt, white space and unframed outfit photography.
enum Atelier {
    static let paper = Color.white
    static let wall = Color(red: 0.965, green: 0.958, blue: 0.943)
    static let ink = Color(red: 18.0 / 255, green: 38.0 / 255, blue: 170.0 / 255)
    static let uiInk = UIColor(red: 18.0 / 255, green: 38.0 / 255, blue: 170.0 / 255, alpha: 1)
    static func title(_ size: CGFloat = 32) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .serif) }
    @MainActor static func configureNavigation() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .white
        navigation.shadowColor = uiInk.withAlphaComponent(0.22)
        navigation.titleTextAttributes = [.foregroundColor: uiInk]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = .white
        tabs.shadowColor = uiInk.withAlphaComponent(0.22)
        for item in [tabs.stackedLayoutAppearance, tabs.inlineLayoutAppearance, tabs.compactInlineLayoutAppearance] {
            item.normal.iconColor = uiInk.withAlphaComponent(0.55)
            item.normal.titleTextAttributes = [.foregroundColor: uiInk.withAlphaComponent(0.65)]
            item.selected.iconColor = uiInk
            item.selected.titleTextAttributes = [.foregroundColor: uiInk]
        }
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }
}
struct AtelierButtonStyle: ButtonStyle {
    var filled = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Atelier.body(13))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 44)
            .foregroundStyle(filled ? Atelier.paper : Atelier.ink)
            .background(filled ? Atelier.ink : Atelier.paper)
            .overlay { Rectangle().strokeBorder(Atelier.ink.opacity(0.65), lineWidth: 0.7) }
            .opacity(!enabled ? 0.35 : configuration.isPressed ? 0.6 : 1)
    }
}
