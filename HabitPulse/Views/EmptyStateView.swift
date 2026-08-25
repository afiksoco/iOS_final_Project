//
//  EmptyStateView.swift
//  HabitPulse
//

import UIKit

/// The "nothing here yet" placeholder shown behind empty tables.
final class EmptyStateView: UIView {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    init(symbolName: String, title: String, message: String) {
        super.init(frame: .zero)
        setup(symbolName: symbolName, title: title, message: message)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(symbolName: "tray", title: "Nothing here", message: "")
    }

    private func setup(symbolName: String, title: String, message: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: configuration)
        iconView.tintColor = .tertiaryLabel
        iconView.contentMode = .scaleAspectFit

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(16, after: iconView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40)
        ])
    }
}
