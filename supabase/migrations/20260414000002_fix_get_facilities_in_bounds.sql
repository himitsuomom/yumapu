-- ============================================================
-- get_facilities_in_bounds 関数の修正
-- 2026-04-14
--
-- 修正内容:
-- 1. SET search_path = public, extensions に変更（PostGIS解決）
-- 2. PostGIS ST_Within → lat/lng BETWEEN に変更
--    (geometry カラムが空のデータが多いため lat/lng カラムを直接使用)
-- 3. INNER JOIN facility_types → LEFT JOIN に変更（NULL安全）
-- 4. 戻り値に latitude, longitude, facility_type_id, address を追加
--    (Flutter の Facility.fromJson が必要とするカラムを返す)
-- 5. アメニティフィルターを OR → AND に変更
--    (複数選択時に全条件一致のみを返す正しい動作)
-- ============================================================

DROP FUNCTION IF EXISTS public.get_facilities_in_bounds(
  double precision, double precision, double precision, double precision,
  uuid[], integer
);

CREATE OR REPLACE FUNCTION public.get_facilities_in_bounds(
  min_lat            double precision,
  min_lng            double precision,
  max_lat            double precision,
  max_lng            double precision,
  filter_amenities   uuid[]  DEFAULT NULL,
  facility_limit     integer DEFAULT 500
)
RETURNS TABLE (
  id                 uuid,
  name               varchar,
  latitude           double precision,
  longitude          double precision,
  facility_type      varchar,
  facility_type_id   uuid,
  address            text,
  data_quality_score integer
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
    -- lat/lng カラムで矩形範囲フィルター（PostGIS 不要）
    f.latitude  BETWEEN min_lat AND max_lat
    AND f.longitude BETWEEN min_lng AND max_lng
    AND f.latitude IS NOT NULL
    AND f.longitude IS NOT NULL
    -- アメニティ AND フィルター: 指定した全アメニティを持つ施設のみ返す
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
