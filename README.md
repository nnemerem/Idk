# Ripple

> Your Visual Social World — an Instagram-like social app built with Flutter and Supabase.

## Features

- Feed — photo/video/carousel posts with likes, comments, saves, shares
- Stories — 24-hour ephemeral content (photo/video + text) with a full-screen viewer
- Reels — short-form vertical video with likes, comments, saves, shares
- Explore — category tabs and grid view of posts
- Search — users and posts
- Profiles — posts/reels/saved tabs, followers/following, edit profile
- DMs — 1:1 conversations with media
- Notifications — activity feed (likes, comments, follows)
- Guest mode — browse as an anonymous session, no account required
- Create flows — post (multi-image), reel (video + trim), story (photo/video)

## Tech Stack

- Flutter 3.22+ / Dart 3.x
- Supabase (Postgres + Auth + Realtime + Storage)
- go_router (StatefulShellRoute)
- flutter_svg icons, cached_network_image, video_player, timeago

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── config/
│   ├── theme.dart               # Dark theme (Amber → Copper → Rose)
│   ├── constants.dart           # Constants, routes, DB tables
│   └── router.dart              # go_router + auth guards + tab shell
├── core/
│   └── utils/
│       ├── auth_guard.dart      # Action-level auth guard
│       └── guest_mode.dart      # Guest (anonymous) browsing
├── services/
│   ├── supabase_service.dart    # Supabase client wrapper & helpers
│   └── conversation_service.dart# 1:1 conversation find/create
└── presentation/
    ├── components/
    │   ├── ripple_bottom_nav.dart
    │   ├── story_ring.dart
    │   ├── post_card.dart
    │   └── reel_card.dart
    └── screens/
        ├── auth/ (splash, login, register)
        ├── feed/
        ├── reels/
        ├── explore/
        ├── notifications/
        ├── search/
        ├── profile/ (profile, user_profile, settings, edit_profile)
        ├── dms/ (dms list)
        ├── chat/
        ├── create/ (post, reel, story)
        └── post/ (post detail)
```

## Getting Started

### Prerequisites
- Flutter SDK 3.22+
- Dart 3.x
- Supabase project

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Configure Supabase
Pass credentials at build time with `--dart-define` (both are injected as
build-time defines — no secret files live in the repo):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```
Or use the helper script, which prompts for both values:
```bash
./scripts/local_dev.sh
```

### 3. Apply the database schema
In the Supabase dashboard → SQL Editor, run `supabase/migrations/20240101000000_initial_schema.sql`.
Then create the public storage buckets it describes: `avatars`, `posts`, `reels`, `stories`.

### 4. Enable anonymous auth
Supabase dashboard → Authentication → Providers → enable **Anonymous sign-ins**
(required for guest mode).

### 5. Run
```bash
flutter run -d chrome    # web
flutter run              # connected device
flutter run -d macos     # macOS
```

## Platforms

| Platform | Status |
|----------|--------|
| Android  | Full (minSdk 24, targetSdk set) |
| iOS      | Full |
| Web      | Full (manifest + icons included) |
| Windows  | Full (CMake + Runner) |
| Linux    | Full (CMake + runner/my_application.cc) |
| macOS    | Full (xcodeproj + xcscheme) |

Android release signing is read from `android/key/` (gitignored) or CI secrets —
never committed to the repo. See `android/app/build.gradle.kts`.

## License

MIT
