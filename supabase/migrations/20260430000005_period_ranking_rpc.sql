-- 期間別ランキング RPC
-- p_days_ago: NULL=累計, 7=今週, 30=今月
-- p_sort_col: total_points / explorer_points / social_points / visit_count
-- p_limit   : 取得件数上限

CREATE OR REPLACE FUNCTION get_period_rankings(
  p_days_ago   INTEGER DEFAULT NULL,
  p_sort_col   TEXT    DEFAULT 'total_points',
  p_limit      INTEGER DEFAULT 50
)
RETURNS TABLE (
  user_id          UUID,
  display_name     TEXT,
  avatar_url       TEXT,
  visit_count      BIGINT,
  explorer_points  BIGINT,
  review_count     BIGINT,
  social_points    BIGINT,
  total_points     BIGINT,
  current_title    TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH since AS (
    SELECT CASE
      WHEN p_days_ago IS NULL THEN NULL::TIMESTAMPTZ
      ELSE NOW() - (p_days_ago || ' days')::INTERVAL
    END AS dt
  ),
  visit_stats AS (
    SELECT
      v.user_id,
      COUNT(*)::BIGINT          AS vc,
      (COUNT(*) * 100)::BIGINT  AS ep
    FROM visits v, since s
    WHERE (s.dt IS NULL OR v.visited_at >= s.dt)
    GROUP BY v.user_id
  ),
  review_stats AS (
    SELECT
      r.user_id,
      COUNT(*)::BIGINT         AS rc,
      (COUNT(*) * 50)::BIGINT  AS sp_r
    FROM reviews r, since s
    WHERE (s.dt IS NULL OR r.created_at >= s.dt)
    GROUP BY r.user_id
  ),
  combined AS (
    SELECT
      u.id                                                          AS user_id,
      COALESCE(u.display_name, u.username, '湯めぐりユーザー')       AS display_name,
      u.avatar_url,
      COALESCE(vs.vc,   0)                                          AS visit_count,
      COALESCE(vs.ep,   0)                                          AS explorer_points,
      COALESCE(rs.rc,   0)                                          AS review_count,
      COALESCE(rs.sp_r, 0)                                          AS social_points,
      COALESCE(vs.ep, 0) + COALESCE(rs.sp_r, 0)                    AS total_points
    FROM users u
    JOIN      visit_stats  vs ON vs.user_id = u.id
    LEFT JOIN review_stats rs ON rs.user_id = u.id
    WHERE COALESCE(vs.vc, 0) > 0
  )
  SELECT
    c.user_id,
    c.display_name,
    c.avatar_url,
    c.visit_count,
    c.explorer_points,
    c.review_count,
    c.social_points,
    c.total_points,
    CASE
      WHEN c.visit_count >= 1000 THEN '湯めぐり王'
      WHEN c.visit_count >= 500  THEN '温泉マスター'
      WHEN c.visit_count >= 200  THEN '温泉上級者'
      WHEN c.visit_count >= 100  THEN '温泉愛好家'
      WHEN c.visit_count >= 50   THEN '温泉通'
      WHEN c.visit_count >= 20   THEN '湯めぐり中級者'
      WHEN c.visit_count >= 10   THEN '湯めぐり経験者'
      WHEN c.visit_count >= 5    THEN '湯めぐり見習い'
      ELSE                            '湯めぐり初心者'
    END AS current_title
  FROM combined c
  ORDER BY
    CASE p_sort_col
      WHEN 'total_points'    THEN c.total_points
      WHEN 'explorer_points' THEN c.explorer_points
      WHEN 'social_points'   THEN c.social_points
      WHEN 'visit_count'     THEN c.visit_count
      ELSE                        c.total_points
    END DESC
  LIMIT p_limit;
$$;

-- 認証済み・匿名ユーザー双方に実行権限を付与
GRANT EXECUTE ON FUNCTION get_period_rankings(INTEGER, TEXT, INTEGER)
  TO authenticated, anon;
