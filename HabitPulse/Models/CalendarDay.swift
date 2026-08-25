//
//  CalendarDay.swift
//  HabitPulse
//

import Foundation

/// Every habit log is keyed by the day it belongs to, written as `yyyy-MM-dd`.
///
/// Using a string key (rather than a timestamp) is deliberate: it makes a day
/// a *document id* in Firestore, which means logging the same habit twice in
/// one day overwrites one document instead of creating duplicates, and it
/// keeps the keys sortable and human-readable in the Firebase console.
enum CalendarDay {

    /// Fixed locale so the key format never changes with the device region.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// A friendly label ("Mon 12 May") used on the history screen.
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    /// The key for a given date, in the device's current time zone.
    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    /// The key for "right now".
    static var todayKey: String {
        key(for: Date())
    }

    /// Turns a key back into a date (midnight, local time). Returns `nil` for
    /// anything that isn't a valid key.
    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }

    /// A short human label for a key, falling back to the key itself.
    static func displayLabel(for key: String) -> String {
        guard let date = date(from: key) else { return key }
        return displayFormatter.string(from: date)
    }

    /// The keys for the last `count` days, oldest first and ending today.
    /// Used by the history heat-map and by the streak calculator.
    static func recentKeys(count: Int, endingAt date: Date = Date()) -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        // `count - 1` because the range includes today itself.
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(key(for:))
        }
    }
}
