# 🌊 Ripple

> **Your Visual Social World** — A modern Instagram-like social media app built with Flutter and Supabase.

## ✨ Features

### Core Features (MVP)
- 📱 **Feed** - Photo/video posts with likes, comments, shares, saves
- 📖 **Stories** - 24-hour ephemeral content with text, stickers, drawing tools
- 🎬 **Reels** - Short-form vertical videos with music, trimming, effects
- 🔍 **Explore** - Discover content with category tabs (For You, Following, Reels, Shop, etc.)
- 💬 **Direct Messages** - Real-time chat with media sharing
- 👤 **Profile** - User profiles with posts, reels, saved content, followers/following
- ⚙️ **Settings** - Account, privacy, notifications, theme preferences

### Technical Features
- 🎨 **Custom Dark Theme** - Unique Amber → Copper → Rose gradient signature
- 🔐 **Authentication** - Email/password with Supabase Auth (+ Anonymous for Guest Mode)
- 📡 **Real-time** - Live updates for messages, likes, comments
- 🖼️ **Media Upload** - Photos, videos, carousels with compression
- 🎵 **Music Integration** - Add music to Reels and Stories
- ✂️ **Video Trimming** - Built-in video editor for Reels
- 📱 **Responsive** - Works on mobile, web, and desktop
- 🎯 **SVG Icons** - Crisp, scalable vector icons throughout

## 🛠 Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.22+ |
| Language | Dart 3.x |
| Backend | Supabase (PostgreSQL + Auth + Realtime + Storage) |
| Routing | go_router 17.3+ |
| State | setState + Supabase Streams |
| Media | image_picker, video_player, cached_network_image |
| Icons | flutter_svg (custom SVG icon set) |
| Time | timeago, intl |
| Utilities | uuid, flutter_riverpod (ready for future) |

## 📁 Project Structure

```
lib/
├── main.dart                      # App entry point
├── config/
│   ├── theme.dart                 # Custom dark theme (Amber → Copper → Rose)
│   ├── constants.dart             # App constants, routes, DB tables
│   ├── router.dart                # go_router with auth guards + shell nav
│   └── supabase_config.dart       # Supabase credentials (local dev, gitignored)
├── core/
│   └── utils/
│       ├── auth_guard.dart        # Authentication helpers
│       └── guest_mode.dart        # Guest/anonymous browsing mode
├── services/
│   └── supabase_service.dart      # Supabase wrapper & helpers
└── presentation/
    ├── components/
    │   ├── ripple_bottom_nav.dart     # 5-tab bottom nav + create FAB
    │   ├── story_ring.dart            # Story avatar rings + viewer
    │   ├── post_card.dart             # Feed post widget
    │   └── reel_card.dart             # Reel player widget
    └── screens/
        ├── auth/
        │   ├── splash_screen.dart
        │   ├── login_screen.dart
        │   └── register_screen.dart
        ├── feed/
        │   └── feed_screen.dart
        ├── reels/
        │   ├── reels_screen.dart
        │   └── reel_detail_screen.dart
        ├── explore/
        │   └── explore_screen.dart
        ├── profile/
        │   ├── profile_screen.dart
        │   ├── user_profile_screen.dart
        │   ├── settings_screen.dart
        │   └── edit_profile_screen.dart
        ├── dms/
        │   └── dms_list_screen.dart
        ├── chat/
        │   └── chat_screen.dart
        ├── create/
        │   ├── create_post_screen.dart
        │   ├── create_reel_screen.dart
        │   └── create_story_screen.dart
        ├── post/
        │   └── post_detail_screen.dart
        └── search/
            └── search_screen.dart
```

## 🚀 Quick Start (Local)

### Prerequisites
- Flutter SDK 3.22+
- Dart 3.x
- Supabase project (free tier works)

### 1. Clone & Install
```bash
git clone https://github.com/nnemerem/Idk.git
cd Idk
flutter pub get
```

