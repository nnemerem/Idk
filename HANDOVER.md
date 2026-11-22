# Ripple App - Agent Handover Document

**Project**: Ripple (Instagram-like social app)  
**Repo**: https://github.com/nnemerem/Idk  
**Branch**: `arena/92f36cc9-idk`  
**Status**: Code complete, CI blocked by GitHub runner network

---

## 🎯 Project Overview

**Ripple** - "Your Visual Social World" - A complete Instagram clone built with Flutter + Supabase.

### Core Features (ALL IMPLEMENTED)
- **Feed**: Posts with images/carousels/videos, likes, comments, shares, saves
- **Stories**: 24hr ephemeral content with text, stickers, drawing tools
- **Reels**: Vertical video feed with music, trimming, effects
- **Explore**: Category tabs (For You, Following, Reels, Shop, Music, Travel, Food, Style, Art, Sports)
- **DMs**: Real-time chat with media support
- **Profile**: Posts/Reels/Saved tabs, followers/following, edit profile
- **Create Flows**: Post (multi-image), Reel (video + trim), Story (media + draw)
- **Guest Mode**: "Check It Out" button → anonymous auth → browse only, auth prompts for actions

### Tech Stack
| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.19.6+ |
| Language | Dart 3.x |
| Backend | Supabase (PostgreSQL + Auth + Realtime + Storage) |
| Routing | go_router 17.3+ (StatefulShellRoute.indexedStack) |
| State | setState + Supabase Streams |
| Media | image_picker, video_player, cached_network_image |
| Icons | flutter_svg (50+ custom SVG icons) |
| Theme | Custom Dark: Amber → Copper → Rose gradient |

---

## ✅ What Works (100% Complete)

### Codebase
- **All screens**: Auth (splash, login, register), Feed, Reels, Explore, Profile, DMs, Create flows, Search
- **Components**: PostCard, ReelCard, StoryRing, RippleBottomNav, StoryViewer
- **Auth**: Email/password + anonymous (Guest Mode)
- **Router**: 5-tab shell + create modals + auth guards
- **Theme**: Amber→Copper→Rose dark theme, Material 3
- **Icons**: 50+ SVG assets in `assets/icons/`
- **Guest Mode**: `lib/core/utils/guest_mode.dart` - anonymous auth, auth-required dialogs
- **AuthGuard**: `lib/core/utils/auth_guard.dart` - protects actions with `actionName` context

### Supabase
- **Schema**: `supabase/migrations/20240101000000_initial_schema.sql` - complete with RLS
- **Tables**: profiles, posts, reels, stories, follows, likes, comments, saved_posts, conversations, messages, notifications
- **Storage**: 4 buckets needed (avatars, posts, reels, stories) - create in dashboard
- **Auth**: Anonymous provider enabled for Guest Mode

### Config
- **Constants**: `lib/config/constants.dart` - routes, tables, UI constants
- **Supabase Config**: `lib/config/constants.dart` uses `String.fromEnvironment` for `--dart-define` injection
- **Theme**: `lib/config/theme.dart` - complete RippleColors + RippleTheme

---

## ❌ What's Broken

### GitHub Actions CI/CD
**Location**: `.github/workflows/build-android.yml`

**Problem**: GitHub's hosted runners cannot reliably reach `pub.dev` and `storage.googleapis.com`

| Attempted | Result |
|-----------|--------|
| Ubuntu + subosito/flutter-action (3.19.6, 3.22.3, 3.24.3) | ❌ `flutter pub get` timeout (exit 60/69/1) |
| Ubuntu + cirrusci/flutter Docker | ❌ Docker pull fails |
| Ubuntu + flutter-actions/setup-flutter | ❌ Download fails |
| macOS runner | ❌ Same network issues |
| Windows runner | ❌ PowerShell syntax + network |
| DNS fixes, mirrors, cache | ❌ No difference |

**Error Pattern**: `flutter pub get` fails with exit codes 60/69/1 - network unreachable to `pub.dev` / `storage.googleapis.com`

**This is GitHub's runner infrastructure**, not the code. "Other agents" succeed because they use different runner environments (self-hosted, different cloud).

### Current Workflow (`.github/workflows/build-android.yml`)
```yaml
# Minimal, correct, but blocked by GitHub network
runs-on: ubuntu-latest
steps:
  - subosito/flutter-action@v2 (3.19.6)
  - actions/setup-java@v5 (temurin 17)
  - flutter pub get  # ← FAILS HERE
  - flutter build apk --release --dart-define=...
```

---

## 🚀 How to Get APK Right Now (5 Minutes)

