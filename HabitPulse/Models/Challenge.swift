//
//  Challenge.swift
//  HabitPulse
//

import Foundation

/// A shared goal several players compete in, stored at `challenges/{id}`.
///
/// A challenge deliberately does *not* store anybody's score — scores live in
/// the Realtime Database because they change constantly and everyone needs to
/// see them the moment they change. Firestore holds only the parts that are
/// stable and worth querying: the title, the goal, the dates and who joined.
///
/// Membership is kept on the challenge document itself (`memberUids`) rather
/// than in a sub-collection, because it lets the Challenges screen answer
/// "which challenges am I in?" with one `arrayContains` listener instead of a
/// collection-group query plus a second fetch per result. For a roster of a
/// handful of friends that trade is clearly worth it.
struct Challenge {

    let id: String
    var title: String
    var emoji: String
    var ownerUid: String
    /// Total habit completions in a day needed for that day to "count".
    var goalPerDay: Int
    var startDate: Date
    var endDate: Date
    /// Short code other players type in to join.
    var joinCode: String
    var memberUids: [String]
    /// uid → display name, so the roster reads properly before anyone has
    /// posted a live standing.
    var memberNames: [String: String]
    var createdAt: Date

    init(id: String,
         title: String,
         emoji: String,
         ownerUid: String,
         goalPerDay: Int,
         startDate: Date,
         endDate: Date,
         joinCode: String,
         memberUids: [String],
         memberNames: [String: String],
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.ownerUid = ownerUid
        self.goalPerDay = max(1, goalPerDay)
        self.startDate = startDate
        self.endDate = endDate
        self.joinCode = joinCode
        self.memberUids = memberUids
        self.memberNames = memberNames
        self.createdAt = createdAt
    }

    // MARK: Derived state

    var memberCount: Int { memberUids.count }

    func contains(uid: String?) -> Bool {
        guard let uid else { return false }
        return memberUids.contains(uid)
    }

    /// True while today falls inside the challenge window.
    var isActive: Bool {
        let now = Date()
        return now >= Calendar.current.startOfDay(for: startDate) && now <= endDate
    }

    /// Whole days left, floored at zero once the challenge is over.
    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let last = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: today, to: last).day ?? 0
        return max(0, days)
    }

    /// A short line describing where the challenge is in its life.
    var statusText: String {
        let now = Date()
        if now < Calendar.current.startOfDay(for: startDate) { return "Starts soon" }
        if now > endDate { return "Finished" }
        let days = daysRemaining
        return days == 0 ? "Last day" : "\(days) day\(days == 1 ? "" : "s") left"
    }

    /// Every day key covered by the challenge window up to today, oldest
    /// first. Standings are computed by counting how many of these days the
    /// player hit the goal on.
    var dayKeys: [String] {
        let calendar = Calendar.current
        var keys: [String] = []
        var cursor = calendar.startOfDay(for: startDate)
        let last = calendar.startOfDay(for: min(endDate, Date()))
        // A corrupt document with end before start simply yields no days.
        while cursor <= last {
            keys.append(CalendarDay.key(for: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return keys
    }

    // MARK: Firestore mapping

    init?(id: String, data: [String: Any]) {
        guard let title = data["title"] as? String, !title.isEmpty,
              let ownerUid = data["ownerUid"] as? String,
              let joinCode = data["joinCode"] as? String else { return nil }
        self.id = id
        self.title = title
        self.emoji = data["emoji"] as? String ?? "🏁"
        self.ownerUid = ownerUid
        self.goalPerDay = max(1, data["goalPerDay"] as? Int ?? 1)
        self.startDate = (data["startDate"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        self.endDate = (data["endDate"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        self.joinCode = joinCode
        self.memberUids = data["memberUids"] as? [String] ?? []
        self.memberNames = data["memberNames"] as? [String: String] ?? [:]
        self.createdAt = (data["createdAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
    }

    var firestoreData: [String: Any] {
        [
            "title": title,
            "emoji": emoji,
            "ownerUid": ownerUid,
            "goalPerDay": goalPerDay,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate.timeIntervalSince1970,
            "joinCode": joinCode,
            "memberUids": memberUids,
            "memberNames": memberNames,
            "createdAt": createdAt.timeIntervalSince1970
        ]
    }

    /// Six unambiguous characters — no O/0 or I/1 — so a code is easy to read
    /// out loud and type in.
    static func makeJoinCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }

    /// Emoji offered when creating a challenge.
    static let emojiChoices = ["🏁", "🔥", "💪", "🏃", "📚", "🧘", "💧", "🌙", "🥗", "⛰"]
}
