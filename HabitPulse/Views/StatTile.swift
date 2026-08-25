//
//  StatTile.swift
//  HabitPulse
//

import UIKit

/// One of the three headline numbers at the top of the screen.
final class StatTile: UIView {

    var value: String = "—" {
        didSet { valueLabel.text = value }
    }

    var caption: String = "" {
        didSet { captionLabel.text = caption }
    }

    var valueColor: UIColor = .label {
        didSet { valueLabel.textColor = valueColor }
    }

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)

        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 2

        valueLabel.text = value
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        captionLabel.font = .systemFont(ofSize: 12)
        captionLabel.textColor = .tertiaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("StatTile is created in code only")
    }
}
