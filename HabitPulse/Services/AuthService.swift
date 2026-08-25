//
//  AuthService.swift
//  HabitPulse
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Signs the player in and owns their profile document.
///
/// Sign-in is **anonymous**: the player never types a password, but Firebase
/// still hands out a stable UID that survives relaunches. That UID is what the
/// security rules key off, what their habits hang under in Firestore, and what
/// identifies them on a challenge board. The display name they pick is purely
/// cosmetic and is stored alongside it in `users/{uid}`.
final class AuthService {

    static let shared = AuthService()

    enum AuthError: LocalizedError {
        case notConfigured
        case noUser

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Firebase has not been configured yet."
            case .noUser:        return "Could not start a session. Check your connection and try again."
            }
        }
    }

    /// The loaded profile, or `nil` when the player has not picked a name yet.
    private(set) var profile: UserProfile?

    private init() {}

    var uid: String? {
        guard FirebaseService.isConfigured else { return nil }
        return Auth.auth().currentUser?.uid
    }

    /// Display name if we have one, otherwise a neutral placeholder — used for
    /// the live standings rows, which should never show an empty name.
    var displayName: String { profile?.displayName ?? "Player" }
    var avatarEmoji: String { profile?.avatarEmoji ?? "🙂" }

    /// Signs in if needed, then loads `users/{uid}`.
    ///
    /// The result is `nil` when the account exists but has no profile document
    /// yet — that is the signal to show the onboarding screen.
    func start(completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        guard FirebaseService.isConfigured else {
            completion(.failure(AuthError.notConfigured))
            return
        }

        if let user = Auth.auth().currentUser {
            loadProfile(uid: user.uid, completion: completion)
            return
        }

        Auth.auth().signInAnonymously { [weak self] result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let uid = result?.user.uid else {
                completion(.failure(AuthError.noUser))
                return
            }
            self?.loadProfile(uid: uid, completion: completion)
        }
    }

    private func loadProfile(uid: String, completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        FirebaseService.firestore.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }
            let profile = snapshot?.data().flatMap { UserProfile(uid: uid, data: $0) }
            self?.profile = profile
            completion(.success(profile))
        }
    }

    /// Creates or updates the profile document, then republishes presence so
    /// everyone watching a shared challenge sees the new name straight away.
    func saveProfile(displayName: String,
                     avatarEmoji: String,
                     completion: @escaping (Error?) -> Void) {
        guard let uid else {
            completion(AuthError.noUser)
            return
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(AuthError.noUser)
            return
        }

        let profile = UserProfile(uid: uid,
                                  displayName: trimmed,
                                  avatarEmoji: avatarEmoji,
                                  createdAt: self.profile?.createdAt ?? Date())

        FirebaseService.firestore.collection("users").document(uid)
            .setData(profile.firestoreData, merge: true) { [weak self] error in
                if error == nil {
                    self?.profile = profile
                    PresenceService.shared.goOnline()
                }
                completion(error)
            }
    }
}
