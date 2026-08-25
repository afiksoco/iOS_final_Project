//
//  ChallengesViewController.swift
//  HabitPulse
//

import UIKit
import FirebaseFirestore

/// The list of challenges the player has joined, with the two ways in:
/// create a new one, or type someone else's join code.
final class ChallengesViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private lazy var emptyView = EmptyStateView(
        symbolName: "flag.2.crossed",
        title: "No challenges yet",
        message: "Create one and share the code, or join a friend's with theirs."
    )

    private var challenges: [Challenge] = []
    private var listener: ListenerRegistration?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Challenges"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addTapped))
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListening()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    private func setupViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChallengeCell.self, forCellReuseIdentifier: ChallengeCell.reuseIdentifier)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: Data

    private func startListening() {
        listener?.remove()
        listener = ChallengeStore.shared.observeMyChallenges { [weak self] challenges in
            guard let self else { return }
            self.challenges = challenges
            self.tableView.reloadData()
            self.tableView.backgroundView = challenges.isEmpty ? self.emptyView : nil

            // Joining on another device should show a score here right away,
            // so every visible challenge gets its standing refreshed.
            for challenge in challenges {
                StandingsSync.shared.sync(challenge: challenge)
            }
        }
    }

    // MARK: Actions

    @objc private func addTapped() {
        let sheet = UIAlertController(title: "Challenges",
                                      message: "Compete with friends on total habits per day.",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Create a challenge", style: .default) { [weak self] _ in
            self?.presentCreate()
        })
        sheet.addAction(UIAlertAction(title: "Join with a code", style: .default) { [weak self] _ in
            self?.presentJoin()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    private func presentCreate() {
        let alert = UIAlertController(title: "New challenge",
                                      message: "Everyone competes on how many habits they finish each day.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Name, e.g. October Reset"
            field.autocapitalizationType = .sentences
        }
        alert.addTextField { field in
            field.placeholder = "Habits per day to qualify (e.g. 3)"
            field.keyboardType = .numberPad
        }
        alert.addTextField { field in
            field.placeholder = "Length in days (e.g. 14)"
            field.keyboardType = .numberPad
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let fields = alert?.textFields else { return }
            let title = (fields[0].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            let goal = Int(fields[1].text ?? "") ?? 3
            let days = Int(fields[2].text ?? "") ?? 14

            ChallengeStore.shared.createChallenge(title: title,
                                                  emoji: Challenge.emojiChoices.randomElement() ?? "🏁",
                                                  goalPerDay: goal,
                                                  days: days) { result in
                switch result {
                case .success(let challenge):
                    StandingsSync.shared.sync(challenge: challenge)
                    self?.presentShare(challenge: challenge)
                case .failure(let error):
                    self?.presentError(error)
                }
            }
        })
        present(alert, animated: true)
    }

    private func presentJoin() {
        let alert = UIAlertController(title: "Join a challenge",
                                      message: "Type the six-character code your friend shared.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "ABC123"
            field.autocapitalizationType = .allCharacters
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Join", style: .default) { [weak self, weak alert] _ in
            let code = alert?.textFields?.first?.text ?? ""
            ChallengeStore.shared.joinChallenge(code: code) { result in
                switch result {
                case .success(let challenge):
                    StandingsSync.shared.sync(challenge: challenge)
                case .failure(let error):
                    self?.presentError(error)
                }
            }
        })
        present(alert, animated: true)
    }

    private func presentShare(challenge: Challenge) {
        let alert = UIAlertController(
            title: "Share the code",
            message: "Friends join \(challenge.title) with:\n\n\(challenge.joinCode)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Copy code", style: .default) { _ in
            UIPasteboard.general.string = challenge.joinCode
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        present(alert, animated: true)
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Something went wrong",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ChallengesViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        challenges.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChallengeCell.reuseIdentifier,
                                                 for: indexPath)
        guard let challengeCell = cell as? ChallengeCell, indexPath.row < challenges.count else { return cell }
        challengeCell.configure(challenge: challenges[indexPath.row])
        return challengeCell
    }
}

// MARK: - UITableViewDelegate

extension ChallengesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < challenges.count else { return }

        guard let detail = storyboard?
            .instantiateViewController(withIdentifier: "ChallengeDetailViewController") as? ChallengeDetailViewController else {
            return
        }
        detail.challenge = challenges[indexPath.row]
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < challenges.count else { return nil }
        let challenge = challenges[indexPath.row]

        let leave = UIContextualAction(style: .destructive, title: "Leave") { _, _, done in
            ChallengeStore.shared.leaveChallenge(id: challenge.id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [leave])
    }
}
