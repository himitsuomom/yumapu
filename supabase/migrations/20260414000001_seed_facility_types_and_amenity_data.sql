-- ============================================================
-- 施設タイプシード + アメニティデータ一括投入
-- 2026-04-14
--
-- 修正内容:
-- 1. facility_types が空でフィルターが機能しない問題を修正
-- 2. facility_amenities が空でアメニティフィルターが無効な問題を修正
-- 3. sync_facility_location トリガー関数の search_path を修正
-- ============================================================

-- ─────────────────────────────────────
-- 0. sync_facility_location トリガー関数の search_path 修正
--    (geography型の解決に extensions スキーマを含める)
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_facility_location()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, extensions
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

-- ─────────────────────────────────────
-- 1. facility_types シード
-- ─────────────────────────────────────
INSERT INTO facility_types (code, name_ja, name_en)
VALUES
  ('onsen',       '温泉施設',       'Onsen'),
  ('public_bath', '銭湯・公衆浴場', 'Public Bath'),
  ('sauna',       'サウナ',         'Sauna')
ON CONFLICT (code) DO NOTHING;

-- ─────────────────────────────────────
-- 2. facilities.facility_type_id を type VARCHAR から自動設定
--    (トリガーが geography型を使うため一時的に無効化)
-- ─────────────────────────────────────
ALTER TABLE facilities DISABLE TRIGGER trg_sync_facility_location;

UPDATE facilities f
SET facility_type_id = ft.id
FROM facility_types ft
WHERE f.type = ft.code
  AND f.facility_type_id IS NULL;

ALTER TABLE facilities ENABLE TRIGGER trg_sync_facility_location;

-- ─────────────────────────────────────
-- 3. アメニティデータ投入
--    UNIQUE(facility_id, amenity_id) なので ON CONFLICT DO NOTHING で安全
-- ─────────────────────────────────────

-- 3-1. natural_hot_spring: type=onsen の全施設（約4,289件）
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 70
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'natural_hot_spring'
  AND f.type = 'onsen'
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-2. サウナ: type=sauna の全施設
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 85
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'sauna'
  AND f.type = 'sauna'
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-3. 硫黄泉: 施設名に「硫黄」「硫化」「いおう」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'sulfur_spring'
  AND (f.name ILIKE '%硫黄%' OR f.name ILIKE '%硫化%' OR f.name ILIKE '%いおう%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-4. 炭酸水素塩泉: 施設名に「炭酸」「重曹」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'bicarbonate_spring'
  AND (f.name ILIKE '%炭酸%' OR f.name ILIKE '%重曹%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-5. 塩化物泉: 施設名に「食塩」「塩化物」「塩泉」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'chloride_spring'
  AND (f.name ILIKE '%食塩%' OR f.name ILIKE '%塩化物%' OR f.name ILIKE '%塩泉%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-6. 硫酸塩泉: 施設名に「硫酸」「芒硝」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'sulfate_spring'
  AND (f.name ILIKE '%硫酸%' OR f.name ILIKE '%芒硝%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-7. 含鉄泉: 施設名に「含鉄」「鉄泉」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'iron_spring'
  AND (f.name ILIKE '%含鉄%' OR f.name ILIKE '%鉄泉%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-8. 酸性泉: 施設名に「酸性」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'acidic_spring'
  AND f.name ILIKE '%酸性%'
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-9. 放射能泉: 施設名に「ラジウム」「ラドン」「放射能」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'radioactive_spring'
  AND (f.name ILIKE '%ラジウム%' OR f.name ILIKE '%ラドン%' OR f.name ILIKE '%放射能%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-10. 単純温泉（デフォルト）: type=onsen で泉質が未付与の施設
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 50
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'simple_hot_spring'
  AND f.type = 'onsen'
  AND NOT EXISTS (
    SELECT 1
    FROM facility_amenities fa2
    JOIN amenities a2 ON fa2.amenity_id = a2.id
    WHERE fa2.facility_id = f.id
      AND a2.category = 'spring_type'
  )
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-11. 露天風呂: 施設名に「露天」「野天」「外湯」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'outdoor_bath'
  AND (f.name ILIKE '%露天%' OR f.name ILIKE '%野天%' OR f.name ILIKE '%外湯%')
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-12. 宿泊施設: 施設名に「旅館」「ホテル」「民宿」「ロッジ」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'lodging'
  AND (
    f.name ILIKE '%旅館%'
    OR f.name ILIKE '%ホテル%'
    OR f.name ILIKE '%民宿%'
    OR f.name ILIKE '%ロッジ%'
  )
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-13. 混浴: 施設名に「混浴」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'mixed_bath'
  AND f.name ILIKE '%混浴%'
ON CONFLICT (facility_id, amenity_id) DO NOTHING;

-- 3-14. 岩盤浴: 施設名に「岩盤浴」を含む
INSERT INTO facility_amenities (facility_id, amenity_id, value, confidence_score)
SELECT f.id, a.id, 'true', 65
FROM facilities f
CROSS JOIN amenities a
WHERE a.code = 'stone_sauna'
  AND f.name ILIKE '%岩盤浴%'
ON CONFLICT (facility_id, amenity_id) DO NOTHING;
