-- Ripple Phase 0 — Foundation migrations
-- Adds: comment replies (threaded comments) + saved collections
-- Run this in the Supabase SQL Editor after the initial schema.

-- ============================================
-- COMMENT REPLIES (threaded comments)
-- ============================================
-- A comment can optionally point to a parent comment, forming a reply thread.
-- Top-level comments have parent_id IS NULL.

ALTER TABLE post_comments
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES post_comments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_post_comments_parent_id ON post_comments(parent_id);

ALTER TABLE reel_comments
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES reel_comments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_reel_comments_parent_id ON reel_comments(parent_id);

-- Replies are viewable by everyone (same as top-level comments).
-- No extra RLS needed: post_comments/reel_comments already have
-- "viewable by everyone" SELECT policies; INSERT/UPDATE/DELETE are gated
-- to auth.uid() = user_id, which covers replies too.

-- ============================================
-- SAVED COLLECTIONS (organize saved posts/reels)
-- ============================================
-- Instagram lets users save posts into named collections (default
-- "All posts" still lives in saved_posts). Collections are private.

CREATE TABLE IF NOT EXISTS saved_collections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_collections_user_id ON saved_collections(user_id);

CREATE TABLE IF NOT EXISTS saved_collection_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  collection_id UUID REFERENCES saved_collections(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (collection_id, post_id, reel_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_collection_items_collection ON saved_collection_items(collection_id);
CREATE INDEX IF NOT EXISTS idx_saved_collection_items_post ON saved_collection_items(post_id);
CREATE INDEX IF NOT EXISTS idx_saved_collection_items_reel ON saved_collection_items(reel_id);

-- An item is either a post OR a reel, never both and never neither.
ALTER TABLE saved_collection_items
  ADD CONSTRAINT saved_collection_items_media_xor
  CHECK ((post_id IS NOT NULL) <> (reel_id IS NOT NULL));

-- ============================================
-- RLS FOR COLLECTIONS
-- ============================================
ALTER TABLE saved_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_collection_items ENABLE ROW LEVEL SECURITY;

-- Collections: private to the owner
CREATE POLICY "Users can view own collections" ON saved_collections
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own collections" ON saved_collections
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own collections" ON saved_collections
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own collections" ON saved_collections
  FOR DELETE USING (auth.uid() = user_id);

-- Collection items: visible to the collection owner
CREATE POLICY "Users can view items in own collections" ON saved_collection_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM saved_collections sc
      WHERE sc.id = saved_collection_items.collection_id AND sc.user_id = auth.uid()
    )
  );
CREATE POLICY "Users can insert items into own collections" ON saved_collection_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM saved_collections sc
      WHERE sc.id = saved_collection_items.collection_id AND sc.user_id = auth.uid()
    )
  );
CREATE POLICY "Users can delete items from own collections" ON saved_collection_items
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM saved_collections sc
      WHERE sc.id = saved_collection_items.collection_id AND sc.user_id = auth.uid()
    )
  );

-- ============================================
-- HELPER: bump posts_count already exists in initial schema.
-- No new helpers needed for this migration.
