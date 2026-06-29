# Kouvention

Kouvention is a Flutter mobile chat app focused on a local-first inbox and chat-room experience backed by Firebase and Drift. The current product shape is a single-account, single-channel personal chat app with stories, media messaging, offline-first behavior, and bounded sync rules designed to scale beyond small inbox sizes.

## What this repo contains

- Flutter app for iOS and Android
- Firebase-backed auth, chat, notifications, storage, and presence
- Drift-backed local cache for chat and story UI
- Riverpod + MVVM app structure
- Staging and production flavor support

## Core architecture

The chat stack is intentionally constrained:

- Drift is the local source of truth for visible UI state.
- Firestore is the remote source of truth, not a dataset the app scans.
- Login sync reads chat metadata only.
- Messages sync only when a chat is opened, receives a notification, or the user explicitly asks for more history.
- Message writes must be idempotent or transaction-guarded.

## Stack

- Flutter
- Firebase Auth, Firestore, Storage, Messaging, Crashlytics, Analytics
- Drift + SQLite (`sqlite3mc`)
- Riverpod
- GoRouter
- Envied

## Project structure

Main app areas:

- `lib/features/auth/` - sign in, sign up, onboarding
- `lib/features/chat/` - inbox, chat room, sync, local database, media
- `lib/features/story/` - story composer, feed, viewer, sync
- `lib/features/notification/` - foreground/background notification handling
- `lib/features/shared/` - shared services and cross-cutting app state
- `lib/cores/` - routing, config, theme, base classes, reusable widgets

## Environment setup

This app uses flavor-specific environment files and generated config:

- `.env.staging`
- `.env.prod`
- `lib/firebase_options.dart`
- platform Firebase config files as required by FlutterFire

Install dependencies:

```bash
flutter pub get
```

If generated files are missing or env models changed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Running the app

The app reads the flavor from `--dart-define=ENV=...`.

Staging:

```bash
flutter run --dart-define=ENV=staging
```

Production:

```bash
flutter run --dart-define=ENV=production
```