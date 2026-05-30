-- ============================================================
-- 全国施設登録 — ステージングテーブル + 昇格関数 + 進捗追跡
-- 2026-05-30
-- ============================================================

CREATE TABLE IF NOT EXISTS public.facility_candidates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  latitude        NUMERIC(9,6) NOT NULL,
  longitude       NUMERIC(9,6) NOT NULL,
  prefecture      TEXT,
  address         TEXT,
  website         TEXT,
  phone           TEXT,
  facility_type   TEXT CHECK (facility_type IN ('onsen','public_bath','sauna','spa','unknown')),
  source          TEXT NOT NULL CHECK (source IN ('osm','here','google')),
  source_id       TEXT,
  raw_json        JSONB NOT NULL DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','promoted','duplicate','rejected','error')),
  duplicate_of    UUID REFERENCES public.facilities(id) ON DELETE SET NULL,
  rejection_reason TEXT,
  promoted_facility_id UUID REFERENCES public.facilities(id) ON DELETE SET NULL,
  collected_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at    TIMESTAMPTZ,
  UNIQUE (source, source_id)
);

CREATE INDEX IF NOT EXISTS idx_facility_candidates_pending
  ON public.facility_candidates(prefecture, source, collected_at DESC)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_facility_candidates_status
  ON public.facility_candidates(status, collected_at DESC);

ALTER TABLE public.facility_candidates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON public.facility_candidates
  FOR ALL USING (auth.role() = 'service_role');

-- 進捗追跡テーブル
CREATE TABLE IF NOT EXISTS public.coverage_progress (
  prefecture        TEXT NOT NULL,
  source            TEXT NOT NULL CHECK (source IN ('osm','here','google')),
  status            TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','done','error')),
  candidates_found  INTEGER DEFAULT 0,
  promoted_count    INTEGER DEFAULT 0,
  duplicate_count   INTEGER DEFAULT 0,
  rejected_count    INTEGER DEFAULT 0,
  started_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  last_error        TEXT,
  PRIMARY KEY (prefecture, source)
);

ALTER TABLE public.coverage_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON public.coverage_progress
  FOR ALL USING (auth.role() = 'service_role');

-- 47都道府県 × 3ソース を初期投入
INSERT INTO public.coverage_progress (prefecture, source)
SELECT pref, src
FROM (VALUES
  ('北海道'),('青森県'),('岩手県'),('宮城県'),('秋田県'),('山形県'),('福島県'),
  ('茨城県'),('栃木県'),('群馬県'),('埼玉県'),('千葉県'),('東京都'),('神奈川県'),
  ('新潟県'),('富山県'),('石川県'),('福井県'),('山梨県'),('長野県'),
  ('岐阜県'),('静岡県'),('愛知県'),('三重県'),
  ('滋賀県'),('京都府'),('大阪府'),('兵庫県'),('奈良県'),('和歌山県'),
  ('鳥取県'),('島根県'),('岡山県'),('広島県'),('山口県'),
  ('徳島県'),('香川県'),('愛媛県'),('高知県'),
  ('福岡県'),('佐賀県'),('長崎県'),('熊本県'),('大分県'),('宮崎県'),('鹿児島県'),('沖縄県')
) AS p(pref)
CROSS JOIN (VALUES ('osm'),('here'),('google')) AS s(src)
ON CONFLICT (prefecture, source) DO NOTHING;

-- 昇格関数（候補1件をfacilitiesへ）
-- facility_types の UUID を code から逆引きするヘルパー
CREATE OR REPLACE FUNCTION public.get_facility_type_id(p_code TEXT)
RETURNS UUID
LANGUAGE sql STABLE
AS $$
  SELECT id FROM public.facility_types WHERE code = p_code LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.promote_candidate(p_candidate_id UUID)
RETURNS TABLE (outcome TEXT, facility_id UUID, duplicate_id UUID, reason TEXT)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cand  public.facility_candidates%ROWTYPE;
  v_dup_id UUID;
  v_new_id UUID;
  v_type_id UUID;
  v_url_source TEXT;
