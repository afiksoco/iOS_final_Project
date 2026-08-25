//
//  ChallengeDetailViewController.swift
//  HabitPulse
//

import UIKit
import FirebaseFirestore

/// The live leaderboard — the screen where both databases are visibly working
/// together.
///
/// * **Firestore** keeps the challenge itself in view, so someone joining
///   while the screen is open appears in the roster.
/// * **Realtime Database** streams the standings, everyone's online dot, and
///   the cheers, so a habit ticked on another phone re-sorts this table within
///   a moment, with no refreshing.
final class ChallengeDetailViewController: UIViewController {

    /// Set by whoever pushes this screen.
    var challenge: Challenge?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerView = UIView()
    private let subtitleLabel = UILabel()
    private let codeButton = UIButton(type: .system)
    private let cheerLabel = UILabel()

    private var standings: [StandingEntry] = []
    private var onlineByUid: [String: Bool] = [:]

    private var challengeListener: ListenerRegistration?
    private var standingsObservation: StandingsObservation?
    private var cheersObservation: StandingsObservation?
    private var presenceObservation: PresenceObservation?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = challenge?.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "hands.clap"),
            style: .plain,
            target: self,
            action: #selector(cheerTapped)
        )
        setupViews()
        refreshHeader()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListening()
        // Publish our own row on arrival, so an empty board fills in even if
        // nothing has been logged since the app opened.
        if let challenge { StandingsSync.shared.sync(challenge: challenge) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopListening()
    }

    deinit {
        stopListening()
    }

    // MARK: Setup

    private func setupViews() {
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        codeButton.titleLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .bold)
        codeButton.addTarget(self, action: #selector(copyCodeTapped), for: .touchUpInside)
        codeButton.contentHorizontalAlignment = .leading

        cheerLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        cheerLabel.textColor = .secondaryLabel
        cheerLabel.alpha = 0
        cheerLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [subtitleLabel, codeButton, cheerLabel])
        headerStack.axis = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerStack)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StandingCell.self, forCellReuseIdentifier: StandingCell.reuseIdentifier)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false

        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 32),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -32),
            headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func refreshHeader() {
        guard let challenge else { return }
        let members = challenge.memberCount
        subtitleLabel.text = "\(challenge.emoji)  Finish \(challenge.goalPerDay) habit\(challenge.goalPerDay == 1 ? "" : "s") a day to score. "
            + "\(members) player\(members == 1 ? "" : "s") · \(challenge.statusText)."
        codeButton.setTitle("Join code: \(challenge.joinCode)  ⧉", for: .normal)
    }

    // MARK: Listening

    private func startListening() {
        guard let challenge else { return }
        stopListening()

        // Firestore — the challenge document itself.
        challengeListener = ChallengeStore.shared.observeChallenge(id: challenge.id) { [weak self] updated in
            guard let self, let updated else { return }
            self.challenge = updated
            self.title = updated.title
            self.refreshHeader()
            self.observePresence(for: updated.memberUids)
        }

        // Realtime Database — the live board.
        standingsObservation = LiveStandingsService.shared.observeStandings(challengeId: challenge.id) { [weak self] entries in
            guard let self else { return }
            self.standings = entries
            self.applyPresence()
            self.tableView.reloadData()
        }

        cheersObservation = LiveStandingsService.shared.observeCheers(challengeId: challenge.id) { [weak self] name, emoji in
            self?.showCheer(from: name, emoji: emoji)
        }

        observePresence(for: challenge.memberUids)
    }

    private func observePresence(for uids: [String]) {
        presenceObservation?.cancel()
        presenceObservation = PresenceService.shared.observePresence(uids: uids) { [weak self] online in
            guard let self else { return }
            self.onlineByUid = online
            self.applyPresence()
            self.tableView.reloadData()
        }
    }

    /// Presence arrives on a different node than the standings, so the two are
    /// merged here before the table draws.
    private func applyPresence() {
        for index in standings.indices {
            standings[index].isOnline = onlineByUid[standings[index].uid] ?? false
        }
    }

    private func stopListening() {
        challengeListener?.remove()
        challengeListener = nil
        standingsObservation?.cancel()
        standingsObservation = nil
        cheersObservation?.cancel()
        cheersObservation = nil
        presenceObservation?.cancel()
        presenceObservation = nil
    }

    // MARK: Cheers

    @objc private func cheerTapped() {
        guard let challenge else { return }
        let sheet = UIAlertController(title: "Send a cheer",
                                      message: "Everyone with the challenge open will see it.",
                                      preferredStyle: .actionSheet)
        for emoji in LiveStandingsService.cheerEmojis {
            sheet.addAction(UIAlertAction(title: emoji, style: .default) { _ in
                LiveStandingsService.shared.sendCheer(challengeId: challenge.id, emoji: emoji)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    /// Fades a cheer in, holds it, then fades it out again.
    private func showCheer(from name: String, emoji: String) {
        cheerLabel.text = "\(emoji)  \(name) cheered!"
        cheerLabel.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.2) {
            self.cheerLabel.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 2.2) {
                self.cheerLabel.alpha = 0
            }
        }
    }

    @objc private func copyCodeTapped() {
        guard let challenge else { return }
        UIPasteboard.general.string = challenge.joinCode
        codeButton.setTitle("Copied \(challenge.joinCode) ✓", for: .normal)
        // Put the original label back after a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshHeader()
        }
    }
}

// MARK: - UITableViewDataSource

extension ChallengeDetailViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        standings.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        standings.isEmpty ? nil : "LEADERBOARD · LIVE"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StandingCell.reuseIdentifier,
                                                 for: indexPath)
        guard let standingCell = cell as? StandingCell, indexPath.row < standings.count else { return cell }

        let entry = standings[indexPath.row]
        standingCell.configure(entry: entry,
                               rank: indexPath.row + 1,
                               goalPerDay: challenge?.goalPerDay ?? 1,
                               isMe: entry.uid == AuthService.shared.uid)
        return standingCell
    }
}

// MARK: - UITableViewDelegate

extension ChallengeDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}
