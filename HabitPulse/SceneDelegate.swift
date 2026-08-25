//
//  SceneDelegate.swift
//  HabitPulse
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        // The window + root storyboard are wired automatically when using a
        // main storyboard. All we add is the saved light/dark preference.
        ThemeManager.shared.applyToAllScenes()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Coming back to the foreground makes us "online" again for everyone
        // watching a shared challenge.
        PresenceService.shared.goOnline()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Leaving the app flips presence immediately, rather than waiting for
        // the server-side onDisconnect handler to notice the socket drop.
        PresenceService.shared.goOffline()
    }
}
