//
//  HabitCell.swift
//  HabitPulse
//

import UIKit

/// One row on the Today screen: emoji, title, today's progress ring, and a
/// button that logs another completion.
final class HabitCell: UITableViewCell {

    static let reuseIdentifier = "HabitCell"

    /// Called when the player taps the + button.
    var onIncrement: (() -> Void)?

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let ring = ProgressRingView()
    private let addButton = UIButton(type: .system)

    /// Remembered so the ring only bounces on the tap that *completes* a
    /// habit, not on every redraw of an already-complete one.
    private var wasComplete = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .default
        accessoryType = .disclosureIndicator
        backgroundColor = .clear

        emojiLabel.font = .systemFont(ofSize: 30)
        emojiLabel.textAlignment = .center
        emojiLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel

        ring.lineWidth = 6
        ring.translatesAutoresizingMaskIntoConstraints = false

        addButton.setImage(UIImage(systemName: "plus.circle.fill",
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 28)),
                           for: .normal)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.accessibilityLabel = "Log one completion"

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [emojiLabel, textStack, ring, addButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            emojiLabel.widthAnchor.constraint(equalToConstant: 38),
            ring.widthAnchor.constraint(equalToConstant: 44),
            ring.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onIncrement = nil
        wasComplete = false
        ring.setProgress(0, animated: false)
    }

    // MARK: Content

    func configure(habit: Habit, count: Int, streak: Int) {
        let color = HabitPalette.color(for: habit.colorKey)
        let complete = StreakCalculator.isComplete(count: count, target: habit.targetPerDay)

        emojiLabel.text = habit.emoji
        titleLabel.text = habit.title
        ring.ringColor = color
        ring.setCenterText("\(count)/\(habit.targetPerDay)", color: complete ? color : .secondaryLabel)
        ring.setProgress(StreakCalculator.progress(count: count, target: habit.targetPerDay),
                         animated: false)
        addButton.tintColor = color

        // A streak is only worth showing once it means something.
        if streak > 1 {
            subtitleLabel.text = complete ? "Done today · 🔥 \(streak) days" : "🔥 \(streak) day streak"
        } else {
            subtitleLabel.text = complete ? "Done today" : "\(max(0, habit.targetPerDay - count)) to go"
        }

        wasComplete = complete
    }

    /// Animates to a new count after the player taps +, bouncing the ring if
    /// this is the tap that finished the habit for the day.
    func animate(to count: Int, target: Int, color: UIColor) {
        let complete = StreakCalculator.isComplete(count: count, target: target)
        ring.setCenterText("\(count)/\(target)", color: complete ? color : .secondaryLabel)
        ring.setProgress(StreakCalculator.progress(count: count, target: target), animated: true)
        if complete && !wasComplete {
            ring.playCompletionBounce()
        }
        wasComplete = complete
    }

    @objc private func addTapped() {
        onIncrement?()
    }
}
