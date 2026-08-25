//
//  ProgressRingView.swift
//  HabitPulse
//

import UIKit

/// A circular progress indicator: a faint track with a coloured arc drawn on
/// top, and the count in the middle.
///
/// Built from `CAShapeLayer`s so that changing `progress` animates the arc for
/// free via `strokeEnd`. The trade-off is that layer colours are `CGColor`,
/// which does *not* follow light/dark mode on its own — so the colours are
/// re-resolved in `traitCollectionDidChange`.
final class ProgressRingView: UIView {

    /// 0…1. Setting it animates unless `setProgress(_:animated:)` says not to.
    private(set) var progress: Double = 0

    /// Tint of the filled arc.
    var ringColor: UIColor = HabitPalette.color(for: HabitPalette.defaultKey) {
        didSet { updateColors() }
    }

    var lineWidth: CGFloat = 8 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
            setNeedsLayout()
        }
    }

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let centerLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        for shape in [trackLayer, progressLayer] {
            shape.fillColor = UIColor.clear.cgColor
            shape.lineWidth = lineWidth
            shape.lineCap = .round
            layer.addSublayer(shape)
        }
        progressLayer.strokeEnd = 0

        centerLabel.textAlignment = .center
        centerLabel.font = .systemFont(ofSize: 15, weight: .bold)
        centerLabel.adjustsFontSizeToFitWidth = true
        centerLabel.minimumScaleFactor = 0.6
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerLabel)
        NSLayoutConstraint.activate([
            centerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerLabel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.7)
        ])

        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Start at 12 o'clock and go clockwise, which is how people read a
        // progress dial.
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(arcCenter: center,
                                radius: max(0, radius),
                                startAngle: -.pi / 2,
                                endAngle: 1.5 * .pi,
                                clockwise: true)
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    /// `cgColor` snapshots the colour at assignment time, so it has to be
    /// recomputed whenever the interface style flips.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            updateColors()
        }
    }

    private func updateColors() {
        trackLayer.strokeColor = UIColor.quaternaryLabel.resolvedColor(with: traitCollection).cgColor
        progressLayer.strokeColor = ringColor.resolvedColor(with: traitCollection).cgColor
    }

    // MARK: Content

    func setProgress(_ value: Double, animated: Bool) {
        let clamped = min(1, max(0, value))
        progress = clamped
        if animated {
            progressLayer.strokeEnd = CGFloat(clamped)
        } else {
            // Disabling actions skips the implicit animation, used when a cell
            // is recycled and should show its new value immediately.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = CGFloat(clamped)
            CATransaction.commit()
        }
    }

    /// Text drawn in the middle, e.g. "2/3".
    func setCenterText(_ text: String, color: UIColor = .label) {
        centerLabel.text = text
        centerLabel.textColor = color
    }

    /// A small pop, played when a habit's daily target is reached.
    func playCompletionBounce() {
        UIView.animate(withDuration: 0.16, animations: {
            self.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
        }, completion: { _ in
            UIView.animate(withDuration: 0.22,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.6,
                           options: []) {
                self.transform = .identity
            }
        })
    }
}
