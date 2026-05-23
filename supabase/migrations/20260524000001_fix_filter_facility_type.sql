-- ============================================================
-- Phase 1: フィルターバグ修正
-- 2026-05-24
--
-- 修正内容:
-- get_facilities_in_bounds に filter_facility_type パラメータを追加
-- Dart 側 (facility_service.dart) は既にこのパラメータを渡しているが
-- RPC 側が受け取っておらず、施設タイプフィルターが無効だった
-- ============================================================

DROP FUNCTION IF EXISTS public.get_facilities_in_bounds(
  double precision, double precision, double precision, double precision,
  uuid[], integer
);

CREATE OR REPLACE FUNCTION public.get_facilities_in_bounds(
  min_lat              double precision,
  min_lng              double precision,
  max_lat              double precision,
  max_lng              double precision,
  filter_amenities     uuid[]  DEFAULT NULL,
  facility_limit       integer DEFAULT 500,
  filter_facility_type uuid    DEFAULT NULL
)
RETURNS TABLE (
  id                   uuid,
  name                 varchar,
  latitude             double precision,
  longitude            double precision,
  facility_type        varchar,
  facility_type_id     uuid,
  address              text,
  data_quality_score   integer
)
LANGUAGE plpgsql
STABLE
SET search_path = public, extensions
AS $$
BEGIN
  RETURN QUERY
  SELECT
    f.id,
    f.name,
    f.latitude,
    f.longitude,
    ft.code  AS facility_type,
    ft.id    AS facility_type_id,
    f.address,
    f.data_quality_score
  FROM public.facilities f
  LEFT JOIN public.facility_types ft ON f.facility_type_id = ft.id
  WHERE
    f.latitude  BETWEEN min_lat AND max_lat
    AND f.longitude BETWEEN min_lng AND max_lng
    AND f.latitude  IS NOT NULL
    AND f.longitude IS NOT NULL
    -- 施設タイプフィルター（指定なし = 全タイプ返す）
    AND (
      filter_facility_type IS NULL
      OR f.facility_type_id = filter_facility_type
    )
    -- アメニティ AND フィルター（指定した全アメニティを持つ施設のみ）
    AND (
      filter_amenities IS NULL
      OR (
        SELECT COUNT(DISTINCT fa.amenity_id)
        FROM public.facility_amenities fa
        WHERE fa.facility_id = f.id
          AND fa.amenity_id = ANY(filter_amenities)
      ) = array_length(filter_amenities, 1)
    )
  ORDER BY f.data_quality_score DESC
  LIMIT facility_limit;
END;
$$;

-- 動作確認用: 施設タイプ一覧
-- SELECT id, code, name FROM facility_types ORDER BY code;
