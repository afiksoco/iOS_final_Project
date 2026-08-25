//
//  ChallengeCell.swift
//  HabitPulse
//

import UIKit

/// One row in the Challenges list.
final class ChallengeCell: UITableViewCell {

    static let reuseIdentifier = "ChallengeCell"

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        accessoryType = .disclosureIndicator
        backgroundColor = .clear

        emojiLabel.font = .systemFont(ofSize: 30)
        emojiLabel.textAlignment = .center
        emojiLabel.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label

        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel

        statusBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 9
        statusBadge.layer.masksToBounds = true
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [emojiLabel, textStack, statusBadge])
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
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 84)
        ])
    }

    func configure(challenge: Challenge) {
        emojiLabel.text = challenge.emoji
        titleLabel.text = challenge.title

        let members = challenge.memberCount
        detailLabel.text = "\(members) player\(members == 1 ? "" : "s") · goal \(challenge.goalPerDay)/day"

        statusBadge.text = " \(challenge.statusText) "
        if challenge.isActive {
            statusBadge.textColor = .systemGreen
            statusBadge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        } else {
            statusBadge.textColor = .secondaryLabel
            statusBadge.backgroundColor = .tertiarySystemFill
        }
    }
}
