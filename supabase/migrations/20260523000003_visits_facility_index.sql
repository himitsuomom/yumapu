-- visits テーブルの週次チェックイン数集計を高速化するインデックス
CREATE INDEX IF NOT EXISTS idx_visits_facility_visited_at
  ON visits(facility_id, visited_at DESC);
