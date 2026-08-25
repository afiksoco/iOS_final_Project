//
//  StreakCalculator.swift
//  HabitPulse
//

import Foundation

/// Pure scoring logic, with no Firebase and no UIKit anywhere in sight.
///
/// Everything the app shows as a number — a streak, a completion rate, a
/// challenge score — comes from here, which keeps the rules in one readable
/// place and makes them straightforward to reason about (and to unit-test).
///
/// The input is always the same shape: a dictionary of `yyyy-MM-dd` keys to
/// the number of completions on that day, plus the daily target. That single
/// shape covers both cases — one habit's own logs, and a challenge's totals
/// across every habit — so the same four functions serve both screens.
enum StreakCalculator {

    /// A day counts once the target has been reached.
    static func isComplete(count: Int, target: Int) -> Bool {
        count >= max(1, target)
    }

    /// Consecutive completed days ending today.
    ///
    /// Today is treated leniently: if the goal hasn't been met *yet* today the
    /// streak is measured up to yesterday rather than reset to zero, so a
    /// streak only actually breaks once a whole day has been missed.
    static func currentStreak(logs: [String: Int], target: Int, today: Date = Date()) -> Int {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: today)

        // If today isn't done yet, start counting from yesterday instead.
        if !isComplete(count: logs[CalendarDay.key(for: cursor)] ?? 0, target: target) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while isComplete(count: logs[CalendarDay.key(for: cursor)] ?? 0, target: target) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// The longest run of consecutive completed days ever recorded.
    static func bestStreak(logs: [String: Int], target: Int) -> Int {
        let calendar = Calendar.current
        let completedDates = logs
            .filter { isComplete(count: $0.value, target: target) }
            .compactMap { CalendarDay.date(from: $0.key) }
            .sorted()

        guard !completedDates.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<completedDates.count {
            let previous = completedDates[index - 1]
            let current = completedDates[index]
            let gap = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if gap == 1 {
                run += 1
                best = max(best, run)
            } else if gap > 1 {
                run = 1
            }
            // A gap of 0 would mean a duplicate key, which can't happen since
            // the day is the document id — so it is simply ignored.
        }
        return best
    }

    /// Share of the last `days` days that were completed, as 0…1.
    static func completionRate(logs: [String: Int],
                               target: Int,
                               overLast days: Int,
                               endingAt date: Date = Date()) -> Double {
        guard days > 0 else { return 0 }
        let keys = CalendarDay.recentKeys(count: days, endingAt: date)
        let completed = keys.filter { isComplete(count: logs[$0] ?? 0, target: target) }.count
        return Double(completed) / Double(keys.count)
    }

    /// How many of the given days hit the target — this is a player's score in
    /// a challenge, where `dayKeys` is the challenge window so far.
    static func qualifyingDays(logs: [String: Int], target: Int, within dayKeys: [String]) -> Int {
        dayKeys.filter { isComplete(count: logs[$0] ?? 0, target: target) }.count
    }

    /// Progress towards today's target as 0…1, for the ring on the Today screen.
    static func progress(count: Int, target: Int) -> Double {
        let target = max(1, target)
        return min(1, Double(count) / Double(target))
    }
}
