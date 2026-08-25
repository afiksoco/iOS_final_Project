//
//  HabitPalette.swift
//  HabitPulse
//

import UIKit

/// The colours a habit can be tagged with.
///
/// Each one is a `UIColor(dynamicProvider:)`, so it resolves to a different
/// shade depending on the current interface style. The light variants are
/// deep enough to read against a white background; the dark variants are
/// lifted and desaturated so they glow rather than glare on black — a colour
/// that looks right in light mode is usually too heavy in dark mode.
enum HabitPalette {

    static let defaultKey = "mint"

    private struct Shade {
        let light: UIColor
        let dark: UIColor
    }

    private static let shades: [(key: String, name: String, shade: Shade)] = [
        ("mint",   "Mint",   Shade(light: UIColor(red: 0.10, green: 0.55, blue: 0.44, alpha: 1),
                                   dark:  UIColor(red: 0.30, green: 0.82, blue: 0.66, alpha: 1))),
        ("ocean",  "Ocean",  Shade(light: UIColor(red: 0.09, green: 0.42, blue: 0.72, alpha: 1),
                                   dark:  UIColor(red: 0.36, green: 0.68, blue: 0.98, alpha: 1))),
        ("grape",  "Grape",  Shade(light: UIColor(red: 0.44, green: 0.26, blue: 0.72, alpha: 1),
                                   dark:  UIColor(red: 0.70, green: 0.55, blue: 0.98, alpha: 1))),
        ("sunset", "Sunset", Shade(light: UIColor(red: 0.85, green: 0.35, blue: 0.16, alpha: 1),
                                   dark:  UIColor(red: 1.00, green: 0.58, blue: 0.35, alpha: 1))),
        ("berry",  "Berry",  Shade(light: UIColor(red: 0.77, green: 0.18, blue: 0.38, alpha: 1),
                                   dark:  UIColor(red: 1.00, green: 0.45, blue: 0.62, alpha: 1))),
        ("moss",   "Moss",   Shade(light: UIColor(red: 0.36, green: 0.48, blue: 0.14, alpha: 1),
                                   dark:  UIColor(red: 0.65, green: 0.80, blue: 0.36, alpha: 1)))
    ]

    /// Every key, in the order shown in the habit editor.
    static var allKeys: [String] { shades.map(\.key) }

    /// Display name for the editor's colour picker.
    static func name(for key: String) -> String {
        shades.first { $0.key == key }?.name ?? "Mint"
    }

    /// The colour for a key, resolving per interface style. Unknown keys fall
    /// back to the default rather than returning something invisible.
    static func color(for key: String) -> UIColor {
        let shade = (shades.first { $0.key == key } ?? shades[0]).shade
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? shade.dark : shade.light
        }
    }
}
