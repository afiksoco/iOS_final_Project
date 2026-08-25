//
//  HabitEditorViewController.swift
//  HabitPulse
//

import UIKit

/// Create-or-edit sheet for a habit.
///
/// The same screen serves both cases: passing a habit fills the fields in and
/// saves over it, passing `nil` starts a blank one. It is built in code and
/// presented modally, so it needs no storyboard scene of its own.
final class HabitEditorViewController: UIViewController {

    private let existingHabit: Habit?

    private let titleField = UITextField()
    private let emojiPicker = UISegmentedControl(items: HabitEditorViewController.emojiChoices)
    private let colorPicker = UISegmentedControl(items: HabitPalette.allKeys.map { HabitPalette.name(for: $0) })
    private let targetStepper = UIStepper()
    private let targetLabel = UILabel()
    private let previewRing = ProgressRingView()

    private static let emojiChoices = ["💧", "🏃", "📚", "🧘", "🥗", "😴"]

    init(habit: Habit?) {
        self.existingHabit = habit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.existingHabit = nil
        super.init(coder: coder)
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingHabit == nil ? "New habit" : "Edit habit"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
                                                            target: self,
                                                            action: #selector(saveTapped))

        setupViews()
        loadExistingValues()
        refreshPreview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if existingHabit == nil { titleField.becomeFirstResponder() }
    }

    // MARK: Setup

    private func setupViews() {
        titleField.placeholder = "What do you want to do?"
        titleField.borderStyle = .roundedRect
        titleField.font = .systemFont(ofSize: 18)
        titleField.autocapitalizationType = .sentences
        titleField.returnKeyType = .done
        titleField.delegate = self
        titleField.addTarget(self, action: #selector(valueChanged), for: .editingChanged)

        emojiPicker.selectedSegmentIndex = 0
        emojiPicker.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 20)], for: .normal)
        emojiPicker.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

        colorPicker.selectedSegmentIndex = 0
        colorPicker.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12, weight: .semibold)], for: .normal)
        colorPicker.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

        targetStepper.minimumValue = 1
        targetStepper.maximumValue = 20
        targetStepper.value = 1
        targetStepper.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

        targetLabel.font = .systemFont(ofSize: 16)
        targetLabel.textColor = .label

        previewRing.lineWidth = 9
        previewRing.translatesAutoresizingMaskIntoConstraints = false

        // A wrapper keeps the fixed-size ring from being stretched to
        // the full width by the stack view's .fill alignment.
        let ringWrapper = UIView()
        ringWrapper.addSubview(previewRing)

        let targetRow = UIStackView(arrangedSubviews: [targetLabel, UIView(), targetStepper])
        targetRow.axis = .horizontal
        targetRow.alignment = .center
        targetRow.spacing = 12

        let stack = UIStackView(arrangedSubviews: [
            sectionLabel("NAME"), titleField,
            sectionLabel("ICON"), emojiPicker,
            sectionLabel("COLOUR"), colorPicker,
            sectionLabel("TIMES PER DAY"), targetRow,
            ringWrapper
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(22, after: titleField)
        stack.setCustomSpacing(22, after: emojiPicker)
        stack.setCustomSpacing(22, after: colorPicker)
        stack.setCustomSpacing(30, after: targetRow)
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            titleField.heightAnchor.constraint(equalToConstant: 48),
            emojiPicker.heightAnchor.constraint(equalToConstant: 40),
            colorPicker.heightAnchor.constraint(equalToConstant: 36),
            ringWrapper.heightAnchor.constraint(equalToConstant: 88),
            previewRing.heightAnchor.constraint(equalToConstant: 88),
            previewRing.widthAnchor.constraint(equalToConstant: 88),
            previewRing.centerXAnchor.constraint(equalTo: ringWrapper.centerXAnchor),
            previewRing.centerYAnchor.constraint(equalTo: ringWrapper.centerYAnchor)
        ])

    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private func loadExistingValues() {
        guard let habit = existingHabit else { return }
        titleField.text = habit.title
        targetStepper.value = Double(habit.targetPerDay)

        if let emojiIndex = Self.emojiChoices.firstIndex(of: habit.emoji) {
            emojiPicker.selectedSegmentIndex = emojiIndex
        }
        if let colorIndex = HabitPalette.allKeys.firstIndex(of: habit.colorKey) {
            colorPicker.selectedSegmentIndex = colorIndex
        }
    }

    // MARK: State

    private var selectedEmoji: String {
        let index = max(0, emojiPicker.selectedSegmentIndex)
        return Self.emojiChoices[min(index, Self.emojiChoices.count - 1)]
    }

    private var selectedColorKey: String {
        let keys = HabitPalette.allKeys
        let index = max(0, colorPicker.selectedSegmentIndex)
        return keys[min(index, keys.count - 1)]
    }

    private var target: Int { Int(targetStepper.value) }

    @objc private func valueChanged() {
        refreshPreview()
    }

    /// Shows what the row on the Today screen will look like.
    private func refreshPreview() {
        let color = HabitPalette.color(for: selectedColorKey)
        targetLabel.text = target == 1 ? "Once a day" : "\(target) times a day"
        previewRing.ringColor = color
        previewRing.setCenterText("\(selectedEmoji)", color: color)
        previewRing.setProgress(0.66, animated: true)
        navigationItem.rightBarButtonItem?.isEnabled = !trimmedTitle.isEmpty
    }

    private var trimmedTitle: String {
        (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let title = trimmedTitle
        guard !title.isEmpty else { return }

        if var habit = existingHabit {
            habit.title = title
            habit.emoji = selectedEmoji
            habit.colorKey = selectedColorKey
            habit.targetPerDay = target
            HabitStore.shared.updateHabit(habit)
        } else {
            HabitStore.shared.createHabit(title: title,
                                          emoji: selectedEmoji,
                                          colorKey: selectedColorKey,
                                          targetPerDay: target)
        }
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension HabitEditorViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
