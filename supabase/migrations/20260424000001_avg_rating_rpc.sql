-- 施設の平均評価をサーバーサイドで計算するRPC関数
--
-- reviewListProvider は最新 AppConstants.pageSize 件に LIMIT されているため、
-- 件数が多い施設では平均評価が偏る（Bug-V7-2）。
-- この関数は全レビューの AVG(rating) を計算して返す。

CREATE OR REPLACE FUNCTION get_facility_avg_rating(p_facility_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ROUND(AVG(rating)::numeric, 1)
  FROM reviews
  WHERE facility_id = p_facility_id;
$$;
