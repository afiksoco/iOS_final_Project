//
//  HabitDetailViewController.swift
//  HabitPulse
//

import UIKit
import FirebaseFirestore

/// History for a single habit: the three headline numbers and an eight-week
/// heat-map, all computed by `StreakCalculator` from the habit's own logs.
final class HabitDetailViewController: UIViewController {

    /// Set by whoever pushes this screen.
    var habit: Habit?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headlineLabel = UILabel()
    private let heatmap = HeatmapView()
    private let footnoteLabel = UILabel()

    private let streakTile = StatTile(title: "CURRENT STREAK")
    private let bestTile = StatTile(title: "BEST STREAK")
    private let rateTile = StatTile(title: "LAST 30 DAYS")

    private var logsListener: ListenerRegistration?
    private var heatmapHeight: NSLayoutConstraint?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = habit?.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(editTapped))
        setupViews()
        applyHabitStyling()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListening()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        logsListener?.remove()
        logsListener = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The heat-map is square-per-day, so its height depends on how wide it
        // ended up being.
        let width = contentStack.bounds.width
        guard width > 0 else { return }
        let height = heatmap.preferredHeight(forWidth: width)
        if heatmapHeight?.constant != height {
            heatmapHeight?.constant = height
        }
    }

    deinit {
        logsListener?.remove()
    }

    // MARK: Setup

    private func setupViews() {
        headlineLabel.font = .systemFont(ofSize: 15)
        headlineLabel.textColor = .secondaryLabel
        headlineLabel.numberOfLines = 0

        let tileRow = UIStackView(arrangedSubviews: [streakTile, bestTile, rateTile])
        tileRow.axis = .horizontal
        tileRow.distribution = .fillEqually
        tileRow.spacing = 10

        let heatmapTitle = UILabel()
        heatmapTitle.text = "LAST 8 WEEKS"
        heatmapTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        heatmapTitle.textColor = .secondaryLabel

        footnoteLabel.font = .systemFont(ofSize: 13)
        footnoteLabel.textColor = .tertiaryLabel
        footnoteLabel.numberOfLines = 0
        footnoteLabel.text = "Each square is one day — the darker it is, the closer you got to the target. Columns are weeks, oldest on the left."

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        for subview in [headlineLabel, tileRow, heatmapTitle, heatmap, footnoteLabel] {
            contentStack.addArrangedSubview(subview)
        }
        contentStack.setCustomSpacing(24, after: headlineLabel)
        contentStack.setCustomSpacing(24, after: tileRow)
        contentStack.setCustomSpacing(6, after: heatmapTitle)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        let heatmapHeightConstraint = heatmap.heightAnchor.constraint(equalToConstant: 120)
        heatmapHeight = heatmapHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            // Pinning the width to the frame guide is what stops the scroll
            // view from scrolling sideways.
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            heatmapHeightConstraint
        ])
    }

    private func applyHabitStyling() {
        guard let habit else { return }
        let color = HabitPalette.color(for: habit.colorKey)
        heatmap.tint = color
        heatmap.target = habit.targetPerDay
        heatmap.dayCount = 56
        streakTile.valueColor = color
        headlineLabel.text = habit.targetPerDay == 1
            ? "\(habit.emoji)  \(habit.title) — once a day"
            : "\(habit.emoji)  \(habit.title) — \(habit.targetPerDay)× a day"
    }

    // MARK: Data

    private func startListening() {
        guard let habit else { return }
        logsListener?.remove()
        logsListener = HabitStore.shared.observeLogs(habitId: habit.id, days: 90) { [weak self] logs in
            self?.render(logs: logs, habit: habit)
        }
    }

    private func render(logs: [String: Int], habit: Habit) {
        heatmap.logs = logs

        let current = StreakCalculator.currentStreak(logs: logs, target: habit.targetPerDay)
        let best = StreakCalculator.bestStreak(logs: logs, target: habit.targetPerDay)
        let rate = StreakCalculator.completionRate(logs: logs, target: habit.targetPerDay, overLast: 30)

        streakTile.value = current == 0 ? "—" : "\(current)"
        streakTile.caption = current == 1 ? "day" : "days"

        bestTile.value = best == 0 ? "—" : "\(best)"
        bestTile.caption = best == 1 ? "day" : "days"

        rateTile.value = "\(Int((rate * 100).rounded()))%"
        rateTile.caption = "completed"
    }

    // MARK: Actions

    @objc private func editTapped() {
        guard let habit else { return }
        let editor = HabitEditorViewController(habit: habit)
        present(UINavigationController(rootViewController: editor), animated: true)
    }
}
