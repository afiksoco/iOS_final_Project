//
//  ChallengeStore.swift
//  HabitPulse
//

import Foundation
import FirebaseFirestore

/// Creating, joining and leaving challenges — the Firestore half of the
/// competition feature.
///
/// Only the *definition* of a challenge lives here (title, goal, dates,
/// roster). The scores are in the Realtime Database, see `LiveStandingsService`.
final class ChallengeStore {

    static let shared = ChallengeStore()

    enum ChallengeError: LocalizedError {
        case notFound
        case alreadyJoined

        var errorDescription: String? {
            switch self {
            case .notFound:      return "No challenge with that code. Check the letters and try again."
            case .alreadyJoined: return "You have already joined this challenge."
            }
        }
    }

    private init() {}

    private var collection: CollectionReference? {
        guard FirebaseService.isConfigured else { return nil }
        return FirebaseService.firestore.collection("challenges")
    }

    // MARK: Reading

    /// Live list of the challenges the player belongs to, soonest deadline
    /// first. One `arrayContains` listener covers the whole screen.
    @discardableResult
    func observeMyChallenges(onChange: @escaping ([Challenge]) -> Void) -> ListenerRegistration? {
        guard let collection, let uid = AuthService.shared.uid else { return nil }
        return collection
            .whereField("memberUids", arrayContains: uid)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { print("[HabitPulse] challenges listener failed: \(error)") }
                    onChange([])
                    return
                }
                let challenges = documents
                    .compactMap { Challenge(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.endDate < $1.endDate }
                onChange(challenges)
            }
    }

    /// Live view of one challenge, so the detail screen notices people joining
    /// and leaving while it is open.
    @discardableResult
    func observeChallenge(id: String, onChange: @escaping (Challenge?) -> Void) -> ListenerRegistration? {
        guard let collection else { return nil }
        return collection.document(id).addSnapshotListener { snapshot, error in
            if let error { print("[HabitPulse] challenge listener failed: \(error)") }
            guard let data = snapshot?.data() else {
                onChange(nil)
                return
            }
            onChange(Challenge(id: id, data: data))
        }
    }

    /// One-shot version of the above, for the background standings sync.
    func fetchMyChallenges(completion: @escaping ([Challenge]) -> Void) {
        guard let collection, let uid = AuthService.shared.uid else {
            completion([])
            return
        }
        collection.whereField("memberUids", arrayContains: uid).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                if let error { print("[HabitPulse] challenges fetch failed: \(error)") }
                completion([])
                return
            }
            completion(documents.compactMap { Challenge(id: $0.documentID, data: $0.data()) })
        }
    }

    // MARK: Writing

    /// Creates a challenge running for `days` days from today, with the player
    /// as its first member.
    func createChallenge(title: String,
                         emoji: String,
                         goalPerDay: Int,
                         days: Int,
                         completion: @escaping (Result<Challenge, Error>) -> Void) {
        guard let collection, let uid = AuthService.shared.uid else {
            completion(.failure(AuthService.AuthError.noUser))
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        // The window ends at the *end* of the last day, so a challenge created
        // today with a length of 1 runs until tonight rather than this second.
        let lastDay = calendar.date(byAdding: .day, value: max(1, days) - 1, to: start) ?? start
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay

        let document = collection.document()
        let name = AuthService.shared.displayName
        let challenge = Challenge(id: document.documentID,
                                  title: title,
                                  emoji: emoji,
                                  ownerUid: uid,
                                  goalPerDay: goalPerDay,
                                  startDate: start,
                                  endDate: end,
                                  joinCode: Challenge.makeJoinCode(),
                                  memberUids: [uid],
                                  memberNames: [uid: name])

        document.setData(challenge.firestoreData) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(challenge))
            }
        }
    }

    /// Looks a challenge up by its join code and adds the player to it.
    func joinChallenge(code: String, completion: @escaping (Result<Challenge, Error>) -> Void) {
        guard let collection, let uid = AuthService.shared.uid else {
            completion(.failure(AuthService.AuthError.noUser))
            return
        }
        let normalised = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        collection.whereField("joinCode", isEqualTo: normalised).limit(to: 1)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let document = snapshot?.documents.first,
                      let challenge = Challenge(id: document.documentID, data: document.data()) else {
                    completion(.failure(ChallengeError.notFound))
                    return
                }
                guard !challenge.contains(uid: uid) else {
                    completion(.failure(ChallengeError.alreadyJoined))
                    return
                }

                let name = AuthService.shared.displayName
                document.reference.updateData([
                    "memberUids": FieldValue.arrayUnion([uid]),
                    "memberNames.\(uid)": name
                ]) { error in
                    if let error {
                        completion(.failure(error))
                        return
                    }
                    var joined = challenge
                    joined.memberUids.append(uid)
                    joined.memberNames[uid] = name
                    completion(.success(joined))
                }
            }
    }

    /// Removes the player from a challenge, and clears their live standing so
    /// they disappear from everyone else's leaderboard straight away.
    func leaveChallenge(id: String, completion: ((Error?) -> Void)? = nil) {
        guard let collection, let uid = AuthService.shared.uid else {
            completion?(AuthService.AuthError.noUser)
            return
        }
        collection.document(id).updateData([
            "memberUids": FieldValue.arrayRemove([uid]),
            "memberNames.\(uid)": FieldValue.delete()
        ]) { error in
            LiveStandingsService.shared.removeStanding(challengeId: id)
            completion?(error)
        }
    }
}
