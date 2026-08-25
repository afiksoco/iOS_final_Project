# Firebase setup

The app runs without any of this — it shows a setup screen instead of
crashing — but nothing is stored until these steps are done. It takes about
five minutes.

## 1. Register the iOS app

In the [Firebase console](https://console.firebase.google.com), open your
project and add an iOS app.

**The bundle ID must be exactly:**

```
com.afik.HabitPulse
```

That is what `PRODUCT_BUNDLE_IDENTIFIER` is set to in the Xcode project. If you
would rather use a different one, change it in **both** places — Xcode target →
Signing & Capabilities → Bundle Identifier, and the Firebase console — or the
app will not be able to talk to your project.

## 2. Add GoogleService-Info.plist

Download `GoogleService-Info.plist` from the console and put it in the
`HabitPulse/` folder, right next to `Info.plist`:

```
HabitPulse/
├─ AppDelegate.swift
├─ Info.plist
└─ GoogleService-Info.plist   ← here
```

The Xcode project uses a file-system-synchronized folder, so the file is picked
up automatically — there is no "Add Files to…" step and no need to touch the
project settings.

> This file is not a secret. It holds a client API key that is meant to ship
> inside the app; what actually protects the data is the security rules in
> step 5. Committing it is what lets anyone clone the repo and run the app.

## 3. Turn on Anonymous authentication

**Authentication → Sign-in method → Anonymous → Enable.**

The app never asks for a password. It signs in anonymously on first launch,
which gives each device a stable UID that the security rules key off. The
display name the player picks is only cosmetic.

If this is not enabled, the app will show a "Could not sign in" alert.

## 4. Create both databases

The app genuinely uses both, for different jobs.

**Cloud Firestore** — *Firestore Database → Create database*.
Start in **production mode** (the rules in step 5 replace the defaults) and
pick any location.

**Realtime Database** — *Realtime Database → Create database*.
Also production mode. Note the region you choose; if it is not `us-central1`
the console gives you a URL like
`https://<project>-default-rtdb.europe-west1.firebasedatabase.app`. That URL is
already inside `GoogleService-Info.plist`, so there is nothing to configure —
just make sure you downloaded the plist **after** creating the database. If you
created the Realtime Database later, download the plist again and replace it.

## 5. Publish the security rules

Production mode denies everything by default, so the app will silently fail
until the rules are in place.

- **Firestore Database → Rules** → paste [`firestore.rules`](firestore.rules) → *Publish*
- **Realtime Database → Rules** → paste [`database.rules.json`](database.rules.json) → *Publish*

Both files are commented and explain what each rule is protecting.

## 6. Run it

Open `HabitPulse.xcodeproj`, wait for Swift Package Manager to fetch the
Firebase SDK the first time (a few minutes), pick an iPhone simulator, and
press ⌘R.

## Checking it worked

Add a habit and tap **+**, then look in the Firebase console:

- **Firestore** should have `users/{uid}` with a `habits` sub-collection and a
  `days/{today}` rollup document.
- **Realtime Database** should have a `presence/{uid}` node with
  `online: true`.

Create a challenge and the Realtime Database should also grow a
`standings/{challengeId}/{uid}` row.

## Demoing the live parts

The leaderboard and presence are the interesting bit, and they need two
clients. Run the app on **two simulators at once** (in Xcode, pick a different
simulator and press Run again — the first one keeps running), or on a simulator
and a physical device.

Each gets its own anonymous UID, so they behave as two different players.
Create a challenge on one, copy the join code, join with the other, then tick a
habit and watch the other device's leaderboard re-sort and the green online
dots appear.

## Troubleshooting

| What you see | What it usually means |
| --- | --- |
| The "One step left" setup screen | `GoogleService-Info.plist` is not in the `HabitPulse/` folder |
| "Could not sign in" | Anonymous auth is not enabled (step 3) |
| Habits never save, no error | Firestore rules were not published (step 5) |
| Leaderboard stays empty | Realtime Database rules were not published, or the database was created after the plist was downloaded |
| `No such module 'FirebaseCore'` | Package resolution has not finished — *File → Packages → Resolve Package Versions* |