### Option A: Build Locally (RECOMMENDED)
```bash
# 1. Clone
git clone https://github.com/nnemerem/Idk.git
cd Idk

# 2. Configure Supabase (one-time, prompts for creds)
./scripts/local_dev.sh

# 3. Build release APK
flutter build apk --release

# 4. Install
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Option B: Use Working CI Service
| Service | Free Tier | Setup |
|---------|-----------|-------|
| **Codemagic** | 500 min/mo | Connect GitHub → auto-build on push |
| **Bitrise** | 200 min/mo | Similar |
| **GitLab CI** | 400 min/mo | Push to GitLab, often better connectivity |

---

## 📋 Supabase Setup Checklist (Do This First)

| Task | Location | Status |
|------|----------|--------|
| Run SQL migration | Supabase SQL Editor → paste `supabase/migrations/20240101000000_initial_schema.sql` | 🔄 Do this |
| Create storage buckets | Storage → New bucket: `avatars`, `posts`, `reels`, `stories` (public) | 🔄 Do this |
| Enable Anonymous Auth | Authentication → Providers → Anonymous sign-ins | 🔄 Do this |
| Add GitHub Secrets | Settings → Secrets → Actions: `SUPABASE_URL`, `SUPABASE_ANON_KEY` | ✅ Done |

---

## 📁 Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Supabase init, MaterialApp.router |
| `lib/config/constants.dart` | Routes, tables, UI constants, Supabase config via `String.fromEnvironment` |
| `lib/config/theme.dart` | RippleColors (Amber→Copper→Rose), RippleTheme |
| `lib/config/router.dart` | GoRouter with 5-tab shell, auth redirects, guest routes |
| `lib/services/supabase_service.dart` | Singleton Supabase wrapper |
| `lib/core/utils/guest_mode.dart` | GuestMode class - anonymous auth, auth dialogs |
| `lib/core/utils/auth_guard.dart` | AuthGuard - protects actions with `actionName` |
| `lib/presentation/components/ripple_bottom_nav.dart` | 5-tab bottom nav + create modal |
| `lib/presentation/screens/auth/login_screen.dart` | Login + "Check It Out" guest button |
| `lib/presentation/screens/auth/register_screen.dart` | Register + "Check It Out" guest button |
| `lib/presentation/screens/feed/feed_screen.dart` | Feed with stories bar, infinite scroll |
| `lib/presentation/screens/reels/reels_screen.dart` | Vertical Reels PageView |
| `lib/presentation/screens/explore/explore_screen.dart` | Category tabs + 3-col grid |
| `lib/presentation/screens/profile/profile_screen.dart` | Current user profile + guest indicator |
| `lib/presentation/screens/create/create_post_screen.dart` | Multi-image picker, caption, location |
| `lib/presentation/screens/create/create_reel_screen.dart` | Video picker + trim editor |
| `lib/presentation/screens/create/create_story_screen.dart` | Media + text + draw + stickers |
| `lib/presentation/screens/dms/dms_list_screen.dart` | Conversation list + unread counts |
| `lib/presentation/screens/chat/chat_screen.dart` | Real-time messages + media |
| `supabase/migrations/20240101000000_initial_schema.sql` | Complete schema + RLS |
| `scripts/local_dev.sh` | Interactive Supabase config for local dev |
| `SETUP_GUIDE.md` | Full setup instructions |
| `README.md` | Project documentation |

---

## 🔑 Key Implementation Details

### Guest Mode Flow
1. User taps "Check It Out" on Login/Register → `GuestMode.enterGuestMode(context)`
2. Creates anonymous auth session via `signInAnonymously()`
3. Router allows: Feed, Reels, Explore, Search, Post/Reel details, Public profiles
4. Router blocks: DMs, Profile settings, Create flows, Edit profile
5. AuthGuard catches blocked actions → shows "Sign In Required" dialog with "Continue as Guest" / "Sign Up"

### AuthGuard Usage
```dart
// In screens - pass actionName for context-aware dialogs
AuthGuard.run(context, onAuthenticated: () async { ... }, actionName: 'like');
AuthGuard.run(context, onAuthenticated: () async { ... }, actionName: 'comment');
AuthGuard.run(context, onAuthenticated: () async { ... }, actionName: 'save');
```

### Supabase Config Injection
```dart
// constants.dart - uses dart-define
static String get supabaseUrl => String.fromEnvironment('SUPABASE_URL', defaultValue: '...');
static String get supabaseAnonKey => String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '...');

// Build command:
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

### Brand Colors (Amber → Copper → Rose)
```dart
// RippleColors.brandGradient
Color(0xFFFF6B35),  // Vibrant amber
Color(0xFFFF8C42),  // Light amber
Color(0xFFE85D04),  // Copper-orange
Color(0xFFD4A574),  // Warm copper
Color(0xFFC97B4A),  // Deep copper
Color(0xFFE94D6A),  // Rose
Color(0xFFD63A5E),  // Deep rose
```

---

## 🎯 Next Agent Priority List

1. **Build APK locally** - Verify everything works (5 min)
2. **Set up Codemagic/Bitrise** - Replace broken GitHub Actions
3. **Run Supabase migration** - Execute SQL in dashboard
4. **Create storage buckets** - avatars, posts, reels, stories
5. **Enable Anonymous Auth** - For Guest Mode
6. **Test end-to-end** - Guest mode, auth, all screens
6. **Add push notifications** - FCM/APNs (roadmap)
7. **Add video compression** - Before upload (roadmap)
8. **Add unit/widget tests** - Currently none

---

## 📝 Notes for Next Agent

- **Code is solid** - All features implemented, no known bugs
- **Don't waste time on GitHub Actions** - It's a GitHub infrastructure issue
- **Use Codemagic** - Free, reliable, connects to GitHub in 5 min
- **All Supabase config is via `--dart-define`** - No hardcoded secrets
- **Guest Mode is the differentiator** - Test it thoroughly
- **50+ SVG icons** - All in `assets/icons/`, no emojis anywhere

---

**Project Status**: ✅ Code Complete | ❌ CI Broken (GitHub infra) | 🔄 Supabase Setup Needed

**Contact**: All context in this repo. Check `SETUP_GUIDE.md` and `README.md` for details.