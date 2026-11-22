-- Ripple Database Schema
-- Run this in Supabase SQL Editor (or use Supabase CLI: supabase db push)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES
-- ============================================
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

-- Index for username lookups
CREATE INDEX idx_profiles_username ON profiles(username);

-- ============================================
-- POSTS
-- ============================================
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

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

-- ============================================
-- REELS
-- ============================================
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

CREATE INDEX idx_reels_user_id ON reels(user_id);
CREATE INDEX idx_reels_created_at ON reels(created_at DESC);

-- ============================================
-- STORIES
-- ============================================
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

CREATE INDEX idx_stories_user_id ON stories(user_id);
CREATE INDEX idx_stories_expires_at ON stories(expires_at);

-- ============================================
-- FOLLOWS
-- ============================================
CREATE TABLE follows (
  follower_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id)
);

CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

-- ============================================
-- LIKES
-- ============================================
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

-- ============================================
-- COMMENTS
-- ============================================
CREATE TABLE post_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX idx_post_comments_created_at ON post_comments(created_at);

CREATE TABLE reel_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reel_comments_reel_id ON reel_comments(reel_id);
CREATE INDEX idx_reel_comments_created_at ON reel_comments(created_at);

-- ============================================
-- SAVED POSTS
-- ============================================
CREATE TABLE saved_posts (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id, reel_id)
);

-- ============================================
-- CONVERSATIONS & MESSAGES (DMs)
-- ============================================
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

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);

-- ============================================
-- NOTIFICATIONS
-- ============================================
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

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================
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

-- ============================================
-- RLS POLICIES
-- ============================================

-- Profiles: public read, own write
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Posts: public read, own write
CREATE POLICY "Posts are viewable by everyone" ON posts FOR SELECT USING (true);
CREATE POLICY "Users can insert own posts" ON posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own posts" ON posts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own posts" ON posts FOR DELETE USING (auth.uid() = user_id);

-- Reels: public read, own write
CREATE POLICY "Reels are viewable by everyone" ON reels FOR SELECT USING (true);
CREATE POLICY "Users can insert own reels" ON reels FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reels" ON reels FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reels" ON reels FOR DELETE USING (auth.uid() = user_id);

-- Stories: public read (non-expired), own write
CREATE POLICY "Stories are viewable by everyone" ON stories FOR SELECT USING (expires_at > NOW());
CREATE POLICY "Users can insert own stories" ON stories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own stories" ON stories FOR DELETE USING (auth.uid() = user_id);

-- Follows: public read, own write
CREATE POLICY "Follows are viewable by everyone" ON follows FOR SELECT USING (true);
CREATE POLICY "Users can follow" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow" ON follows FOR DELETE USING (auth.uid() = follower_id);

-- Likes: public read, own write
CREATE POLICY "Post likes viewable by everyone" ON post_likes FOR SELECT USING (true);
CREATE POLICY "Users can like posts" ON post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike posts" ON post_likes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Reel likes viewable by everyone" ON reel_likes FOR SELECT USING (true);
CREATE POLICY "Users can like reels" ON reel_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike reels" ON reel_likes FOR DELETE USING (auth.uid() = user_id);

-- Comments: public read, own write
CREATE POLICY "Post comments viewable by everyone" ON post_comments FOR SELECT USING (true);
CREATE POLICY "Users can comment on posts" ON post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own comments" ON post_comments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments" ON post_comments FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Reel comments viewable by everyone" ON reel_comments FOR SELECT USING (true);
CREATE POLICY "Users can comment on reels" ON reel_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reel comments" ON reel_comments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reel comments" ON reel_comments FOR DELETE USING (auth.uid() = user_id);

-- Saved posts: own read/write
CREATE POLICY "Users can view own saved posts" ON saved_posts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can save posts" ON saved_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unsave posts" ON saved_posts FOR DELETE USING (auth.uid() = user_id);

-- Conversations: participants only
CREATE POLICY "Users can view own conversations" ON conversations FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = conversations.id AND user_id = auth.uid()
  )
);
CREATE POLICY "Users can create conversations" ON conversations FOR INSERT WITH CHECK (true);

-- Conversation participants: own conversations
CREATE POLICY "Participants viewable in own conversations" ON conversation_participants FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_participants cp
    WHERE cp.conversation_id = conversation_participants.conversation_id AND cp.user_id = auth.uid()
  )
);
CREATE POLICY "Users can add participants" ON conversation_participants FOR INSERT WITH CHECK (true);

-- Messages: participants only
CREATE POLICY "Messages viewable by participants" ON messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()
  )
);
CREATE POLICY "Participants can send messages" ON messages FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversation_participants
    WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()
  )
);

-- Notifications: own only
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- STORAGE BUCKETS (create in Supabase Dashboard → Storage)
-- ============================================
-- 1. avatars (public)
-- 2. posts (public)
-- 3. reels (public)
-- 4. stories (public)
--
-- Bucket policies (run in SQL Editor after creating buckets):
--
-- INSERT INTO storage.buckets (id, name, public) VALUES
--   ('avatars', 'avatars', true),
--   ('posts', 'posts', true),
--   ('reels', 'reels', true),
--   ('stories', 'stories', true);
--
-- CREATE POLICY "Public read" ON storage.objects FOR SELECT USING (bucket_id IN ('avatars','posts','reels','stories'));
-- CREATE POLICY "Authenticated upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id IN ('avatars','posts','reels','stories') AND auth.uid() IS NOT NULL);
-- CREATE POLICY "Own update" ON storage.objects FOR UPDATE USING (auth.uid() = owner);
-- CREATE POLICY "Own delete" ON storage.objects FOR DELETE USING (auth.uid() = owner);