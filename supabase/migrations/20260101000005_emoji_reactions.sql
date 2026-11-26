-- Ripple Phase 1 — Emoji Reactions
-- Run this in the Supabase SQL Editor after migrations 000000 through 000004.

-- ============================================
-- POST COMMENT REACTIONS
-- One emoji reaction per user per comment.
-- ============================================
CREATE TABLE IF NOT EXISTS post_comment_reactions (
  comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_comment_reactions_comment_id ON post_comment_reactions(comment_id);
CREATE INDEX IF NOT EXISTS idx_post_comment_reactions_user_id ON post_comment_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comment_reactions_emoji ON post_comment_reactions(emoji);

ALTER TABLE post_comment_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Post comment reactions viewable by everyone" ON post_comment_reactions
  FOR SELECT USING (true);
CREATE POLICY "Users can add post comment reactions" ON post_comment_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their post comment reaction" ON post_comment_reactions
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their post comment reaction" ON post_comment_reactions
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- REEL COMMENT REACTIONS
-- One emoji reaction per user per comment.
-- ============================================
CREATE TABLE IF NOT EXISTS reel_comment_reactions (
  comment_id UUID REFERENCES reel_comments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reel_comment_reactions_comment_id ON reel_comment_reactions(comment_id);
CREATE INDEX IF NOT EXISTS idx_reel_comment_reactions_user_id ON reel_comment_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_reel_comment_reactions_emoji ON reel_comment_reactions(emoji);

ALTER TABLE reel_comment_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reel comment reactions viewable by everyone" ON reel_comment_reactions
  FOR SELECT USING (true);
CREATE POLICY "Users can add reel comment reactions" ON reel_comment_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their reel comment reaction" ON reel_comment_reactions
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their reel comment reaction" ON reel_comment_reactions
  FOR DELETE USING (auth.uid() = user_id);
