//
//  HeatmapView.swift
//  HabitPulse
//

import UIKit

/// A GitHub-style grid of one square per day, shaded by how much of that day's
/// target was met.
///
/// Drawn in `draw(_:)` with `UIColor` rather than layers, which means UIKit
/// re-runs it automatically when the interface style changes — no manual
/// `cgColor` bookkeeping needed, unlike `ProgressRingView`.
final class HeatmapView: UIView {

    /// Number of days shown; laid out in columns of 7 (one column per week).
    var dayCount: Int = 56 {
        didSet { rebuildKeys() }
    }

    /// `dayKey → count`.
    var logs: [String: Int] = [:] {
        didSet { setNeedsDisplay() }
    }

    var target: Int = 1 {
        didSet { setNeedsDisplay() }
    }

    var tint: UIColor = HabitPalette.color(for: HabitPalette.defaultKey) {
        didSet { setNeedsDisplay() }
    }

    private var keys: [String] = []
    private let spacing: CGFloat = 4
    private let rows = 7

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        rebuildKeys()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        rebuildKeys()
    }

    private func rebuildKeys() {
        keys = CalendarDay.recentKeys(count: dayCount)
        setNeedsDisplay()
    }

    /// Height needed for a given width, so a caller can pin a sensible
    /// constraint instead of guessing.
    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let columns = CGFloat(Int(ceil(Double(dayCount) / Double(rows))))
        guard columns > 0 else { return 0 }
        let side = (width - (columns - 1) * spacing) / columns
        return side * CGFloat(rows) + spacing * CGFloat(rows - 1)
    }

    override func draw(_ rect: CGRect) {
        guard !keys.isEmpty else { return }

        let columns = Int(ceil(Double(keys.count) / Double(rows)))
        guard columns > 0 else { return }

        let side = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        guard side > 0 else { return }

        // Empty days are a faint fill rather than nothing at all, so the grid
        // still reads as a calendar when the history is sparse.
        let emptyColor = UIColor.quaternarySystemFill

        for (index, key) in keys.enumerated() {
            let column = index / rows
            let row = index % rows
            let origin = CGPoint(x: CGFloat(column) * (side + spacing),
                                 y: CGFloat(row) * (side + spacing))
            let square = CGRect(origin: origin, size: CGSize(width: side, height: side))
            let path = UIBezierPath(roundedRect: square, cornerRadius: min(4, side / 4))

            let count = logs[key] ?? 0
            if count <= 0 {
                emptyColor.setFill()
            } else {
                // Four steps of intensity, so partial days are visible without
                // looking finished.
                let ratio = StreakCalculator.progress(count: count, target: target)
                let alpha: CGFloat = ratio >= 1 ? 1.0 : (ratio >= 0.66 ? 0.7 : (ratio >= 0.33 ? 0.45 : 0.25))
                tint.withAlphaComponent(alpha).setFill()
            }
            path.fill()
        }
    }
}
