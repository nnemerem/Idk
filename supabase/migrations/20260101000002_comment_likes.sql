-- Ripple Phase 1 — Comment likes
-- Run this in the Supabase SQL Editor after migrations 000000 and 000001.

-- ============================================
-- POST COMMENT LIKES
-- ============================================
CREATE TABLE IF NOT EXISTS post_comment_likes (
  post_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_comment_likes_user_id ON post_comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comment_likes_comment_id ON post_comment_likes(post_comment_id);

ALTER TABLE post_comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Post comment likes viewable by everyone" ON post_comment_likes
  FOR SELECT USING (true);
CREATE POLICY "Users can like own post comments" ON post_comment_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike own post comments" ON post_comment_likes
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- REEL COMMENT LIKES
-- ============================================
CREATE TABLE IF NOT EXISTS reel_comment_likes (
  reel_comment_id UUID REFERENCES reel_comments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (reel_comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reel_comment_likes_user_id ON reel_comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_reel_comment_likes_comment_id ON reel_comment_likes(reel_comment_id);

ALTER TABLE reel_comment_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reel comment likes viewable by everyone" ON reel_comment_likes
  FOR SELECT USING (true);
CREATE POLICY "Users can like own reel comments" ON reel_comment_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike own reel comments" ON reel_comment_likes
  FOR DELETE USING (auth.uid() = user_id);
