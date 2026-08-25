//
//  ProfileViewController.swift
//  HabitPulse
//

import UIKit
import FirebaseFirestore

/// Identity and settings: the display name, the avatar, and the appearance
/// override that forces light or dark mode from inside the app.
final class ProfileViewController: UIViewController {

    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let uidLabel = UILabel()
    private let themePicker = UISegmentedControl(items: AppTheme.allCases.map(\.title))
    private let totalTile = StatTile(title: "COMPLETIONS\nLOGGED")
    private let habitsTile = StatTile(title: "ACTIVE\nHABITS")
    private let bestTile = StatTile(title: "BEST DAY\n(COMPLETIONS)")

    private var habitsListener: ListenerRegistration?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        view.backgroundColor = .systemGroupedBackground
        setupViews()
        applyStoredTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshIdentity()
        startListening()
        loadStats()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        habitsListener?.remove()
        habitsListener = nil
    }

    deinit {
        habitsListener?.remove()
    }

    // MARK: Setup

    private func setupViews() {
        avatarLabel.font = .systemFont(ofSize: 56)
        avatarLabel.textAlignment = .center

        nameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 0

        uidLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        uidLabel.textColor = .tertiaryLabel
        uidLabel.textAlignment = .center
        uidLabel.numberOfLines = 0

        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit name & avatar", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

        themePicker.selectedSegmentIndex = AppTheme.allCases.firstIndex(of: ThemeManager.shared.theme) ?? 0
        themePicker.addTarget(self, action: #selector(themeChanged), for: .valueChanged)

        let appearanceTitle = UILabel()
        appearanceTitle.text = "APPEARANCE"
        appearanceTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        appearanceTitle.textColor = .secondaryLabel

        let appearanceNote = UILabel()
        appearanceNote.text = "Every colour in the app is a dynamic colour, so it follows the system automatically — this just lets you override it."
        appearanceNote.font = .systemFont(ofSize: 12)
        appearanceNote.textColor = .tertiaryLabel
        appearanceNote.numberOfLines = 0

        let statsTitle = UILabel()
        statsTitle.text = "ALL TIME"
        statsTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        statsTitle.textColor = .secondaryLabel

        let tileRow = UIStackView(arrangedSubviews: [totalTile, habitsTile, bestTile])
        tileRow.axis = .horizontal
        tileRow.distribution = .fillEqually
        tileRow.spacing = 10

        let stack = UIStackView(arrangedSubviews: [
            avatarLabel, nameLabel, uidLabel, editButton,
            appearanceTitle, themePicker, appearanceNote,
            statsTitle, tileRow
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(2, after: avatarLabel)
        stack.setCustomSpacing(4, after: nameLabel)
        stack.setCustomSpacing(28, after: editButton)
        stack.setCustomSpacing(6, after: appearanceTitle)
        stack.setCustomSpacing(28, after: appearanceNote)
        stack.setCustomSpacing(6, after: statsTitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            themePicker.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: Identity

    private func refreshIdentity() {
        let profile = AuthService.shared.profile
        avatarLabel.text = profile?.avatarEmoji ?? "🙂"
        nameLabel.text = profile?.displayName ?? "Not signed in"
        if let uid = AuthService.shared.uid {
            uidLabel.text = "anonymous session · \(uid.prefix(10))…"
        } else {
            uidLabel.text = "no session"
        }
    }

    @objc private func editTapped() {
        let alert = UIAlertController(title: "Your profile",
                                      message: "This is how you appear on a challenge leaderboard.",
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.placeholder = "Name"
            field.autocapitalizationType = .words
            field.text = self?.nameLabel.text
        }
        alert.addTextField { [weak self] field in
            field.placeholder = "Avatar emoji"
            field.text = self?.avatarLabel.text
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let fields = alert?.textFields else { return }
            let name = (fields[0].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let avatar = (fields[1].text ?? "🙂").trimmingCharacters(in: .whitespacesAndNewlines)

            AuthService.shared.saveProfile(displayName: name,
                                           avatarEmoji: avatar.isEmpty ? "🙂" : avatar) { error in
                if let error {
                    print("[HabitPulse] could not save profile: \(error)")
                    return
                }
                self?.refreshIdentity()
                // The new name has to reach the leaderboards too.
                StandingsSync.shared.syncAll()
            }
        })
        present(alert, animated: true)
    }

    // MARK: Appearance

    private func applyStoredTheme() {
        ThemeManager.shared.applyToAllScenes()
    }

    @objc private func themeChanged() {
        let index = max(0, themePicker.selectedSegmentIndex)
        let themes = AppTheme.allCases
        ThemeManager.shared.theme = themes[min(index, themes.count - 1)]
    }

    // MARK: Stats

    private func startListening() {
        habitsListener?.remove()
        habitsListener = HabitStore.shared.observeHabits { [weak self] habits in
            self?.habitsTile.value = "\(habits.count)"
            self?.habitsTile.caption = habits.count == 1 ? "habit" : "habits"
        }
    }

    /// A one-shot read over the day rollups — the same documents the challenge
    /// scoring uses, which is why this is cheap: one range query, no fan-out
    /// across every habit.
    private func loadStats() {
        let keys = CalendarDay.recentKeys(count: 365)
        guard let first = keys.first, let last = keys.last else { return }

        HabitStore.shared.fetchDailyTotals(from: first, to: last) { [weak self] totals in
            guard let self else { return }
            let total = totals.values.reduce(0, +)
            let best = totals.values.max() ?? 0

            self.totalTile.value = "\(total)"
            self.totalTile.caption = "in the last year"
            self.bestTile.value = best == 0 ? "—" : "\(best)"
            self.bestTile.caption = best == 1 ? "completion" : "completions"
        }
    }
}
