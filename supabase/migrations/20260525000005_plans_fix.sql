-- プランテーブルのRLS確認用migration
-- onsen_plans テーブルが存在することを前提
ALTER TABLE IF EXISTS onsen_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS plans_select_own ON onsen_plans;
DROP POLICY IF EXISTS plans_insert_own ON onsen_plans;
DROP POLICY IF EXISTS plans_update_own ON onsen_plans;
DROP POLICY IF EXISTS plans_delete_own ON onsen_plans;

CREATE POLICY plans_select_own ON onsen_plans FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY plans_insert_own ON onsen_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY plans_update_own ON onsen_plans FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY plans_delete_own ON onsen_plans FOR DELETE
  USING (auth.uid() = user_id);
