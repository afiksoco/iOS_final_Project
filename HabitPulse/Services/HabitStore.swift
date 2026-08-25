//
//  HabitStore.swift
//  HabitPulse
//

import Foundation
import FirebaseFirestore

/// All habit reading and writing, backed by **Cloud Firestore**.
///
/// Layout under the signed-in player:
/// ```
/// users/{uid}
///   ├─ habits/{habitId}                  the habit definition
///   │    └─ logs/{yyyy-MM-dd}            that habit's history  → heat-map
///   └─ days/{yyyy-MM-dd}                 rollup of every habit → Today + challenges
/// ```
/// Every write touches both the per-habit log and the day rollup inside one
/// `WriteBatch`, so the two views of the same fact are always in step.
///
/// Firestore was chosen over the Realtime Database for this data because it is
/// what the app needs to *query*: "the last 60 days of this habit", "every day
/// in the challenge window". Those are range reads over documents, which is
/// exactly Firestore's strength.
final class HabitStore {

    static let shared = HabitStore()

    private init() {}

    // MARK: References

    private var userDocument: DocumentReference? {
        guard FirebaseService.isConfigured, let uid = AuthService.shared.uid else { return nil }
        return FirebaseService.firestore.collection("users").document(uid)
    }

    private var habitsCollection: CollectionReference? {
        userDocument?.collection("habits")
    }

    private var daysCollection: CollectionReference? {
        userDocument?.collection("days")
    }

    // MARK: Reading

    /// Live list of the player's active habits, oldest first.
    /// Returns `nil` if there is no signed-in user to listen for.
    @discardableResult
    func observeHabits(onChange: @escaping ([Habit]) -> Void) -> ListenerRegistration? {
        guard let habitsCollection else { return nil }
        return habitsCollection
            .whereField("archived", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { print("[HabitPulse] habits listener failed: \(error)") }
                    onChange([])
                    return
                }
                // Sorting locally keeps the query to a single `where`, which
                // means Firestore doesn't need a composite index for it.
                let habits = documents
                    .compactMap { Habit(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt < $1.createdAt }
                onChange(habits)
            }
    }

    /// Live rollup for one day — used by the Today screen with today's key.
    @discardableResult
    func observeDay(_ dayKey: String, onChange: @escaping (DaySummary) -> Void) -> ListenerRegistration? {
        guard let daysCollection else { return nil }
        return daysCollection.document(dayKey).addSnapshotListener { snapshot, error in
            if let error { print("[HabitPulse] day listener failed: \(error)") }
            let data = snapshot?.data() ?? [:]
            onChange(DaySummary(day: dayKey, data: data))
        }
    }

