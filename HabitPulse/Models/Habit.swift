//
//  Habit.swift
//  HabitPulse
//

import Foundation

/// One habit the player is tracking, e.g. "Drink water — 8× a day".
///
/// Stored in Firestore at `users/{uid}/habits/{id}`. The mapping to and from
/// a Firestore dictionary is written by hand rather than via `Codable`, so the
/// exact shape of the stored document is visible in one place.
struct Habit {

    let id: String
    var title: String
    var emoji: String
    /// Key into `HabitPalette` — the colour is resolved at draw time so it can
    /// differ between light and dark mode.
    var colorKey: String
    /// How many times a day counts as "done". Always at least 1.
    var targetPerDay: Int
    var createdAt: Date
    /// Archived habits stay in Firestore (so history survives) but drop off
    /// the Today screen.
    var archived: Bool

    init(id: String,
         title: String,
         emoji: String,
         colorKey: String,
         targetPerDay: Int,
         createdAt: Date = Date(),
         archived: Bool = false) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.colorKey = colorKey
        self.targetPerDay = max(1, targetPerDay)
        self.createdAt = createdAt
        self.archived = archived
    }

    // MARK: Firestore mapping

    /// Builds a habit from a Firestore document. Returns `nil` if the document
    /// is missing the fields we cannot sensibly default.
    init?(id: String, data: [String: Any]) {
        guard let title = data["title"] as? String, !title.isEmpty else { return nil }
        self.id = id
        self.title = title
        self.emoji = data["emoji"] as? String ?? "✅"
        self.colorKey = data["colorKey"] as? String ?? HabitPalette.defaultKey
        self.targetPerDay = max(1, data["targetPerDay"] as? Int ?? 1)
        self.createdAt = (data["createdAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        self.archived = data["archived"] as? Bool ?? false
    }

    /// The dictionary written back to Firestore.
    var firestoreData: [String: Any] {
        [
            "title": title,
            "emoji": emoji,
            "colorKey": colorKey,
            "targetPerDay": targetPerDay,
            "createdAt": createdAt.timeIntervalSince1970,
            "archived": archived
        ]
    }
}
