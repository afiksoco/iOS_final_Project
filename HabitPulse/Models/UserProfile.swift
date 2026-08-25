//
//  UserProfile.swift
//  HabitPulse
//

import Foundation

/// The public identity of a player, stored at `users/{uid}`.
///
/// Sign-in is anonymous, so the Firebase UID is the only real identifier; the
/// display name is purely cosmetic and is what other players see on a shared
/// challenge leaderboard.
struct UserProfile {

    let uid: String
    var displayName: String
    var avatarEmoji: String
    var createdAt: Date

    init(uid: String, displayName: String, avatarEmoji: String = "🙂", createdAt: Date = Date()) {
        self.uid = uid
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.createdAt = createdAt
    }

    // MARK: Firestore mapping

    init?(uid: String, data: [String: Any]) {
        guard let displayName = data["displayName"] as? String, !displayName.isEmpty else { return nil }
        self.uid = uid
        self.displayName = displayName
        self.avatarEmoji = data["avatarEmoji"] as? String ?? "🙂"
        self.createdAt = (data["createdAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
    }

    var firestoreData: [String: Any] {
        [
            "displayName": displayName,
            "avatarEmoji": avatarEmoji,
            "createdAt": createdAt.timeIntervalSince1970
        ]
    }

    /// Pool of avatars offered on the profile screen.
    static let avatarChoices = ["🙂", "🔥", "🐢", "🦊", "🐼", "🚀", "🌱", "⚡️", "🏔", "🐝"]
}
