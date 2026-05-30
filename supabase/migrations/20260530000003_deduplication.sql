-- ============================================================
-- 重複防止・解消システム
-- 2026-05-30
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE public.facilities
  ADD COLUMN IF NOT EXISTS merged_into UUID REFERENCES public.facilities(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS merged_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_facilities_merged_into
  ON public.facilities(merged_into) WHERE merged_into IS NOT NULL;

CREATE OR REPLACE FUNCTION public.normalize_facility_name(p_name TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
  SELECT lower(
    regexp_replace(
      regexp_replace(
        regexp_replace(p_name, '[（(][^）)]*[）)]', '', 'g'),
        '[[:space:]　:：;；・]', '', 'g'
      ),
      '(温泉|銭湯|スパ|サウナ|の湯|湯)$', '', 'g'
    )
  )
$$;

CREATE OR REPLACE FUNCTION public.haversine_m(
  lat1 NUMERIC, lng1 NUMERIC, lat2 NUMERIC, lng2 NUMERIC
) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE
AS $$
  SELECT 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
      * power(sin(radians(lng2 - lng1) / 2), 2)
  ))
$$;

CREATE OR REPLACE FUNCTION public.find_duplicate_facilities(
  p_name TEXT,
  p_lat NUMERIC,
  p_lng NUMERIC,
  p_exclude_id UUID DEFAULT NULL
)
RETURNS TABLE (
  facility_id UUID,
  name TEXT,
  distance_m NUMERIC,
  name_similarity NUMERIC
)
LANGUAGE sql STABLE
AS $$
  SELECT
    f.id,
    f.name,
    public.haversine_m(p_lat, p_lng, f.latitude::NUMERIC, f.longitude::NUMERIC) AS distance_m,
    similarity(
      public.normalize_facility_name(p_name),
      public.normalize_facility_name(f.name)
    ) AS name_similarity
  FROM public.facilities f
  WHERE f.merged_into IS NULL
    AND (p_exclude_id IS NULL OR f.id != p_exclude_id)
    AND f.latitude IS NOT NULL
    AND f.longitude IS NOT NULL
    AND public.haversine_m(p_lat, p_lng, f.latitude::NUMERIC, f.longitude::NUMERIC) <= 500
    AND similarity(
          public.normalize_facility_name(p_name),
          public.normalize_facility_name(f.name)
        ) >= 0.8
  ORDER BY distance_m ASC, name_similarity DESC
$$;

GRANT EXECUTE ON FUNCTION public.find_duplicate_facilities TO service_role;
GRANT EXECUTE ON FUNCTION public.normalize_facility_name TO service_role;
GRANT EXECUTE ON FUNCTION public.haversine_m TO service_role;

-- 重複URLを NULL に置換してから UNIQUE INDEX を作成
UPDATE public.crawl_schedule cs
SET official_site_url = NULL
WHERE official_site_url IS NOT NULL
  AND facility_id NOT IN (
    SELECT DISTINCT ON (official_site_url) facility_id
    FROM public.crawl_schedule
    WHERE official_site_url IS NOT NULL
    ORDER BY official_site_url, priority ASC, facility_id ASC
  );

CREATE UNIQUE INDEX IF NOT EXISTS uniq_crawl_schedule_url
  ON public.crawl_schedule(official_site_url)
  WHERE official_site_url IS NOT NULL;

CREATE OR REPLACE FUNCTION public.merge_facility(
  p_source_id UUID,
  p_target_id UUID
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_source_id = p_target_id THEN
    RAISE EXCEPTION 'source と target が同一です';
  END IF;

  UPDATE public.raw_facility_data
    SET facility_id = p_target_id
    WHERE facility_id = p_source_id;

  INSERT INTO public.crawl_schedule (facility_id, official_site_url, priority)
  SELECT p_target_id, official_site_url, priority
  FROM public.crawl_schedule WHERE facility_id = p_source_id
  ON CONFLICT (facility_id) DO NOTHING;

  DELETE FROM public.crawl_schedule WHERE facility_id = p_source_id;

  UPDATE public.facilities
    SET merged_into = p_target_id,
        merged_at = NOW()
    WHERE id = p_source_id;
END$$;

GRANT EXECUTE ON FUNCTION public.merge_facility TO service_role;
