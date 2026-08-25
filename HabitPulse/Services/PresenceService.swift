//
//  PresenceService.swift
//  HabitPulse
//

import Foundation
import FirebaseDatabase

/// A handle for a set of presence observers, so a screen can stop listening
/// when it goes away.
final class PresenceObservation {
    fileprivate var entries: [(reference: DatabaseReference, handle: DatabaseHandle)] = []

    func cancel() {
        for entry in entries {
            entry.reference.removeObserver(withHandle: entry.handle)
        }
        entries.removeAll()
    }

    deinit { cancel() }
}

/// Tracks who is online, in the **Realtime Database** at `presence/{uid}`.
///
/// This is the clearest example of why the app uses both databases. Firestore
/// has nothing like `onDisconnect`: a value the *server* writes when a client's
/// socket drops. Without it, a player who force-quits the app or walks into a
/// tunnel would stay "online" forever. The Realtime Database gives us that for
/// free, so presence lives there even though every other fact about a player
/// lives in Firestore.
final class PresenceService {

    static let shared = PresenceService()

    private var myReference: DatabaseReference?
    private var connectedReference: DatabaseReference?
    private var connectedHandle: DatabaseHandle?

    private init() {}

    // MARK: Publishing my own presence

    /// Marks the player online and arms the server-side disconnect handler.
    ///
    /// Everything hangs off `.info/connected`, the Realtime Database's own
    /// connection flag: `onDisconnect` has to be re-armed every time the socket
    /// comes back, so the write is done from inside that observer rather than
    /// once at launch.
    func goOnline() {
        guard let root = FirebaseService.database, let uid = AuthService.shared.uid else { return }

        let reference = root.child("presence").child(uid)
        myReference = reference

        // Only one connection observer at a time.
        if let connectedReference, let connectedHandle {
            connectedReference.removeObserver(withHandle: connectedHandle)
        }

        let connected = Database.database().reference(withPath: ".info/connected")
        connectedReference = connected
        connectedHandle = connected.observe(.value) { snapshot in
            guard snapshot.value as? Bool == true else { return }

            let name = AuthService.shared.displayName
            let avatar = AuthService.shared.avatarEmoji

            // Armed first, so there is no window where we are marked online
            // with no disconnect handler behind it.
            reference.onDisconnectSetValue([
                "online": false,
                "displayName": name,
                "avatarEmoji": avatar,
                "lastSeen": ServerValue.timestamp()
            ])

            reference.setValue([
                "online": true,
                "displayName": name,
                "avatarEmoji": avatar,
                "lastSeen": ServerValue.timestamp()
            ])
        }
    }

    /// Marks the player offline immediately — used when the app resigns
    /// active, rather than waiting for the socket to actually drop.
    func goOffline() {
        guard let myReference else { return }
        myReference.updateChildValues([
            "online": false,
            "lastSeen": ServerValue.timestamp()
        ])
    }

    // MARK: Watching other players

    /// Watches a set of players and reports `uid → isOnline` whenever any of
    /// them changes. The callback fires once per change, with the full map.
    func observePresence(uids: [String],
                         onChange: @escaping ([String: Bool]) -> Void) -> PresenceObservation {
        let observation = PresenceObservation()
        guard let root = FirebaseService.database, !uids.isEmpty else { return observation }

        var online: [String: Bool] = [:]
        let presenceRoot = root.child("presence")

        for uid in uids {
            let reference = presenceRoot.child(uid)
            let handle = reference.observe(.value) { snapshot in
                let value = snapshot.value as? [String: Any]
                online[uid] = value?["online"] as? Bool ?? false
                onChange(online)
            }
            observation.entries.append((reference, handle))
        }
        return observation
    }
}