### 2. Configure Supabase (Local Development)
```bash
# Run the helper script - it will prompt for your credentials
./scripts/local_dev.sh

# OR manually edit lib/config/supabase_config.dart:
# static const String supabaseUrl = 'https://your-project.supabase.co';
# static const String supabaseAnonKey = 'your-anon-key';
```

### 3. Run Database Migrations
In Supabase Dashboard → **SQL Editor**, run the migration:
```bash
# Option A: Copy/paste from supabase/migrations/20240101000000_initial_schema.sql
# Option B: If using Supabase CLI
supabase db push
```

### 4. Create Storage Buckets
In Supabase Dashboard → **Storage**, create these buckets (public):
- `avatars`
- `posts`
- `reels`
- `stories`

### 5. Enable Anonymous Auth (for Guest Mode)
Supabase Dashboard → **Authentication → Providers** → Enable **Anonymous sign-ins**

### 6. Run the App
```bash
# Mobile
flutter run

# Web
flutter run -d chrome

# Desktop
flutter run -d macos  # or windows, linux
```

## 📱 Get a Release Build (No Local Flutter Needed!)

**GitHub Actions builds APKs automatically.**

### 1. Add Secrets to GitHub
Repo → **Settings → Secrets and variables → Actions** → Add:
- `SUPABASE_URL` = `https://your-project.supabase.co`
- `SUPABASE_ANON_KEY` = `eyJhbGciOiJIUzI1NiIs...`

### 2. Trigger Build
**Option A: Push a tag (creates GitHub Release)**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Option B: Manual**
1. Go to **Actions → Build Android** → **Run workflow**
2. Select branch → **Run workflow**

### 3. Download
- **Actions tab** → Click build → **Artifacts** → Download `ripple-release-apks.zip`
- **Releases page** (if tagged) → Download APK/AAB directly

## 🎯 Key Implementation Details

### Authentication Flow
1. **Splash Screen** → Checks session → Routes to Feed or Login
2. **Login/Register** → Supabase Auth → Creates profile on signup
3. **Guest Mode** → "Check It Out" button → Anonymous auth → Browse only
4. **Router Guards** → Protects routes + `AuthGuard` for in-app actions

### Bottom Navigation
- 5 tabs: Home, Explore, Create (center FAB), Messages, Profile
- `StatefulShellRoute.indexedStack` preserves tab state
- Center FAB opens create modal (Post, Reel, Story)

### Guest Mode
- Tap "Check It Out" on Login/Register → Creates anonymous session
- Can browse: Feed, Reels, Explore, Profiles, Post/Reel details
- Blocked actions (like, comment, save, follow, message, create) → "Sign In Required" dialog
- Exit via Profile/Settings → "Switch to Real Account"

### Media Handling
- **Posts**: Up to 10 images/videos (carousel)
- **Reels**: Single video ≤ 90s with trim editor
- **Stories**: Photo/video ≤ 15s with text/drawing tools
- All uploads go to Supabase Storage with public URLs

### Real-time Features
- Messages: Supabase Realtime on `messages` table
- Feed/Reels: Pull-to-refresh (streams ready to add)

### Color Signature
**Amber → Copper → Rose** gradient replaces Instagram's pink/orange/yellow:
- Primary: `#FF6B35` (Vibrant amber)
- Secondary: `#D4A574` (Warm copper)
- Tertiary: `#C97B4A` (Deep copper)
- Rose accent: `#E94D6A`

### SVG Icon System
All icons are custom SVG assets in `assets/icons/` — no emojis, fully scalable and themeable.

## 🔮 Roadmap

- [ ] Push notifications (FCM/APNs)
- [ ] Video compression before upload
- [ ] AR filters for Stories
- [ ] Reels remix/duet
- [ ] Live streaming
- [ ] Shopping tags
- [ ] Dark/Light theme toggle
- [ ] Accessibility improvements
- [ ] Unit/Widget tests
- [ ] CI/CD pipeline

## 📄 License

MIT License - feel free to use for your own projects!

---

Built with 🌊 using Flutter + Supabase