-- ============================================================
-- トレンド施設 RPC（直近 N 日でチェックイン数が多い施設を返す）
-- セッション40 / 2026-04-28
-- ============================================================

-- ------------------------------------------------------------
-- get_trending_facilities
--   直近 days_ago 日以内にチェックインされた件数が多い順に
--   facilities を最大 limit_count 件返す。
--
-- 使い方（SQL）:
--   SELECT * FROM get_trending_facilities(30, 10);
--
-- 使い方（Flutter Supabase）:
--   await supabase.rpc('get_trending_facilities', params: {
--     'days_ago': 30,
--     'limit_count': 10,
--   });
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_trending_facilities(
  days_ago     INT     DEFAULT 30,
  limit_count  INT     DEFAULT 10
)
RETURNS TABLE (
  id                UUID,
  name              TEXT,
  name_kana         TEXT,
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  address           TEXT,
  phone             TEXT,
  website           TEXT,
  type              TEXT,
  hours             TEXT,
  price             INT,
  data_source       TEXT,
  data_quality_score INT,
  facility_type     TEXT,       -- facility_types.code
  visit_count       BIGINT      -- 直近 days_ago 日のチェックイン数
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    f.id,
    f.name,
    f.name_kana,
    f.latitude,
    f.longitude,
    f.address,
    f.phone,
    f.website,
    f.type,
    f.hours,
    f.price,
    f.data_source,
    f.data_quality_score,
    ft.code AS facility_type,
    COUNT(v.id) AS visit_count
  FROM facilities f
  LEFT JOIN facility_types ft ON f.facility_type_id = ft.id
  INNER JOIN visits v
    ON v.facility_id = f.id
   AND v.visited_at >= NOW() - (days_ago || ' days')::INTERVAL
  WHERE f.latitude IS NOT NULL
    AND f.longitude IS NOT NULL
  GROUP BY
    f.id, f.name, f.name_kana, f.latitude, f.longitude,
    f.address, f.phone, f.website, f.type, f.hours, f.price,
    f.data_source, f.data_quality_score, ft.code
  ORDER BY visit_count DESC
  LIMIT limit_count;
$$;

-- RLS: 誰でも呼び出せる（SECURITY DEFINER で RLS をバイパスして集計）
REVOKE EXECUTE ON FUNCTION get_trending_facilities(INT, INT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_trending_facilities(INT, INT) TO anon, authenticated;

-- ------------------------------------------------------------
-- get_popular_facilities_no_visits
--   visits が 0 件の場合のフォールバック用。
--   data_quality_score 順・名前順で最大 limit_count 件返す。
--   トレンドデータが少ない初期フェーズで使用する。
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_popular_facilities_no_visits(
  limit_count INT DEFAULT 10
)
RETURNS TABLE (
  id                UUID,
  name              TEXT,
  name_kana         TEXT,
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  address           TEXT,
  phone             TEXT,
  website           TEXT,
  type              TEXT,
  hours             TEXT,
  price             INT,
  data_source       TEXT,
  data_quality_score INT,
  facility_type     TEXT,
  visit_count       BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    f.id,
    f.name,
    f.name_kana,
    f.latitude,
    f.longitude,
    f.address,
    f.phone,
    f.website,
    f.type,
    f.hours,
    f.price,
    f.data_source,
    f.data_quality_score,
    ft.code AS facility_type,
    COALESCE(vc.cnt, 0) AS visit_count
  FROM facilities f
  LEFT JOIN facility_types ft ON f.facility_type_id = ft.id
  LEFT JOIN (
    SELECT facility_id, COUNT(*) AS cnt
    FROM visits
    GROUP BY facility_id
  ) vc ON vc.facility_id = f.id
  WHERE f.latitude IS NOT NULL
    AND f.longitude IS NOT NULL
  ORDER BY f.data_quality_score DESC, f.name ASC
  LIMIT limit_count;
$$;

REVOKE EXECUTE ON FUNCTION get_popular_facilities_no_visits(INT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_popular_facilities_no_visits(INT) TO anon, authenticated;
