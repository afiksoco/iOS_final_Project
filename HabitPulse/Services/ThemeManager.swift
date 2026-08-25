//
//  ThemeManager.swift
//  HabitPulse
//

import UIKit

/// The three appearance options offered on the Profile screen.
enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Remembers the player's appearance choice and pushes it onto every window.
///
/// Dark mode works without this class — all the colours in the app are dynamic
/// system colours, so they adapt on their own. This adds the ability to
/// *override* the system setting from inside the app, which is handy for
/// showing both looks during the demo without leaving for Settings.
final class ThemeManager {

    static let shared = ThemeManager()

    private let key = "app_theme"

    private init() {}

    var theme: AppTheme {
        get {
            let raw = UserDefaults.standard.string(forKey: key) ?? AppTheme.system.rawValue
            return AppTheme(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            applyToAllScenes()
        }
    }

    /// Applies the saved choice to every window of every connected scene, with
    /// a short cross-fade so the switch doesn't snap.
    func applyToAllScenes() {
        let style = theme.interfaceStyle
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows where window.overrideUserInterfaceStyle != style {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
