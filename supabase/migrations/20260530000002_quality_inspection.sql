-- ============================================================
-- データ品質検査システム
-- 2026-05-30
-- ============================================================

-- raw_facility_data に conflict_info カラムがなければ追加
ALTER TABLE public.raw_facility_data
  ADD COLUMN IF NOT EXISTS conflict_info JSONB,
  ADD COLUMN IF NOT EXISTS collected_at TIMESTAMPTZ DEFAULT NOW();

CREATE OR REPLACE FUNCTION public.validate_raw_facility_data()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_price NUMERIC;
  v_phone TEXT;
  v_hours TEXT;
  v_issues TEXT[] := ARRAY[]::TEXT[];
BEGIN
  v_price := (NEW.raw_json->>'price_adult')::NUMERIC;
  v_phone := NEW.raw_json->>'phone';
  v_hours := NEW.raw_json->>'hours';

  IF v_price IS NOT NULL AND (v_price < 0 OR v_price > 5000) THEN
    v_issues := array_append(v_issues, 'price_out_of_range');
  END IF;

  IF v_phone IS NOT NULL AND v_phone !~ '^0\d{1,4}-\d{1,4}-\d{3,4}$' THEN
    v_issues := array_append(v_issues, 'phone_format_invalid');
  END IF;

  IF v_hours IS NOT NULL AND v_hours !~ '\d' THEN
    v_issues := array_append(v_issues, 'hours_no_digits');
  END IF;

  IF array_length(v_issues, 1) > 0 THEN
    NEW.conflict_info := COALESCE(NEW.conflict_info, '{}'::jsonb)
      || jsonb_build_object('validation_issues', to_jsonb(v_issues));
    IF 'price_out_of_range' = ANY(v_issues) THEN
      NEW.status := 'flagged';
    END IF;
  END IF;

  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_validate_raw_facility_data ON public.raw_facility_data;
CREATE TRIGGER trg_validate_raw_facility_data
  BEFORE INSERT OR UPDATE ON public.raw_facility_data
  FOR EACH ROW EXECUTE FUNCTION public.validate_raw_facility_data();

CREATE OR REPLACE FUNCTION public.get_stale_facilities(p_limit INT DEFAULT 100)
RETURNS TABLE (
  facility_id UUID,
  official_site_url TEXT,
  last_crawled_at TIMESTAMPTZ,
  days_since INT
)
LANGUAGE sql STABLE
AS $$
  SELECT
    facility_id,
    official_site_url,
    last_crawled_at,
    EXTRACT(DAY FROM NOW() - last_crawled_at)::INT
  FROM public.crawl_schedule
  WHERE official_site_url IS NOT NULL
    AND last_crawled_at IS NOT NULL
    AND last_crawled_at < NOW() - INTERVAL '90 days'
    AND status != 'in_progress'
  ORDER BY last_crawled_at ASC
  LIMIT p_limit
$$;

GRANT EXECUTE ON FUNCTION public.get_stale_facilities TO service_role;

CREATE OR REPLACE FUNCTION public.get_auto_merge_candidates(p_limit INT DEFAULT 200)
RETURNS TABLE (facility_id UUID)
LANGUAGE sql STABLE
AS $$
  SELECT DISTINCT facility_id
  FROM public.raw_facility_data
  WHERE status = 'pending'
    AND (raw_json->>'confidence')::NUMERIC >= 0.5
    AND collected_at < NOW() - INTERVAL '24 hours'
  LIMIT p_limit
$$;

GRANT EXECUTE ON FUNCTION public.get_auto_merge_candidates TO service_role;
