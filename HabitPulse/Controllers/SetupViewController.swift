//
//  SetupViewController.swift
//  HabitPulse
//

import UIKit

/// Shown when the app launches without a `GoogleService-Info.plist`.
///
/// A fresh clone of this repository has no Firebase credentials in it, and
/// calling into the SDK without them crashes on launch. Rather than let that
/// happen, `FirebaseService` refuses to configure and this screen explains
/// exactly what is missing — so the project always builds and runs, even
/// before anyone has touched the Firebase console.
final class SetupViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupViews()
    }

    private func setupViews() {
        let iconView = UIImageView(image: UIImage(systemName: "gearshape.2.fill",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 52)))
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "One step left"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 16)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        bodyLabel.text = """
        HabitPulse needs its Firebase credentials before it can store anything.

        In the Firebase console, add an iOS app with the bundle id \
        com.afik.HabitPulse, download GoogleService-Info.plist, and drop it \
        into the HabitPulse folder next to Info.plist.

        The full walkthrough is in docs/FIREBASE_SETUP.md.
        """

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
    }
}
