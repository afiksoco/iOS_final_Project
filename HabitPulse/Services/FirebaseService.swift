//
//  FirebaseService.swift
//  HabitPulse
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseDatabase

/// Owns the one-time Firebase start-up and hands out the two database handles
/// the rest of the app uses.
///
/// The app talks to **both** Firebase databases on purpose, because they are
/// good at different things:
///
/// * **Firestore** — habits, daily logs, profiles, challenge definitions.
///   Documents that need to be queried, filtered and kept forever.
/// * **Realtime Database** — live challenge standings and who is online.
///   Small values that change constantly and must reach every other device
///   immediately, plus `onDisconnect`, which Firestore has no equivalent for.
enum FirebaseService {

    /// False until `configure()` finds a GoogleService-Info.plist and starts
    /// Firebase. Every service checks this before touching the SDK, so a clone
    /// of the repo without the plist shows the setup screen instead of
    /// crashing on the first call.
    private(set) static var isConfigured = false

    /// Whether the project actually has a Realtime Database.
    ///
    /// Firebase only writes `DATABASE_URL` into GoogleService-Info.plist once
    /// an RTDB instance has been created in the console — and `Database.database()`
    /// raises a fatal error when that key is missing, rather than returning nil.
    /// So it is checked up front: without it the Firestore half of the app still
    /// works and the live challenge features simply stay quiet, instead of taking
    /// the whole app down on launch.
    private(set) static var isRealtimeDatabaseAvailable = false

    /// Starts Firebase. Safe to call more than once.
    static func configure() {
        guard !isConfigured else { return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("[HabitPulse] GoogleService-Info.plist is missing — see docs/FIREBASE_SETUP.md")
            return
        }
        FirebaseApp.configure()

        // Firestore keeps a local copy so the Today screen still works with no
        // network, and syncs the writes once the connection is back.
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings

        let options = NSDictionary(contentsOfFile: path) as? [String: Any]
        let databaseURL = options?["DATABASE_URL"] as? String
        isRealtimeDatabaseAvailable = !(databaseURL ?? "").isEmpty

        if isRealtimeDatabaseAvailable {
            // The same offline behaviour for the Realtime Database, so a
            // challenge board opens instantly with the last known standings.
            // Must be set before any other Database call.
            Database.database().isPersistenceEnabled = true
        } else {
            print("""
            [HabitPulse] No DATABASE_URL in GoogleService-Info.plist — the live \
            challenge leaderboard and presence are disabled. Create the Realtime \
            Database in the Firebase console, then download the plist again. \
            See docs/FIREBASE_SETUP.md step 4.
            """)
        }

        isConfigured = true
    }

    /// The Firestore handle. Only valid once `isConfigured` is true.
    static var firestore: Firestore { Firestore.firestore() }

    /// The Realtime Database root, or `nil` when the project has no Realtime
    /// Database yet. Callers guard on it rather than assuming it exists.
    static var database: DatabaseReference? {
        guard isConfigured, isRealtimeDatabaseAvailable else { return nil }
        return Database.database().reference()
    }
}
