-- ============================================================
-- W2-スケール: facility_trends マテビュー（CONCURRENTLY REFRESH 対応）
-- ============================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS facility_trends AS
SELECT
  fm.facility_id,
  COUNT(*) FILTER (WHERE fm.created_at >= NOW() - INTERVAL '24 hours')  AS mentions_24h,
  COUNT(*) FILTER (WHERE fm.created_at >= NOW() - INTERVAL '7 days')    AS mentions_7d,
  COUNT(*) FILTER (WHERE fm.created_at >= NOW() - INTERVAL '30 days')   AS mentions_30d,
  MAX(fm.created_at) AS last_mentioned_at,
  AVG(fm.match_score) FILTER (WHERE fm.created_at >= NOW() - INTERVAL '7 days') AS avg_score_7d,
  NOW() AS refreshed_at
FROM facility_mentions fm
WHERE fm.facility_id IS NOT NULL
GROUP BY fm.facility_id;

-- CONCURRENTLY REFRESH に必須の UNIQUE INDEX
CREATE UNIQUE INDEX IF NOT EXISTS idx_facility_trends_facility_id
  ON facility_trends (facility_id);

CREATE INDEX IF NOT EXISTS idx_facility_trends_24h
  ON facility_trends (mentions_24h DESC) WHERE mentions_24h > 0;
CREATE INDEX IF NOT EXISTS idx_facility_trends_7d
  ON facility_trends (mentions_7d DESC) WHERE mentions_7d > 0;

CREATE OR REPLACE FUNCTION refresh_facility_trends()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY facility_trends;
END;
$$;

GRANT EXECUTE ON FUNCTION refresh_facility_trends() TO service_role;
GRANT SELECT ON facility_trends TO anon, authenticated;

-- 初回データ投入（CONCURRENTLY なしで即時実行）
REFRESH MATERIALIZED VIEW facility_trends;

-- pg_cron で15分ごとにREFRESH
SELECT cron.schedule(
  'refresh-facility-trends',
  '*/15 * * * *',
  $$ SELECT refresh_facility_trends(); $$
);
