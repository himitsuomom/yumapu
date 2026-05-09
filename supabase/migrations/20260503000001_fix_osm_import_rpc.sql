-- ============================================================
-- OSMインポート修正: trigger + batch_upsert RPC
-- ============================================================
-- 背景:
--   sync_facility_location() トリガーが SET search_path なしで定義されており、
--   PostGIS が extensions スキーマにある環境で ::geography キャストが解決できず
--   batch_upsert_osm_facilities RPC 内の INSERT が全件 EXCEPTION に
--   落ちて 0 件挿入されていた。
--
-- 修正:
--   1. sync_facility_location() に SET search_path = extensions, public を追加
--   2. batch_upsert_osm_facilities を再作成:
--      - location カラムを明示的に INSERT（trigger 依存を排除）
--      - facility_type_id を INSERT に追加
--      - EXCEPTION メッセージを last_error フィールドで返すよう改善
-- ============================================================

-- 1. トリガー関数を search_path 付きで再定義
CREATE OR REPLACE FUNCTION public.sync_facility_location()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = extensions, public
AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location = ST_SetSRID(
      ST_MakePoint(NEW.longitude, NEW.latitude),
      4326
    )::geography;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. batch_upsert_osm_facilities を再作成
--    - location を明示的に設定（trigger のフォールバックとして機能）
--    - facility_type_id を受け付ける
--    - last_error フィールドを返して問題診断を可能にする
CREATE OR REPLACE FUNCTION public.batch_upsert_osm_facilities(records jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public
AS $$
DECLARE
  rec         jsonb;
  inserted    int := 0;
  skipped     int := 0;
  last_error  text := null;
BEGIN
  FOR rec IN SELECT * FROM jsonb_array_elements(records)
  LOOP
    BEGIN
      INSERT INTO public.facilities (
        name,
        name_kana,
        latitude,
        longitude,
        location,
        address,
        phone,
        website,
        osm_id,
        type,
        hours,
        price,
        data_source,
        data_quality_score,
        is_open,
        facility_type_id
      )
      VALUES (
        rec->>'name',
        rec->>'name_kana',
        (rec->>'latitude')::double precision,
        (rec->>'longitude')::double precision,
        -- location を明示的に計算（トリガーも同じ処理をするが二重安全のため）
        ST_SetSRID(
          ST_MakePoint(
            (rec->>'longitude')::double precision,
            (rec->>'latitude')::double precision
          ),
          4326
        )::geography,
        rec->>'address',
        rec->>'phone',
        rec->>'website',
        rec->>'osm_id',
        rec->>'type',
        rec->>'hours',
        (rec->>'price')::integer,
        COALESCE(rec->>'data_source', 'osm'),
        COALESCE((rec->>'data_quality_score')::integer, 2),
        COALESCE((rec->>'is_open')::boolean, true),
        (rec->>'facility_type_id')::uuid
      )
      ON CONFLICT (osm_id) DO UPDATE SET
        name               = EXCLUDED.name,
        latitude           = EXCLUDED.latitude,
        longitude          = EXCLUDED.longitude,
        location           = EXCLUDED.location,
        address            = COALESCE(EXCLUDED.address, public.facilities.address),
        phone              = COALESCE(EXCLUDED.phone,   public.facilities.phone),
        website            = COALESCE(EXCLUDED.website, public.facilities.website),
        hours              = COALESCE(EXCLUDED.hours,   public.facilities.hours),
        price              = COALESCE(EXCLUDED.price,   public.facilities.price),
        data_quality_score = EXCLUDED.data_quality_score,
        facility_type_id   = COALESCE(EXCLUDED.facility_type_id, public.facilities.facility_type_id),
        updated_at         = NOW();

      inserted := inserted + 1;

    EXCEPTION WHEN OTHERS THEN
      skipped    := skipped + 1;
      last_error := SQLERRM;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'inserted',   inserted,
    'skipped',    skipped,
    'last_error', last_error
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.batch_upsert_osm_facilities(jsonb) TO service_role;
