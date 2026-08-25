//
//  TodayViewController.swift
//  HabitPulse
//

import UIKit
import FirebaseFirestore

/// The home screen: every active habit, and how far along it is today.
///
/// Two Firestore listeners drive the whole screen — one for the habit
/// definitions, one for today's rollup document. Because they are live
/// listeners rather than one-off reads, logging a habit on a second device
/// updates this list without any refreshing.
final class TodayViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerLabel = UILabel()
    private let summaryLabel = UILabel()
    private lazy var emptyView = EmptyStateView(
        symbolName: "list.bullet.clipboard",
        title: "No habits yet",
        message: "Tap + to add the first thing you want to do every day."
    )

    private var habits: [Habit] = []
    private var today = DaySummary(day: CalendarDay.todayKey)
    /// habitId → that habit's own history, used only for the streak label.
    private var streaks: [String: Int] = [:]

    private var habitsListener: ListenerRegistration?
    private var dayListener: ListenerRegistration?
    private var logListeners: [String: ListenerRegistration] = [:]

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Today"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addHabitTapped))
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshHeader()
        startListening()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Listeners cost a live connection each, so they are dropped whenever
        // the screen is not on show and re-attached in `viewWillAppear`.
        stopListening()
    }

    deinit {
        stopListening()
    }

    // MARK: Setup

    private func setupViews() {
        headerLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        headerLabel.textColor = .secondaryLabel

        summaryLabel.font = .systemFont(ofSize: 26, weight: .bold)
        summaryLabel.textColor = .label
        summaryLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [headerLabel, summaryLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(HabitCell.self, forCellReuseIdentifier: HabitCell.reuseIdentifier)
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerStack)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            headerStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: Listening

    private func startListening() {
        stopListening()

        habitsListener = HabitStore.shared.observeHabits { [weak self] habits in
            guard let self else { return }
            self.habits = habits
            self.syncLogListeners()
            self.tableView.reloadData()
            self.refreshHeader()
        }

        dayListener = HabitStore.shared.observeDay(CalendarDay.todayKey) { [weak self] summary in
            guard let self else { return }
            self.today = summary
            self.tableView.reloadData()
            self.refreshHeader()
        }
    }

    /// One extra listener per habit, purely so each row can show its streak.
    /// They are added and removed as the habit list changes rather than being
    /// rebuilt wholesale, so scrolling never tears down a live listener.
    private func syncLogListeners() {
        let currentIds = Set(habits.map(\.id))

        for (habitId, listener) in logListeners where !currentIds.contains(habitId) {
            listener.remove()
            logListeners.removeValue(forKey: habitId)
            streaks.removeValue(forKey: habitId)
        }

        for habit in habits where logListeners[habit.id] == nil {
            logListeners[habit.id] = HabitStore.shared.observeLogs(habitId: habit.id, days: 90) { [weak self] logs in
                guard let self else { return }
                self.streaks[habit.id] = StreakCalculator.currentStreak(logs: logs, target: habit.targetPerDay)
                self.reloadRow(for: habit.id)
            }
        }
    }

    private func stopListening() {
        habitsListener?.remove()
        habitsListener = nil
        dayListener?.remove()
        dayListener = nil
        logListeners.values.forEach { $0.remove() }
        logListeners.removeAll()
    }

    private func reloadRow(for habitId: String) {
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else { return }
        let indexPath = IndexPath(row: index, section: 0)
        guard tableView.indexPathsForVisibleRows?.contains(indexPath) == true else { return }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    // MARK: Header

    private func refreshHeader() {
        headerLabel.text = CalendarDay.displayLabel(for: CalendarDay.todayKey).uppercased()

        let name = AuthService.shared.profile?.displayName
        let done = habits.filter {
            StreakCalculator.isComplete(count: today.count(for: $0.id), target: $0.targetPerDay)
        }.count

        if habits.isEmpty {
            summaryLabel.text = name.map { "Hi \($0)" } ?? "Hi there"
        } else if done == habits.count {
            summaryLabel.text = "All done today 🎉"
        } else {
            summaryLabel.text = "\(done) of \(habits.count) done"
        }

        tableView.backgroundView = habits.isEmpty ? emptyView : nil
    }

    // MARK: Actions

    @objc private func addHabitTapped() {
        presentEditor(for: nil)
    }

    private func presentEditor(for habit: Habit?) {
        let editor = HabitEditorViewController(habit: habit)
        let navigation = UINavigationController(rootViewController: editor)
        present(navigation, animated: true)
    }

    /// Logs one completion and republishes the player's challenge standings.
    private func increment(habit: Habit) {
        let newCount = today.count(for: habit.id) + 1

        // The row is animated immediately rather than waiting for Firestore
        // to echo the write back, so the tap feels instant — the listener
        // confirms the same number a moment later. The row index is resolved
        // here rather than captured when the cell was built, so a list that
        // reordered in between still animates the right row.
        if let row = habits.firstIndex(where: { $0.id == habit.id }),
           let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? HabitCell {
            cell.animate(to: newCount,
                         target: habit.targetPerDay,
                         color: HabitPalette.color(for: habit.colorKey))
        }

        HabitStore.shared.adjustCount(habitId: habit.id, delta: 1) { error in
            if let error {
                print("[HabitPulse] could not log completion: \(error)")
                return
            }
            StandingsSync.shared.syncAll()
        }
    }

    private func confirmDelete(habit: Habit) {
        let alert = UIAlertController(
            title: "Delete \(habit.title)?",
            message: "Its history will be removed too. Archive it instead to keep the history.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Archive", style: .default) { _ in
            HabitStore.shared.archiveHabit(id: habit.id)
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            HabitStore.shared.deleteHabit(id: habit.id)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // Required so the sheet has an anchor on iPad.
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX,
                                                                 y: view.bounds.midY,
                                                                 width: 0,
                                                                 height: 0)
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension TodayViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        habits.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HabitCell.reuseIdentifier,
                                                 for: indexPath)
        guard let habitCell = cell as? HabitCell, indexPath.row < habits.count else { return cell }

        let habit = habits[indexPath.row]
        habitCell.configure(habit: habit,
                            count: today.count(for: habit.id),
                            streak: streaks[habit.id] ?? 0)
        habitCell.onIncrement = { [weak self] in
            self?.increment(habit: habit)
        }
        return habitCell
    }
}

// MARK: - UITableViewDelegate

extension TodayViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < habits.count else { return }

        guard let detail = storyboard?
            .instantiateViewController(withIdentifier: "HabitDetailViewController") as? HabitDetailViewController else {
            return
        }
        detail.habit = habits[indexPath.row]
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < habits.count else { return nil }
        let habit = habits[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            self?.confirmDelete(habit: habit)
            done(true)
        }

        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, done in
            self?.presentEditor(for: habit)
            done(true)
        }
        edit.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [delete, edit])
    }

    func tableView(_ tableView: UITableView,
                   leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < habits.count else { return nil }
        let habit = habits[indexPath.row]
        guard today.count(for: habit.id) > 0 else { return nil }

        // Undo, for the inevitable accidental tap.
        let undo = UIContextualAction(style: .normal, title: "Undo one") { _, _, done in
            HabitStore.shared.adjustCount(habitId: habit.id, delta: -1) { _ in
                StandingsSync.shared.syncAll()
            }
            done(true)
        }
        undo.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [undo])
    }
}
