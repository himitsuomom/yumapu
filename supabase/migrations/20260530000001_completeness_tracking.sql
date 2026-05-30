-- ============================================================
-- 全国施設網羅システム
-- 2026-05-30
-- ============================================================

ALTER TABLE public.crawl_schedule
  ADD COLUMN IF NOT EXISTS url_source TEXT
    CHECK (url_source IN ('official','yahoo_yolp','here','user_report','manual'));

CREATE INDEX IF NOT EXISTS idx_crawl_schedule_url_source
  ON public.crawl_schedule(url_source)
  WHERE url_source IS NOT NULL;

ALTER TABLE public.facility_issue_reports
  ADD COLUMN IF NOT EXISTS suggested_url TEXT,
  ADD COLUMN IF NOT EXISTS suggested_phone TEXT,
  ADD COLUMN IF NOT EXISTS suggested_hours TEXT,
  ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_facility_issue_reports_pending_url
  ON public.facility_issue_reports(facility_id)
  WHERE status = 'pending' AND suggested_url IS NOT NULL;

CREATE OR REPLACE VIEW public.v_coverage_by_prefecture AS
SELECT
  p.id AS prefecture_id,
  p.name AS prefecture_name,
  COUNT(f.id) AS total_facilities,
  COUNT(cs.official_site_url) AS with_url,
  COUNT(cs.official_site_url) FILTER (WHERE cs.data_complete) AS complete,
  ROUND(100.0 * COUNT(cs.official_site_url)::numeric / NULLIF(COUNT(f.id), 0), 2) AS url_rate,
  ROUND(100.0 * COUNT(cs.official_site_url) FILTER (WHERE cs.data_complete)::numeric
        / NULLIF(COUNT(f.id), 0), 2) AS complete_rate
FROM public.prefectures p
LEFT JOIN public.facilities f ON f.prefecture_id = p.id
LEFT JOIN public.crawl_schedule cs ON cs.facility_id = f.id
GROUP BY p.id, p.name
ORDER BY p.name;

CREATE OR REPLACE VIEW public.v_coverage_summary AS
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE official_site_url IS NOT NULL) AS with_url,
  COUNT(*) FILTER (WHERE data_complete) AS complete,
  COUNT(*) FILTER (WHERE url_source = 'official') AS src_official,
  COUNT(*) FILTER (WHERE url_source = 'yahoo_yolp') AS src_yahoo,
  COUNT(*) FILTER (WHERE url_source = 'here') AS src_here,
  COUNT(*) FILTER (WHERE url_source = 'user_report') AS src_user,
  ROUND(100.0 * COUNT(*) FILTER (WHERE official_site_url IS NOT NULL)::numeric
        / NULLIF(COUNT(*), 0), 2) AS url_rate_pct
FROM public.crawl_schedule;

GRANT SELECT ON public.v_coverage_by_prefecture TO service_role;
GRANT SELECT ON public.v_coverage_summary TO service_role;

CREATE OR REPLACE FUNCTION public.apply_url_with_priority(
  p_facility_id UUID,
  p_url TEXT,
  p_source TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_source TEXT;
  v_current_priority INT;
  v_new_priority INT;
BEGIN
  v_new_priority := CASE p_source
    WHEN 'manual'      THEN 0
    WHEN 'official'    THEN 1
    WHEN 'user_report' THEN 2
    WHEN 'yahoo_yolp'  THEN 3
    WHEN 'here'        THEN 4
    ELSE 9
  END;

  SELECT url_source INTO v_current_source
  FROM public.crawl_schedule WHERE facility_id = p_facility_id;

  v_current_priority := CASE COALESCE(v_current_source, 'none')
    WHEN 'manual'      THEN 0
    WHEN 'official'    THEN 1
    WHEN 'user_report' THEN 2
    WHEN 'yahoo_yolp'  THEN 3
    WHEN 'here'        THEN 4
    ELSE 99
  END;

  IF v_new_priority <= v_current_priority THEN
    UPDATE public.facilities SET website = p_url WHERE id = p_facility_id;
    UPDATE public.crawl_schedule
      SET official_site_url = p_url,
          url_source = p_source,
          status = 'pending',
          data_complete = FALSE
    WHERE facility_id = p_facility_id;
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END$$;

GRANT EXECUTE ON FUNCTION public.apply_url_with_priority TO service_role;
