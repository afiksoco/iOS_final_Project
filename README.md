# HabitPulse — iOS Final Project

A habit tracker with live group challenges, built with **UIKit + Storyboard
(MVC)** for iPhone.

Track the things you want to do every day, then compete with friends: whoever
finishes the daily goal on the most days wins. The leaderboard is live — a
habit ticked on one phone re-sorts everyone else's board within a moment, and
you can see who is online while it happens.

> Course requirements: an iPhone app using **Firebase Realtime Database** and
> **Cloud Firestore**, with **dark mode** support. All three are covered below.

## Why the app uses both databases

This is the design decision the project is built around. The two Firebase
databases are not interchangeable, and each half of the app uses the one that
actually fits.

| | Cloud Firestore | Realtime Database |
| --- | --- | --- |
| **Holds** | profiles, habits, daily logs, challenge definitions | live standings, presence, cheers |
| **Why there** | it is data that gets **queried** — "the last 60 days of this habit", "every day in the challenge window" — which means range reads over documents | it is data that gets **pushed** — small values, changing constantly, that every device must see at once |
| **Key feature used** | compound queries, `WriteBatch`, `FieldValue.increment`, offline persistence | `onDisconnect`, `.info/connected`, `childAdded` streams |

The clearest example is **presence**. Firestore has no equivalent of
`onDisconnect` — a value the *server* writes when a client's socket drops.
Without it, someone who force-quits the app or walks into a tunnel stays
"online" forever. The Realtime Database provides exactly that, so presence
lives there even though every other fact about a player lives in Firestore.

`StandingsSync` is the bridge between the two: it reads the player's own daily
totals out of Firestore, scores them against each challenge's goal, and writes
a single row into the Realtime Database. Doing that on the client keeps the
security model simple — a player only ever reads their own habit data, and only
ever writes their own leaderboard row — and it needs no Cloud Functions, which
the free Firebase tier does not include.

## Screens

| Screen | What it does |
| --- | --- |
| **Today** | Every active habit with a progress ring; **+** logs a completion. Swipe to edit, undo, archive or delete. |
| **Habit detail** | Current streak, best streak, 30-day completion rate, and an eight-week heat-map. |
| **Challenges** | The challenges you have joined. Create one and share the six-character code, or join with a friend's. |
| **Challenge detail** | The live leaderboard: scores re-sort as they change, green dots show who is online, and cheers pop up as they are sent. |
| **Profile** | Display name and avatar, all-time stats, and the light/dark/system override. |

## Dark mode

Dark mode is handled in three layers, not just switched on:

1. **Dynamic system colours everywhere.** Every label, background and fill uses
   `.label`, `.secondaryLabel`, `.systemGroupedBackground`, `.quaternarySystemFill`
   and friends, so the whole app adapts with no code running.
2. **Custom colours that are also dynamic.** The six habit colours in
   `HabitPalette` are `UIColor(dynamicProvider:)` with hand-picked light *and*
   dark variants — a colour deep enough to read on white is usually too heavy
   on black, so each one is lifted and desaturated for dark mode.
3. **`CGColor` handled explicitly.** `ProgressRingView` draws with `CAShapeLayer`,
   and layer colours are `CGColor`, which does *not* follow the interface style
   on its own. It re-resolves them in `traitCollectionDidChange`. `HeatmapView`
   deliberately draws in `draw(_:)` with `UIColor` instead, where UIKit redraws
   it automatically — the two approaches are there to show the difference.

On top of that, **Profile → Appearance** overrides the system setting from
inside the app (`ThemeManager`), so both looks can be shown without leaving for
Settings.

## Project structure

```
HabitPulse/
├─ AppDelegate.swift / SceneDelegate.swift
├─ Models/        Habit, HabitLog, DaySummary, Challenge, StandingEntry,
│                 UserProfile, CalendarDay, StreakCalculator   (pure logic)
├─ Services/      FirebaseService, AuthService, HabitStore, ChallengeStore,
│                 LiveStandingsService, PresenceService, StandingsSync,
│                 ThemeManager
├─ Views/         ProgressRingView, HeatmapView, HabitPalette, StatTile,
│                 HabitCell, ChallengeCell, StandingCell, EmptyStateView
├─ Controllers/   RootTabBar, Today, HabitDetail, HabitEditor,
│                 Challenges, ChallengeDetail, Profile, Onboarding, Setup
└─ Base.lproj/    Main.storyboard, LaunchScreen.storyboard
```

`StreakCalculator` is deliberately free of both UIKit and Firebase. Every
number the app shows — a streak, a completion rate, a challenge score — comes
out of it, and it takes the same input shape in every case (`day → count`, plus
a target), so one set of functions serves both a single habit's history and a
challenge's daily totals.

## Data model

**Cloud Firestore**

```
users/{uid}                          profile: display name, avatar
  ├─ habits/{habitId}                title, emoji, colour, target per day
  │    └─ logs/{yyyy-MM-dd}          that habit's history   → heat-map
  └─ days/{yyyy-MM-dd}               rollup across habits    → Today + scoring

challenges/{challengeId}             title, goal, dates, join code, members
```

The day rollup is a deliberate denormalisation. The Today screen needs every
habit's count for today at once, and a challenge needs daily totals across a
date range; reading those from the per-habit logs would mean one listener per
habit and a collection-group query per challenge. Both copies are written in
the same `WriteBatch`, so they cannot drift.

**Realtime Database**

```
presence/{uid}                       online, displayName, lastSeen
standings/{challengeId}/{uid}        points, todayCount, streak, displayName
cheers/{challengeId}/{cheerId}       fromName, emoji, at
```

## Running it

1. Follow **[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)** — register the
   app as `com.afik.HabitPulse`, add `GoogleService-Info.plist`, enable
   anonymous auth, create both databases, publish the rules.
2. Open `HabitPulse.xcodeproj` and let Swift Package Manager fetch the Firebase
   SDK on first open.
3. Pick an iPhone simulator and press ⌘R.

Without the plist the app still builds and runs — it shows a setup screen
explaining what is missing rather than crashing.

To see the live features, run it on **two simulators at once** so there are two
players; the setup guide has the details.

## Notes on the implementation

- **Listeners are scoped to the screen.** Every screen attaches its Firestore
  and Realtime Database listeners in `viewWillAppear` and tears them down in
  `viewDidDisappear`, so the app never holds a live connection for a screen
  nobody is looking at.
- **Writes are optimistic.** Tapping **+** animates the ring straight away
  rather than waiting for Firestore to echo the write back; the listener
  confirms the same number a moment later.
- **Counts use `FieldValue.increment`,** so two quick taps can never overwrite
  each other.
- **Queries avoid composite indexes.** Every query filters on a single field
  and sorts client-side, so the project works on a fresh Firebase project with
  no index configuration.
- **A streak breaks only after a whole missed day.** If today's goal has not
  been met *yet*, the streak is measured to yesterday rather than reset to
  zero.
