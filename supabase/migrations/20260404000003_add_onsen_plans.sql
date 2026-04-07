-- Migration: 湯めぐりプラン機能

-- ============================================================
-- 1. onsen_plans テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS onsen_plans (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title        VARCHAR(200) NOT NULL,
  description  TEXT,
  facility_ids UUID[]  DEFAULT '{}',
  is_public    BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_onsen_plans_user ON onsen_plans (user_id);
CREATE INDEX idx_onsen_plans_public ON onsen_plans (is_public) WHERE is_public = TRUE;

-- ============================================================
-- 2. RLS
-- ============================================================
ALTER TABLE onsen_plans ENABLE ROW LEVEL SECURITY;

-- 公開プランは全員が読める
CREATE POLICY "Public plans are viewable by everyone"
  ON onsen_plans FOR SELECT
  USING (is_public = TRUE OR auth.uid() = user_id);

-- 自分のプランのみ作成・更新・削除
CREATE POLICY "Users can create own plans"
  ON onsen_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own plans"
  ON onsen_plans FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own plans"
  ON onsen_plans FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 3. updated_at 自動更新トリガー
-- ============================================================
CREATE OR REPLACE FUNCTION update_onsen_plans_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_onsen_plans_updated_at
  BEFORE UPDATE ON onsen_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_onsen_plans_updated_at();
