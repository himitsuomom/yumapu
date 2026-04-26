-- 施設のレビュー集計（件数 + 平均評価）を1回のDB呼び出しで取得するRPC関数
--
-- 背景: FacilityPreviewSheet では reviewCountProvider と facilityAvgRatingProvider を
-- 個別に呼び出していた（2つの別クエリ）。この RPC に統合することで API 呼び出しを1回に削減する。
-- 合わせて5並列だったクエリが4並列になる。
--
-- 戻り値: JSON { "count": N, "avg_rating": X.X }
--   count     ... 全レビュー件数（0 以上の整数）
--   avg_rating... 全件平均（小数点1桁に丸め。レビュー0件の場合は null → クライアントで 0.0 に変換）

CREATE OR REPLACE FUNCTION get_facility_review_summary(p_facility_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'count',      COUNT(*)::int,
    'avg_rating', CASE
                    WHEN COUNT(*) = 0 THEN NULL
                    ELSE ROUND(AVG(rating)::numeric, 1)
                  END
  )
  FROM reviews
  WHERE facility_id = p_facility_id;
$$;

-- 既存の get_facility_avg_rating は後方互換のために残す（他の場所で使用している可能性があるため）
