//
//  DemoUITests.swift
//  HabitPulseUITests
//

import XCTest

/// Drives the app through a scripted walkthrough while the simulator's screen
/// is being recorded, producing the demo video.
///
/// Every step is deliberately forgiving: `tap(_:)` and friends wait for an
/// element and simply move on if it never appears. A demo recording that is
/// missing one screen is far more useful than one that aborts halfway with a
/// test failure, and the app's own state (a habit that already exists from a
/// previous run, say) legitimately changes what is on screen.
final class DemoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    // MARK: Helpers

    /// Pause long enough for a viewer to read the screen.
    private func beat(_ seconds: TimeInterval = 1.4) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 8, pause: TimeInterval = 1.2) -> Bool {
        guard element.waitForExistence(timeout: timeout), element.isHittable else { return false }
        element.tap()
        beat(pause)
        return true
    }

    /// Types into a field slowly, so the text is readable while recording.
    private func type(_ text: String, into field: XCUIElement, timeout: TimeInterval = 8) {
        guard field.waitForExistence(timeout: timeout) else { return }
        field.tap()
        beat(0.4)
        for character in text {
            field.typeText(String(character))
            Thread.sleep(forTimeInterval: 0.06)
        }
        beat(0.8)
    }

    /// Firebase can surface a "Could not sign in" alert - most often on a
    /// fresh simulator where the keychain is not ready on the first attempt.
    /// Retry once, then dismiss, so a transient failure does not cost the
    /// entire walkthrough.
    private func clearSignInAlertIfPresent(retries: Int = 3) {
        for attempt in 0..<retries {
            let alert = app.alerts["Could not sign in"]
            guard alert.waitForExistence(timeout: attempt == 0 ? 6 : 3) else { return }

            if attempt < retries - 1, alert.buttons["Retry"].exists {
                alert.buttons["Retry"].tap()
                beat(3.5)   // give sign-in time to come back
            } else {
                if alert.buttons["Not now"].exists { alert.buttons["Not now"].tap() }
                beat(1.0)
                return
            }
        }
    }

    /// True once the app has a signed-in session, which is what makes the
    /// onboarding screen (or a working Today screen) appear.
    private func waitForSession(timeout: TimeInterval = 25) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            clearSignInAlertIfPresent()
            if app.textFields["Your name"].exists { return }
            if app.navigationBars.buttons["Add"].exists { return }
            beat(1.0)
        }
    }

    /// Dismiss whatever alert happens to be up. A modal left on screen
    /// makes every later tap a no-op, which would quietly truncate the
    /// recording rather than fail it.
    private func dismissAnyAlert() {
        let alert = app.alerts.firstMatch
        guard alert.exists else { return }
        for label in ["Done", "OK", "Cancel", "Not now"] {
            if alert.buttons[label].exists { alert.buttons[label].tap(); beat(1.0); return }
        }
        if alert.buttons.count > 0 { alert.buttons.element(boundBy: 0).tap(); beat(1.0) }
    }

    // MARK: The walkthrough

    func testDemoWalkthrough() throws {
        beat(3.0)
        waitForSession()

        onboardIfNeeded()
        clearSignInAlertIfPresent()
        addHabits()
        logCompletions()
        showHabitHistory()
        dismissAnyAlert()
        showChallenges()
        dismissAnyAlert()
        showProfileAndDarkMode()
        returnToTodayInDarkMode()

        beat(2.5)
    }

    // MARK: Steps

    /// First launch asks for a display name. On a re-run the profile already
    /// exists and this screen never appears, which is fine.
    private func onboardIfNeeded() {
        let nameField = app.textFields["Your name"]
        guard nameField.waitForExistence(timeout: 6) else { return }

        type("Afik", into: nameField)
        // Pick a livelier avatar than the default before continuing.
        tap(app.buttons["🔥"], timeout: 3, pause: 0.8)
        tap(app.buttons["Start tracking"])
        beat(2.0)
    }

    private func addHabits() {
        let habits = [
            (title: "Drink water",   emoji: "💧", colour: "Ocean",  extraTaps: 7),
            (title: "Morning run",   emoji: "🏃", colour: "Sunset", extraTaps: 0),
            (title: "Read 20 pages", emoji: "📚", colour: "Grape",  extraTaps: 0)
        ]

        for habit in habits {
            guard tap(app.navigationBars.buttons["Add"]) else { continue }

            let field = app.textFields["What do you want to do?"]
            type(habit.title, into: field)
            // Dismiss the keyboard so the colour picker and preview ring
            // are actually visible in the recording.
            field.typeText("\n")
            beat(0.6)
            tap(app.buttons[habit.colour], timeout: 3, pause: 0.7)
            tap(app.buttons[habit.emoji], timeout: 3, pause: 0.7)

            // Nudge the daily target up so the ring shows partial progress.
            if habit.extraTaps > 0 {
                let stepper = app.steppers.firstMatch
                if stepper.waitForExistence(timeout: 3) {
                    let increment = stepper.buttons.element(boundBy: 1)
                    for _ in 0..<habit.extraTaps where increment.exists {
                        increment.tap()
                        Thread.sleep(forTimeInterval: 0.12)
                    }
                }
                beat(0.8)
            }

            tap(app.buttons["Save"])
            beat(1.2)
        }
    }

    /// Tap the + on the rows so the rings fill and a habit completes.
    private func logCompletions() {
        beat(1.0)
        let addButtons = app.tables.buttons.matching(identifier: "Log one completion")

        // Fill the first habit part-way…
        for _ in 0..<4 where addButtons.element(boundBy: 0).exists {
            addButtons.element(boundBy: 0).tap()
            Thread.sleep(forTimeInterval: 0.55)
        }
        beat(1.0)

        // …and finish the second outright, so the completion bounce plays.
        if addButtons.element(boundBy: 1).exists {
            addButtons.element(boundBy: 1).tap()
            beat(1.8)
        }
    }

    private func showHabitHistory() {
        let firstRow = app.tables.cells.element(boundBy: 0)
        guard tap(firstRow, pause: 2.4) else { return }
        beat(4.5)   // hold on the heat-map and stat tiles - this is the
                    // screen that shows the history actually working
        tap(app.navigationBars.buttons.element(boundBy: 0), pause: 1.4)
    }

    private func showChallenges() {
        guard tap(app.tabBars.buttons["Challenges"], pause: 1.6) else { return }

        guard tap(app.navigationBars.buttons["Add"]) else { return }
        guard tap(app.buttons["Create a challenge"], timeout: 4) else { return }

        let alert = app.alerts.firstMatch
        guard alert.waitForExistence(timeout: 5) else { return }

        type("October Reset", into: alert.textFields.element(boundBy: 0))
        type("3", into: alert.textFields.element(boundBy: 1))
        type("14", into: alert.textFields.element(boundBy: 2))
        tap(alert.buttons["Create"], pause: 2.0)

        // The share sheet shows the join code — hold on it, it is the thing
        // another player would type in.
        beat(2.4)
        tap(app.alerts.buttons["Done"], timeout: 5, pause: 1.6)

        // Open the challenge to show the live leaderboard.
        // The live leaderboard is the centrepiece - hold it.
        tap(app.tables.cells.element(boundBy: 0), pause: 3.5)
        beat(4.5)
        tap(app.navigationBars.buttons.element(boundBy: 0), pause: 1.2)
    }

    private func showProfileAndDarkMode() {
        guard tap(app.tabBars.buttons["Profile"], pause: 2.0) else { return }
        beat(1.4)
        // The appearance control is the app overriding the system setting.
        tap(app.buttons["Dark"], timeout: 5, pause: 2.6)
        beat(1.6)
    }

    private func returnToTodayInDarkMode() {
        tap(app.tabBars.buttons["Today"], pause: 2.6)
        beat(2.0)
    }
}
