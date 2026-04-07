-- visits テーブルに RLS を有効化
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Visits are viewable by everyone"
  ON visits FOR SELECT USING (true);

CREATE POLICY "Users can insert their own visits"
  ON visits FOR INSERT WITH CHECK (auth.uid() = user_id);

-- user_rankings テーブルに RLS を有効化
ALTER TABLE user_rankings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User rankings are viewable by everyone"
  ON user_rankings FOR SELECT USING (true);

CREATE POLICY "Users can insert their own ranking"
  ON user_rankings FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own ranking"
  ON user_rankings FOR UPDATE USING (auth.uid() = user_id);
