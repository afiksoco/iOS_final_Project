//
//  StandingEntry.swift
//  HabitPulse
//

import Foundation
import FirebaseDatabase

/// One row of a live challenge leaderboard.
///
/// Unlike the other models this one lives in the **Realtime Database**, at
/// `standings/{challengeId}/{uid}`. Each player writes their own row whenever
/// their score changes, and every other player is watching the parent node, so
/// the table on screen re-sorts within a few hundred milliseconds.
struct StandingEntry {

    let uid: String
    var displayName: String
    var avatarEmoji: String
    /// Days inside the challenge window where the player hit the goal.
    var points: Int
    /// Completions logged today — shown as "3 / 5 today".
    var todayCount: Int
    /// Consecutive qualifying days ending today.
    var streak: Int
    var updatedAt: Date

    /// Filled in from the separate `presence/{uid}` node, not stored on the
    /// standing itself — presence is per player, not per challenge.
    var isOnline: Bool = false

    init(uid: String,
         displayName: String,
         avatarEmoji: String,
         points: Int,
         todayCount: Int,
         streak: Int,
         updatedAt: Date = Date()) {
        self.uid = uid
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.points = points
        self.todayCount = todayCount
        self.streak = streak
        self.updatedAt = updatedAt
    }

    // MARK: Realtime Database mapping

    init?(uid: String, value: Any?) {
        guard let data = value as? [String: Any],
              let displayName = data["displayName"] as? String else { return nil }
        self.uid = uid
        self.displayName = displayName
        self.avatarEmoji = data["avatarEmoji"] as? String ?? "🙂"
        self.points = data["points"] as? Int ?? 0
        self.todayCount = data["todayCount"] as? Int ?? 0
        self.streak = data["streak"] as? Int ?? 0
        // RTDB server timestamps arrive as milliseconds.
        let millis = data["updatedAt"] as? TimeInterval ?? 0
        self.updatedAt = Date(timeIntervalSince1970: millis / 1000)
    }

    /// The payload written to the Realtime Database. `updatedAt` is filled in
    /// by the server so clocks that are slightly off don't reorder the table.
    var databaseValue: [String: Any] {
        [
            "displayName": displayName,
            "avatarEmoji": avatarEmoji,
            "points": points,
            "todayCount": todayCount,
            "streak": streak,
            "updatedAt": ServerValue.timestamp()
        ]
    }

    /// Highest score first; ties broken by the longer streak, then by name so
    /// the order is stable instead of flickering between redraws.
    static func rank(_ lhs: StandingEntry, _ rhs: StandingEntry) -> Bool {
        if lhs.points != rhs.points { return lhs.points > rhs.points }
        if lhs.streak != rhs.streak { return lhs.streak > rhs.streak }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}
