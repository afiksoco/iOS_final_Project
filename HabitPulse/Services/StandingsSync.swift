//
//  StandingsSync.swift
//  HabitPulse
//

import Foundation

/// The bridge between the two databases.
///
/// Firestore knows what the player actually did; the Realtime Database holds
/// the scoreboard everyone is watching. This class is the one place that turns
/// the first into the second: it reads the player's own daily totals out of
/// Firestore, scores them against each challenge's goal, and writes a single
/// row per challenge into the Realtime Database.
///
/// Doing it on the client keeps the security model simple — a player only ever
/// reads their own habit data and only ever writes their own standing row —
/// and it means no Cloud Functions are needed, which the free Firebase tier
/// does not include.
final class StandingsSync {

    static let shared = StandingsSync()

    private init() {}

    /// Recomputes and republishes the player's row in every challenge they are
    /// in. Called after each logged completion, so a tick on one phone shows up
    /// on everyone else's leaderboard right away.
    func syncAll() {
        ChallengeStore.shared.fetchMyChallenges { [weak self] challenges in
            for challenge in challenges {
                self?.sync(challenge: challenge)
            }
        }
    }

    /// Scores one challenge and publishes the result.
    func sync(challenge: Challenge) {
        let dayKeys = challenge.dayKeys
        guard let first = dayKeys.first, let last = dayKeys.last else {
            // The challenge has not started yet — publish an empty row so the
            // player still appears on the board.
            LiveStandingsService.shared.publish(challengeId: challenge.id,
                                                points: 0,
                                                todayCount: 0,
                                                streak: 0)
            return
        }

        HabitStore.shared.fetchDailyTotals(from: first, to: last) { totals in
            let points = StreakCalculator.qualifyingDays(logs: totals,
                                                         target: challenge.goalPerDay,
                                                         within: dayKeys)
            let streak = StreakCalculator.currentStreak(logs: totals,
                                                        target: challenge.goalPerDay)
            let todayCount = totals[CalendarDay.todayKey] ?? 0

            LiveStandingsService.shared.publish(challengeId: challenge.id,
                                                points: points,
                                                todayCount: todayCount,
                                                streak: streak)
        }
    }
}
