//
//  LiveStandingsService.swift
//  HabitPulse
//

import Foundation
import FirebaseDatabase

/// A handle for one screen's standings/cheers observers.
final class StandingsObservation {
    fileprivate var entries: [(query: DatabaseQuery, handle: DatabaseHandle)] = []

    func cancel() {
        for entry in entries {
            entry.query.removeObserver(withHandle: entry.handle)
        }
        entries.removeAll()
    }

    deinit { cancel() }
}

/// The live leaderboard, in the **Realtime Database** under
/// `standings/{challengeId}/{uid}`.
///
/// Firestore is the source of truth for what a player actually did; this is a
/// small projection of it that everyone in a challenge watches at once. Each
/// player computes their own score from their own Firestore logs and writes
/// only their own row here — so a tick on one phone re-sorts the table on
/// everyone else's within a few hundred milliseconds, without any of them
/// needing read access to each other's habit data.
final class LiveStandingsService {

    static let shared = LiveStandingsService()

    private init() {}

    private var root: DatabaseReference? {
        FirebaseService.database
    }

    // MARK: Publishing my row

    /// Writes the player's own standing for a challenge.
    func publish(challengeId: String,
                 points: Int,
                 todayCount: Int,
                 streak: Int) {
        guard let root, let uid = AuthService.shared.uid else { return }

        let entry = StandingEntry(uid: uid,
                                  displayName: AuthService.shared.displayName,
                                  avatarEmoji: AuthService.shared.avatarEmoji,
                                  points: points,
                                  todayCount: todayCount,
                                  streak: streak)

        root.child("standings").child(challengeId).child(uid).setValue(entry.databaseValue)
    }

    /// Clears the player's row, used when they leave a challenge.
    func removeStanding(challengeId: String) {
        guard let root, let uid = AuthService.shared.uid else { return }
        root.child("standings").child(challengeId).child(uid).removeValue()
    }

    // MARK: Watching the board

    /// Watches every row of a challenge's leaderboard, already sorted.
    func observeStandings(challengeId: String,
                          onChange: @escaping ([StandingEntry]) -> Void) -> StandingsObservation {
        let observation = StandingsObservation()
        guard let root else { return observation }

        let reference = root.child("standings").child(challengeId)
        let handle = reference.observe(.value) { snapshot in
            var entries: [StandingEntry] = []
            for child in snapshot.children {
                guard let child = child as? DataSnapshot,
                      let entry = StandingEntry(uid: child.key, value: child.value) else { continue }
                entries.append(entry)
            }
            onChange(entries.sorted(by: StandingEntry.rank))
        } withCancel: { error in
            print("[HabitPulse] standings listener cancelled: \(error)")
            onChange([])
        }

        observation.entries.append((reference, handle))
        return observation
    }

    // MARK: Cheers

    /// Sends a one-off reaction to everyone currently watching the challenge.
    ///
    /// Cheers are pure "happening now" events — nobody needs them next week —
    /// which is exactly the kind of thing that belongs in the Realtime
    /// Database rather than in a Firestore collection that grows forever.
    func sendCheer(challengeId: String, emoji: String) {
        guard let root else { return }
        root.child("cheers").child(challengeId).childByAutoId().setValue([
            "fromName": AuthService.shared.displayName,
            "emoji": emoji,
            "at": ServerValue.timestamp()
        ])
    }

    /// Watches for cheers sent *after* this call, so opening the screen does
    /// not replay the whole backlog.
    func observeCheers(challengeId: String,
                       onCheer: @escaping (String, String) -> Void) -> StandingsObservation {
        let observation = StandingsObservation()
        guard let root else { return observation }

        let startedAt = Date().timeIntervalSince1970 * 1000
        let reference = root.child("cheers").child(challengeId)
        let query = reference.queryLimited(toLast: 20)
        let handle = query.observe(.childAdded) { snapshot in
            guard let data = snapshot.value as? [String: Any],
                  let name = data["fromName"] as? String,
                  let emoji = data["emoji"] as? String else { return }
            // `childAdded` replays existing children first — skip anything
            // that was already there when the screen opened.
            let at = data["at"] as? TimeInterval ?? 0
            guard at >= startedAt else { return }
            onCheer(name, emoji)
        }

        observation.entries.append((query, handle))
        return observation
    }

    /// Reactions offered in the cheer menu.
    static let cheerEmojis = ["👏", "🔥", "💪", "🎉", "🚀"]
}
