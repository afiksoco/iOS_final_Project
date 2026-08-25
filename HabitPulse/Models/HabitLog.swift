//
//  HabitLog.swift
//  HabitPulse
//

import Foundation

/// How many times a habit was completed on one particular day.
///
/// Stored at `users/{uid}/habits/{habitId}/logs/{yyyy-MM-dd}` — the day key is
/// the document id, so there is exactly one log document per habit per day.
struct HabitLog {

    /// `yyyy-MM-dd`, see `CalendarDay`.
    let day: String
    /// Number of completions recorded that day (never negative).
    var count: Int
    var updatedAt: Date

    init(day: String, count: Int, updatedAt: Date = Date()) {
        self.day = day
        self.count = max(0, count)
        self.updatedAt = updatedAt
    }

    // MARK: Firestore mapping

    init?(day: String, data: [String: Any]) {
        guard let count = data["count"] as? Int else { return nil }
        self.day = day
        self.count = max(0, count)
        self.updatedAt = (data["updatedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
    }

    var firestoreData: [String: Any] {
        [
            "day": day,
            "count": count,
            "updatedAt": updatedAt.timeIntervalSince1970
        ]
    }
}