BEGIN
  SELECT * INTO v_cand FROM public.facility_candidates WHERE id = p_candidate_id;
  IF NOT FOUND OR v_cand.status <> 'pending' THEN
    RETURN QUERY SELECT 'rejected'::TEXT, NULL::UUID, NULL::UUID, 'not found or not pending'::TEXT;
    RETURN;
  END IF;

  -- バリデーション
  IF length(trim(v_cand.name)) < 2 THEN
    UPDATE public.facility_candidates SET status='rejected', rejection_reason='name too short', processed_at=NOW() WHERE id=p_candidate_id;
    RETURN QUERY SELECT 'rejected'::TEXT, NULL::UUID, NULL::UUID, 'name too short'::TEXT;
    RETURN;
  END IF;
  IF v_cand.latitude NOT BETWEEN 20 AND 46 OR v_cand.longitude NOT BETWEEN 122 AND 154 THEN
    UPDATE public.facility_candidates SET status='rejected', rejection_reason='invalid coordinates', processed_at=NOW() WHERE id=p_candidate_id;
    RETURN QUERY SELECT 'rejected'::TEXT, NULL::UUID, NULL::UUID, 'invalid coordinates'::TEXT;
    RETURN;
  END IF;

  -- 重複チェック（find_duplicate_facilities は p_lat NUMERIC 型）
  SELECT f.facility_id INTO v_dup_id
  FROM public.find_duplicate_facilities(v_cand.name, v_cand.latitude, v_cand.longitude, NULL) AS f
  LIMIT 1;

  IF v_dup_id IS NOT NULL THEN
    UPDATE public.facility_candidates SET status='duplicate', duplicate_of=v_dup_id, processed_at=NOW() WHERE id=p_candidate_id;
    IF v_cand.website IS NOT NULL THEN
      PERFORM public.apply_url_with_priority(v_dup_id, v_cand.website,
        CASE v_cand.source WHEN 'here' THEN 'here' ELSE 'official' END);
    END IF;
    RETURN QUERY SELECT 'duplicate'::TEXT, NULL::UUID, v_dup_id, 'duplicate found'::TEXT;
    RETURN;
  END IF;

  -- facility_type_id の解決（spa → public_bath にフォールバック）
  v_type_id := public.get_facility_type_id(
    CASE v_cand.facility_type
      WHEN 'onsen'       THEN 'onsen'
      WHEN 'sauna'       THEN 'sauna'
      WHEN 'public_bath' THEN 'public_bath'
      WHEN 'spa'         THEN 'public_bath'
      ELSE NULL
    END
  );

  -- url_source の CHECK 制約: official|yahoo_yolp|here|user_report|manual
  v_url_source := CASE v_cand.source
    WHEN 'here'   THEN 'here'
    WHEN 'osm'    THEN 'official'
    WHEN 'google' THEN 'official'
    ELSE 'manual'
  END;

  -- 新規INSERT
  INSERT INTO public.facilities (name, latitude, longitude, address, website, phone, facility_type_id, data_source)
  VALUES (trim(v_cand.name), v_cand.latitude::FLOAT, v_cand.longitude::FLOAT,
          v_cand.address, v_cand.website, v_cand.phone,
          v_type_id, v_cand.source)
  RETURNING id INTO v_new_id;

  INSERT INTO public.crawl_schedule (facility_id, official_site_url, priority, status, url_source)
  VALUES (v_new_id, v_cand.website, 5,
          CASE WHEN v_cand.website IS NOT NULL THEN 'pending' ELSE 'skipped' END,
          CASE WHEN v_cand.website IS NOT NULL THEN v_url_source ELSE NULL END)
  ON CONFLICT (facility_id) DO NOTHING;

  UPDATE public.facility_candidates SET status='promoted', promoted_facility_id=v_new_id, processed_at=NOW() WHERE id=p_candidate_id;
  RETURN QUERY SELECT 'promoted'::TEXT, v_new_id, NULL::UUID, NULL::TEXT;
END$$;
GRANT EXECUTE ON FUNCTION public.promote_candidate TO service_role;

-- バッチ昇格関数
CREATE OR REPLACE FUNCTION public.promote_candidates_batch(p_prefecture TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 500)
RETURNS TABLE (total INTEGER, promoted INTEGER, duplicate INTEGER, rejected INTEGER)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id UUID; v_outcome TEXT;
  v_total INT:=0; v_prom INT:=0; v_dup INT:=0; v_rej INT:=0;
BEGIN
  FOR v_id IN
    SELECT id FROM public.facility_candidates
    WHERE status='pending' AND (p_prefecture IS NULL OR prefecture=p_prefecture)
    ORDER BY collected_at ASC LIMIT p_limit
  LOOP
    v_total := v_total+1;
    SELECT outcome INTO v_outcome FROM public.promote_candidate(v_id);
    IF v_outcome='promoted' THEN v_prom:=v_prom+1;
    ELSIF v_outcome='duplicate' THEN v_dup:=v_dup+1;
    ELSE v_rej:=v_rej+1; END IF;
  END LOOP;
  RETURN QUERY SELECT v_total, v_prom, v_dup, v_rej;
END$$;
GRANT EXECUTE ON FUNCTION public.promote_candidates_batch TO service_role;
GRANT EXECUTE ON FUNCTION public.get_facility_type_id TO service_role;
