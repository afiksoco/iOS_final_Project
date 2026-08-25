//
//  AppDelegate.swift
//  HabitPulse
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Firebase must be configured before any Firestore / Database / Auth
        // call happens. `configure()` is a no-op (returning false) when the
        // GoogleService-Info.plist has not been added yet, so a fresh clone of
        // the repo shows the setup screen instead of crashing on launch.
        FirebaseService.configure()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