    /// Live history for a single habit, as `dayKey → count`, limited to the
    /// most recent `days` days.
    @discardableResult
    func observeLogs(habitId: String,
                     days: Int,
                     onChange: @escaping ([String: Int]) -> Void) -> ListenerRegistration? {
        guard let habitsCollection else { return nil }
        let earliest = CalendarDay.recentKeys(count: days).first ?? CalendarDay.todayKey
        return habitsCollection.document(habitId).collection("logs")
            .whereField("day", isGreaterThanOrEqualTo: earliest)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { print("[HabitPulse] logs listener failed: \(error)") }
                    onChange([:])
                    return
                }
                var logs: [String: Int] = [:]
                for document in documents {
                    guard let log = HabitLog(day: document.documentID, data: document.data()) else { continue }
                    logs[log.day] = log.count
                }
                onChange(logs)
            }
    }

    /// One-shot read of the daily totals across a date range, used to score a
    /// challenge. Returns `dayKey → total completions`.
    func fetchDailyTotals(from startKey: String,
                          to endKey: String,
                          completion: @escaping ([String: Int]) -> Void) {
        guard let daysCollection else {
            completion([:])
            return
        }
        daysCollection
            .whereField("day", isGreaterThanOrEqualTo: startKey)
            .whereField("day", isLessThanOrEqualTo: endKey)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { print("[HabitPulse] daily totals read failed: \(error)") }
                    completion([:])
                    return
                }
                var totals: [String: Int] = [:]
                for document in documents {
                    totals[document.documentID] = max(0, document.data()["total"] as? Int ?? 0)
                }
                completion(totals)
            }
    }

    // MARK: Writing

    /// Creates a habit and returns its new id.
    @discardableResult
    func createHabit(title: String,
                     emoji: String,
                     colorKey: String,
                     targetPerDay: Int,
                     completion: ((Error?) -> Void)? = nil) -> String? {
        guard let habitsCollection else {
            completion?(AuthService.AuthError.noUser)
            return nil
        }
        let document = habitsCollection.document()
        let habit = Habit(id: document.documentID,
                          title: title,
                          emoji: emoji,
                          colorKey: colorKey,
                          targetPerDay: targetPerDay)
        document.setData(habit.firestoreData) { error in completion?(error) }
        return document.documentID
    }

    /// Saves edits to an existing habit.
    func updateHabit(_ habit: Habit, completion: ((Error?) -> Void)? = nil) {
        guard let habitsCollection else {
            completion?(AuthService.AuthError.noUser)
            return
        }
        habitsCollection.document(habit.id)
            .setData(habit.firestoreData, merge: true) { error in completion?(error) }
    }

    /// Hides a habit from the Today screen but keeps its history.
    func archiveHabit(id: String, completion: ((Error?) -> Void)? = nil) {
        guard let habitsCollection else {
            completion?(AuthService.AuthError.noUser)
            return
        }
        habitsCollection.document(id)
            .setData(["archived": true], merge: true) { error in completion?(error) }
    }

    /// Removes a habit and its logs for good.
    ///
    /// Firestore does not delete sub-collections along with their parent, so
    /// the logs are fetched and batched in explicitly. The day rollups are left
    /// alone on purpose — they are the record of what the player actually did,
    /// and challenge scores are built from them.
    func deleteHabit(id: String, completion: ((Error?) -> Void)? = nil) {
        guard let habitsCollection else {
            completion?(AuthService.AuthError.noUser)
            return
        }
        let habitDocument = habitsCollection.document(id)
        habitDocument.collection("logs").getDocuments { snapshot, error in
            if let error {
                completion?(error)
                return
            }
            let batch = FirebaseService.firestore.batch()
            for document in snapshot?.documents ?? [] {
                batch.deleteDocument(document.reference)
            }
            batch.deleteDocument(habitDocument)
            batch.commit { error in completion?(error) }
        }
    }

    /// Records a completion (`delta` of +1) or takes one back (`-1`) for a
    /// habit on a given day.
    ///
    /// The per-habit log and the day rollup are both moved by the same amount
    /// in one atomic batch, using `FieldValue.increment` so two quick taps can
    /// never overwrite each other.
    func adjustCount(habitId: String,
                     day: String = CalendarDay.todayKey,
                     delta: Int,
                     completion: ((Error?) -> Void)? = nil) {
        guard delta != 0 else {
            completion?(nil)
            return
        }
        guard let habitsCollection, let daysCollection else {
            completion?(AuthService.AuthError.noUser)
            return
        }

        let step = Int64(delta)
        let now = Date().timeIntervalSince1970
        let batch = FirebaseService.firestore.batch()

        let logDocument = habitsCollection.document(habitId).collection("logs").document(day)
        batch.setData([
            "day": day,
            "count": FieldValue.increment(step),
            "updatedAt": now
        ], forDocument: logDocument, merge: true)

        let dayDocument = daysCollection.document(day)
        batch.setData([
            "day": day,
            "total": FieldValue.increment(step),
            "counts": [habitId: FieldValue.increment(step)],
            "updatedAt": now
        ], forDocument: dayDocument, merge: true)

        batch.commit { error in completion?(error) }
    }
}
