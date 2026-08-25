//
//  RootTabBarController.swift
//  HabitPulse
//

import UIKit

/// The app's root. Besides owning the three tabs it runs the launch gate:
///
/// 1. no `GoogleService-Info.plist` → the setup screen,
/// 2. signed in but no profile yet → onboarding (pick a name),
/// 3. otherwise → straight into the app, and announce presence.
final class RootTabBarController: UITabBarController {

    private var hasStarted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabs()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Only once — `viewDidAppear` also fires when a modal is dismissed.
        guard !hasStarted else { return }
        hasStarted = true
        startSession()
    }

    // MARK: Tabs

    /// The tab bar items are set here rather than in the storyboard, because
    /// each tab's root is a navigation controller and the item belongs to the
    /// container, not to the screen inside it.
    private func configureTabs() {
        let items: [(title: String, symbol: String)] = [
            ("Today", "checkmark.circle.fill"),
            ("Challenges", "flag.2.crossed.fill"),
            ("Profile", "person.crop.circle.fill")
        ]

        for (index, item) in items.enumerated() {
            guard index < (viewControllers?.count ?? 0) else { break }
            viewControllers?[index].tabBarItem = UITabBarItem(
                title: item.title,
                image: UIImage(systemName: item.symbol),
                tag: index
            )
        }
    }

    // MARK: Launch gate

    private func startSession() {
        guard FirebaseService.isConfigured else {
            presentSetup()
            return
        }

        AuthService.shared.start { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let profile):
                if profile == nil {
                    self.presentOnboarding()
                } else {
                    PresenceService.shared.goOnline()
                }
            case .failure(let error):
                self.presentSignInFailure(error)
            }
        }
    }

    private func presentSetup() {
        guard let setup = storyboard?
            .instantiateViewController(withIdentifier: "SetupViewController") as? SetupViewController else { return }
        setup.modalPresentationStyle = .fullScreen
        present(setup, animated: false)
    }

    private func presentOnboarding() {
        guard let onboarding = storyboard?
            .instantiateViewController(withIdentifier: "OnboardingViewController") as? OnboardingViewController else { return }
        onboarding.modalPresentationStyle = .fullScreen
        onboarding.onFinished = { [weak self] in
            self?.dismiss(animated: true) {
                PresenceService.shared.goOnline()
            }
        }
        present(onboarding, animated: false)
    }

    private func presentSignInFailure(_ error: Error) {
        let alert = UIAlertController(title: "Could not sign in",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.startSession()
        })
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        present(alert, animated: true)
    }
}
