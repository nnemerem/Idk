-- Ripple Phase 4 — Privacy & Safety / Settings
-- Run this in the Supabase SQL Editor after migrations 000000 through 000005.

-- ============================================
-- PRIVATE ACCOUNT TOGGLE
-- ============================================
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_profiles_is_private ON profiles(is_private);

-- ============================================
-- BLOCKED ACCOUNTS
-- One row per (blocker, blocked). A blocked user cannot follow, message,
-- or interact with the blocker's content.
-- ============================================
CREATE TABLE IF NOT EXISTS blocked_accounts (
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_accounts_blocker ON blocked_accounts(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_accounts_blocked ON blocked_accounts(blocked_id);

ALTER TABLE blocked_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Blocked accounts viewable by the blocker" ON blocked_accounts
  FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Users can block accounts" ON blocked_accounts
  FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can unblock accounts" ON blocked_accounts
  FOR DELETE USING (auth.uid() = blocker_id);

-- ============================================
-- RESTRICTED ACCOUNTS
-- One row per (restricter, restricted). A restricted user's comments on the
-- restricter's posts are hidden from others until approved, and their
-- messages go to a separate folder.
-- ============================================
CREATE TABLE IF NOT EXISTS restricted_accounts (
  restricter_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  restricted_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (restricter_id, restricted_id)
);

CREATE INDEX IF NOT EXISTS idx_restricted_accounts_restricter ON restricted_accounts(restricter_id);
CREATE INDEX IF NOT EXISTS idx_restricted_accounts_restricted ON restricted_accounts(restricted_id);

ALTER TABLE restricted_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Restricted accounts viewable by the restricter" ON restricted_accounts
  FOR SELECT USING (auth.uid() = restricter_id);
CREATE POLICY "Users can restrict accounts" ON restricted_accounts
  FOR INSERT WITH CHECK (auth.uid() = restricter_id);
CREATE POLICY "Users can unrestrict accounts" ON restricted_accounts
  FOR DELETE USING (auth.uid() = restricter_id);
