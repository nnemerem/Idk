-- Ripple Phase 1 — Comment pinning
-- Run this in the Supabase SQL Editor after migrations 000000, 000001, and 000002.

-- ============================================
-- PINNED POST COMMENTS
-- ============================================
ALTER TABLE post_comments
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_post_comments_is_pinned ON post_comments(is_pinned);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id_pinned ON post_comments(post_id, is_pinned);

-- ============================================
-- PINNED REEL COMMENTS
-- ============================================
ALTER TABLE reel_comments
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_reel_comments_is_pinned ON reel_comments(is_pinned);
CREATE INDEX IF NOT EXISTS idx_reel_comments_reel_id_pinned ON reel_comments(reel_id, is_pinned);

-- RLS: pin/unpin is gated to comment author or post/reel owner.
-- Existing policies already allow "Users can update own comments" —
-- pinning is an update to is_pinned, so comment authors can pin their own.
-- Post/reel owners can pin any comment on their content.
