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
- 🔐 **Authentication** - Email/password with Supabase Auth
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
│   └── router.dart                # go_router with auth guards + shell nav
├── core/
│   └── utils/
│       └── auth_guard.dart        # Authentication helpers
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

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.22 or newer
- Dart 3.x
- A Supabase project (free tier works)

### 1. Clone & Install
```bash
git clone <your-repo-url>
cd ripple
flutter pub get
```

### 2. Configure Supabase
Update `lib/config/constants.dart` with your Supabase credentials:
```dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-anon-key';
```

### 3. Create Database Schema
Run these SQL migrations in your Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  bio TEXT DEFAULT '',
  avatar_url TEXT,
  website TEXT,
  email TEXT,
  phone_number TEXT,
  date_of_birth DATE,
  gender TEXT,
  followers_count INT DEFAULT 0,
  following_count INT DEFAULT 0,
  posts_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Posts table
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  caption TEXT,
  location TEXT,
  media JSONB NOT NULL DEFAULT '[]',
  post_type TEXT CHECK (post_type IN ('image', 'video', 'carousel')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reels table
CREATE TABLE reels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  caption TEXT,
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  music_title TEXT,
  music_artist TEXT,
  duration_seconds INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stories table
CREATE TABLE stories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  media_url TEXT,
  thumbnail_url TEXT,
  media_type TEXT CHECK (media_type IN ('image', 'video')),
  caption TEXT,
  background_color TEXT,
  elements JSONB DEFAULT '[]',
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Follows table
CREATE TABLE follows (
  follower_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id)
);

-- Likes tables
CREATE TABLE post_likes (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE reel_likes (
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (reel_id, user_id)
);

-- Comments tables
CREATE TABLE post_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE reel_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Saved posts
CREATE TABLE saved_posts (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id, reel_id)
);

-- Conversations & Messages
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE conversation_participants (
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT,
  media_url TEXT,
  media_type TEXT CHECK (media_type IN ('image', 'video')),
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video')),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT,
  body TEXT,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE reels ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE reel_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE reel_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies (customize as needed)
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Posts are viewable by everyone" ON posts FOR SELECT USING (true);
CREATE POLICY "Users can insert own posts" ON posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own posts" ON posts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own posts" ON posts FOR DELETE USING (auth.uid() = user_id);

-- Storage buckets (create in Supabase Dashboard)
-- avatars, posts, reels, stories
```

### 4. Create Storage Buckets
In Supabase Dashboard → Storage, create these buckets:
- `avatars` (public)
- `posts` (public)
- `reels` (public)
- `stories` (public)

### 5. Run the App
```bash
# Mobile
flutter run

# Web
flutter run -d chrome

# Desktop
flutter run -d macos  # or windows, linux
```

## 🎯 Key Implementation Details

### Authentication Flow
1. **Splash Screen** → Checks session → Routes to Feed or Login
2. **Login/Register** → Supabase Auth → Creates profile on signup
3. **Router Guards** → Protects routes + `AuthGuard` for in-app actions

### Bottom Navigation
- 5 tabs: Home, Explore, Create (center FAB), Messages, Profile
- `StatefulShellRoute.indexedStack` preserves tab state
- Center FAB opens create modal (Post, Reel, Story)

### Media Handling
- **Posts**: Up to 10 images/videos (carousel)
- **Reels**: Single video ≤ 90s with trim editor
- **Stories**: Photo/video ≤ 15s with text/drawing tools
- All uploads go to Supabase Storage with public URLs

### Real-time Features
- Messages: Supabase Realtime on `messages` table
- Feed/Reels: Could add streams for live updates (currently pull-to-refresh)

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