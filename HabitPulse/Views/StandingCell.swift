//
//  StandingCell.swift
//  HabitPulse
//

import UIKit

/// One row of the live leaderboard.
final class StandingCell: UITableViewCell {

    static let reuseIdentifier = "StandingCell"

    private let rankLabel = UILabel()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let pointsLabel = UILabel()
    private let onlineDot = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear

        rankLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        rankLabel.textColor = .secondaryLabel
        rankLabel.textAlignment = .center
        rankLabel.setContentHuggingPriority(.required, for: .horizontal)

        avatarLabel.font = .systemFont(ofSize: 26)
        avatarLabel.textAlignment = .center
        avatarLabel.setContentHuggingPriority(.required, for: .horizontal)

        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label

        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel

        pointsLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        pointsLabel.textColor = .label
        pointsLabel.textAlignment = .right
        pointsLabel.setContentHuggingPriority(.required, for: .horizontal)

        onlineDot.layer.cornerRadius = 4
        onlineDot.translatesAutoresizingMaskIntoConstraints = false

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, onlineDot])
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 6

        let textStack = UIStackView(arrangedSubviews: [nameRow, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [rankLabel, avatarLabel, textStack, pointsLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            rankLabel.widthAnchor.constraint(equalToConstant: 26),
            avatarLabel.widthAnchor.constraint(equalToConstant: 32),
            onlineDot.widthAnchor.constraint(equalToConstant: 8),
            onlineDot.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    /// - Parameter isMe: highlights the player's own row so they can find
    ///   themselves in a long list at a glance.
    func configure(entry: StandingEntry, rank: Int, goalPerDay: Int, isMe: Bool) {
        // The top three get a medal instead of a number.
        switch rank {
        case 1:  rankLabel.text = "🥇"
        case 2:  rankLabel.text = "🥈"
        case 3:  rankLabel.text = "🥉"
        default: rankLabel.text = "\(rank)"
        }

        avatarLabel.text = entry.avatarEmoji
        nameLabel.text = isMe ? "\(entry.displayName) (you)" : entry.displayName
        nameLabel.textColor = isMe ? .tintColor : .label

        var parts = ["\(entry.todayCount)/\(goalPerDay) today"]
        if entry.streak > 1 { parts.append("🔥 \(entry.streak)") }
        detailLabel.text = parts.joined(separator: " · ")

        pointsLabel.text = "\(entry.points)"

        onlineDot.backgroundColor = entry.isOnline ? .systemGreen : .quaternaryLabel

        backgroundColor = isMe ? UIColor.tintColor.withAlphaComponent(0.08) : .clear
    }
}
