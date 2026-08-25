//
//  OnboardingViewController.swift
//  HabitPulse
//

import UIKit

/// First-launch screen: pick a display name and an avatar.
///
/// Sign-in itself already happened silently and anonymously, so there is no
/// password to choose and nothing to verify — this is only about how the
/// player will appear on a shared leaderboard.
final class OnboardingViewController: UIViewController {

    /// Called once the profile has been written.
    var onFinished: (() -> Void)?

    private let nameField = UITextField()
    private let avatarPicker = UISegmentedControl(items: Array(UserProfile.avatarChoices.prefix(5)))
    private let continueButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupViews()
        updateContinueState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameField.becomeFirstResponder()
    }

    private func setupViews() {
        let titleLabel = UILabel()
        titleLabel.text = "Welcome to HabitPulse"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Pick a name your friends will recognise on the leaderboard."
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        nameField.placeholder = "Your name"
        nameField.borderStyle = .roundedRect
        nameField.font = .systemFont(ofSize: 18)
        nameField.autocapitalizationType = .words
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)

        avatarPicker.selectedSegmentIndex = 0
        // The segmented control shows emoji, so it needs a bigger font than
        // the default to stay legible.
        avatarPicker.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 20)], for: .normal)

        continueButton.setTitle("Start tracking", for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        continueButton.backgroundColor = .tintColor
        continueButton.tintColor = .white
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 12
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, nameField, avatarPicker, continueButton, spinner
        ])
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(8, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),

            nameField.heightAnchor.constraint(equalToConstant: 48),
            avatarPicker.heightAnchor.constraint(equalToConstant: 40),
            continueButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    // MARK: State

    private var trimmedName: String {
        (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateContinueState() {
        let valid = !trimmedName.isEmpty
        continueButton.isEnabled = valid
        continueButton.alpha = valid ? 1 : 0.4
    }

    @objc private func nameChanged() {
        updateContinueState()
    }

    // MARK: Actions

    @objc private func continueTapped() {
        let name = trimmedName
        guard !name.isEmpty else { return }

        let index = max(0, avatarPicker.selectedSegmentIndex)
        let avatar = UserProfile.avatarChoices[min(index, UserProfile.avatarChoices.count - 1)]

        setBusy(true)
        AuthService.shared.saveProfile(displayName: name, avatarEmoji: avatar) { [weak self] error in
            guard let self else { return }
            self.setBusy(false)
            if let error {
                self.presentError(error)
                return
            }
            self.view.endEditing(true)
            self.onFinished?()
        }
    }

    private func setBusy(_ busy: Bool) {
        continueButton.isEnabled = !busy
        continueButton.alpha = busy ? 0.4 : 1
        nameField.isEnabled = !busy
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Could not save",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension OnboardingViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !trimmedName.isEmpty { continueTapped() }
        return true
    }
}
