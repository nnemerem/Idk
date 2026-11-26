-- Ripple Phase 1 — Reposts
-- Run this in the Supabase SQL Editor after migrations 000000 through 000003.

-- ============================================
-- POST REPOSTS
-- ============================================
CREATE TABLE IF NOT EXISTS post_reposts (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_reposts_user_id ON post_reposts(user_id);
CREATE INDEX IF NOT EXISTS idx_post_reposts_post_id ON post_reposts(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reposts_created_at ON post_reposts(created_at DESC);

ALTER TABLE post_reposts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Post reposts viewable by everyone" ON post_reposts
  FOR SELECT USING (true);
CREATE POLICY "Users can repost posts" ON post_reposts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unrepost posts" ON post_reposts
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- REEL REPOSTS
-- ============================================
CREATE TABLE IF NOT EXISTS reel_reposts (
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (reel_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reel_reposts_user_id ON reel_reposts(user_id);
CREATE INDEX IF NOT EXISTS idx_reel_reposts_reel_id ON reel_reposts(reel_id);
CREATE INDEX IF NOT EXISTS idx_reel_reposts_created_at ON reel_reposts(created_at DESC);

ALTER TABLE reel_reposts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reel reposts viewable by everyone" ON reel_reposts
  FOR SELECT USING (true);
CREATE POLICY "Users can repost reels" ON reel_reposts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unrepost reels" ON reel_reposts
  FOR DELETE USING (auth.uid() = user_id);
