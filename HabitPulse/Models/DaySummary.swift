//
//  DaySummary.swift
//  HabitPulse
//

import Foundation

/// Everything logged on one day, rolled up into a single document at
/// `users/{uid}/days/{yyyy-MM-dd}`.
///
/// This is a deliberate denormalisation. The per-habit history still lives
/// under each habit (`habits/{id}/logs/{day}`), but the Today screen needs
/// *every* habit's count for today at once, and a challenge needs the daily
/// totals across a whole date range. Reading those from the per-habit logs
/// would mean one listener per habit and a collection-group query per
/// challenge; keeping this rollup means one listener and one range read.
///
/// Both copies are written in the same `WriteBatch`, so they cannot drift.
struct DaySummary {

    let day: String
    /// Completions across every habit that day.
    var total: Int
    /// habitId → completions that day.
    var counts: [String: Int]

    init(day: String, total: Int = 0, counts: [String: Int] = [:]) {
        self.day = day
        self.total = max(0, total)
        self.counts = counts
    }

    /// Completions logged for one habit, never negative.
    func count(for habitId: String) -> Int {
        max(0, counts[habitId] ?? 0)
    }

    // MARK: Firestore mapping

    init(day: String, data: [String: Any]) {
        self.day = day
        self.total = max(0, data["total"] as? Int ?? 0)
        self.counts = data["counts"] as? [String: Int] ?? [:]
    }
}
