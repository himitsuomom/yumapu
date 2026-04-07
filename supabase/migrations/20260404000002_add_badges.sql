-- Migration: バッジシステム RLS + シードデータ + 泉質アメニティ追加
-- 前提: badges / user_badges テーブルは初期スキーマ済み

-- ============================================================
-- 1. RLS 有効化
-- ============================================================
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

-- badges: 全員が読める
CREATE POLICY "Badges are viewable by everyone"
  ON badges FOR SELECT USING (true);

-- user_badges: 全員が読める（社会的機能のため）
CREATE POLICY "User badges are viewable by everyone"
  ON user_badges FOR SELECT USING (true);

-- user_badges: 自分のバッジのみ付与可能
CREATE POLICY "Users can earn badges"
  ON user_badges FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- user_badges: 削除不可（バッジは剥奪しない）
CREATE POLICY "Badges cannot be revoked"
  ON user_badges FOR DELETE USING (false);

-- ============================================================
-- 2. 泉質アメニティをシード
-- ============================================================
INSERT INTO amenities (code, name_ja, name_en, category, value_type) VALUES
  ('simple_hot_spring',    '単純温泉',       'Simple Hot Spring',    'spring_type', 'boolean'),
  ('bicarbonate_spring',   '炭酸水素塩泉',   'Bicarbonate Spring',   'spring_type', 'boolean'),
  ('chloride_spring',      '塩化物泉',       'Chloride Spring',      'spring_type', 'boolean'),
  ('sulfate_spring',       '硫酸塩泉',       'Sulfate Spring',       'spring_type', 'boolean'),
  ('sulfur_spring',        '硫黄泉',         'Sulfur Spring',        'spring_type', 'boolean'),
  ('radioactive_spring',   '放射能泉',       'Radioactive Spring',   'spring_type', 'boolean'),
  ('acidic_spring',        '酸性泉',         'Acidic Spring',        'spring_type', 'boolean'),
  ('iron_spring',          '含鉄泉',         'Iron Spring',          'spring_type', 'boolean')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 3. バッジシードデータ
-- ============================================================

-- ▼ マイルストーンバッジ
INSERT INTO badges (code, name_ja, name_en, description_ja, category, requirements) VALUES
  ('first_visit',  '初めての一湯',    'First Spring',    '初めて温泉施設に訪問しました',                   'milestone', '{"type":"visit_count","count":1}'),
  ('visit_10',     '湯めぐり10湯',    '10 Springs',      '10か所の温泉施設を訪問しました',                 'milestone', '{"type":"visit_count","count":10}'),
  ('visit_50',     '湯めぐり50湯',    '50 Springs',      '50か所の温泉施設を訪問しました',                 'milestone', '{"type":"visit_count","count":50}'),
  ('visit_100',    '湯めぐり100湯',   '100 Springs',     '100か所の温泉施設を訪問しました',                'milestone', '{"type":"visit_count","count":100}'),
  ('visit_1000',   '湯めぐり1000湯',  '1000 Springs',    '1000か所の温泉施設を訪問しました（温泉王！）',   'milestone', '{"type":"visit_count","count":1000}')
ON CONFLICT (code) DO NOTHING;

-- ▼ 都道府県バッジ（47都道府県）
INSERT INTO badges (code, name_ja, name_en, description_ja, category, requirements) VALUES
  ('pref_hokkaido',   '北海道制覇',   'Hokkaido',   '北海道の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"北海道"}'),
  ('pref_aomori',     '青森制覇',     'Aomori',     '青森県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"青森県"}'),
  ('pref_iwate',      '岩手制覇',     'Iwate',      '岩手県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"岩手県"}'),
  ('pref_miyagi',     '宮城制覇',     'Miyagi',     '宮城県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"宮城県"}'),
  ('pref_akita',      '秋田制覇',     'Akita',      '秋田県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"秋田県"}'),
  ('pref_yamagata',   '山形制覇',     'Yamagata',   '山形県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"山形県"}'),
  ('pref_fukushima',  '福島制覇',     'Fukushima',  '福島県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"福島県"}'),
  ('pref_ibaraki',    '茨城制覇',     'Ibaraki',    '茨城県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"茨城県"}'),
  ('pref_tochigi',    '栃木制覇',     'Tochigi',    '栃木県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"栃木県"}'),
  ('pref_gunma',      '群馬制覇',     'Gunma',      '群馬県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"群馬県"}'),
  ('pref_saitama',    '埼玉制覇',     'Saitama',    '埼玉県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"埼玉県"}'),
  ('pref_chiba',      '千葉制覇',     'Chiba',      '千葉県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"千葉県"}'),
  ('pref_tokyo',      '東京制覇',     'Tokyo',      '東京都の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"東京都"}'),
  ('pref_kanagawa',   '神奈川制覇',   'Kanagawa',   '神奈川県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"神奈川県"}'),
  ('pref_niigata',    '新潟制覇',     'Niigata',    '新潟県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"新潟県"}'),
  ('pref_toyama',     '富山制覇',     'Toyama',     '富山県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"富山県"}'),
  ('pref_ishikawa',   '石川制覇',     'Ishikawa',   '石川県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"石川県"}'),
  ('pref_fukui',      '福井制覇',     'Fukui',      '福井県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"福井県"}'),
  ('pref_yamanashi',  '山梨制覇',     'Yamanashi',  '山梨県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"山梨県"}'),
  ('pref_nagano',     '長野制覇',     'Nagano',     '長野県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"長野県"}'),
  ('pref_gifu',       '岐阜制覇',     'Gifu',       '岐阜県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"岐阜県"}'),
  ('pref_shizuoka',   '静岡制覇',     'Shizuoka',   '静岡県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"静岡県"}'),
  ('pref_aichi',      '愛知制覇',     'Aichi',      '愛知県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"愛知県"}'),
  ('pref_mie',        '三重制覇',     'Mie',        '三重県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"三重県"}'),
  ('pref_shiga',      '滋賀制覇',     'Shiga',      '滋賀県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"滋賀県"}'),
  ('pref_kyoto',      '京都制覇',     'Kyoto',      '京都府の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"京都府"}'),
  ('pref_osaka',      '大阪制覇',     'Osaka',      '大阪府の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"大阪府"}'),
  ('pref_hyogo',      '兵庫制覇',     'Hyogo',      '兵庫県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"兵庫県"}'),
  ('pref_nara',       '奈良制覇',     'Nara',       '奈良県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"奈良県"}'),
  ('pref_wakayama',   '和歌山制覇',   'Wakayama',   '和歌山県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"和歌山県"}'),
  ('pref_tottori',    '鳥取制覇',     'Tottori',    '鳥取県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"鳥取県"}'),
  ('pref_shimane',    '島根制覇',     'Shimane',    '島根県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"島根県"}'),
  ('pref_okayama',    '岡山制覇',     'Okayama',    '岡山県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"岡山県"}'),
  ('pref_hiroshima',  '広島制覇',     'Hiroshima',  '広島県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"広島県"}'),
  ('pref_yamaguchi',  '山口制覇',     'Yamaguchi',  '山口県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"山口県"}'),
  ('pref_tokushima',  '徳島制覇',     'Tokushima',  '徳島県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"徳島県"}'),
  ('pref_kagawa',     '香川制覇',     'Kagawa',     '香川県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"香川県"}'),
  ('pref_ehime',      '愛媛制覇',     'Ehime',      '愛媛県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"愛媛県"}'),
  ('pref_kochi',      '高知制覇',     'Kochi',      '高知県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"高知県"}'),
  ('pref_fukuoka',    '福岡制覇',     'Fukuoka',    '福岡県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"福岡県"}'),
  ('pref_saga',       '佐賀制覇',     'Saga',       '佐賀県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"佐賀県"}'),
  ('pref_nagasaki',   '長崎制覇',     'Nagasaki',   '長崎県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"長崎県"}'),
  ('pref_kumamoto',   '熊本制覇',     'Kumamoto',   '熊本県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"熊本県"}'),
  ('pref_oita',       '大分制覇',     'Oita',       '大分県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"大分県"}'),
  ('pref_miyazaki',   '宮崎制覇',     'Miyazaki',   '宮崎県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"宮崎県"}'),
  ('pref_kagoshima',  '鹿児島制覇',   'Kagoshima',  '鹿児島県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"鹿児島県"}'),
  ('pref_okinawa',    '沖縄制覇',     'Okinawa',    '沖縄県の温泉施設を訪問しました', 'prefecture', '{"type":"prefecture","name":"沖縄県"}')
ON CONFLICT (code) DO NOTHING;

-- ▼ 泉質コンプリートバッジ
INSERT INTO badges (code, name_ja, name_en, description_ja, category, requirements) VALUES
  ('spring_simple',       '単純温泉マスター',     'Simple Spring Master',     '単純温泉の施設を訪問しました',     'spring_type', '{"type":"spring_type","spring_code":"simple_hot_spring"}'),
  ('spring_bicarbonate',  '炭酸水素塩泉マスター', 'Bicarbonate Spring Master', '炭酸水素塩泉の施設を訪問しました', 'spring_type', '{"type":"spring_type","spring_code":"bicarbonate_spring"}'),
  ('spring_chloride',     '塩化物泉マスター',     'Chloride Spring Master',   '塩化物泉の施設を訪問しました',     'spring_type', '{"type":"spring_type","spring_code":"chloride_spring"}'),
  ('spring_sulfate',      '硫酸塩泉マスター',     'Sulfate Spring Master',    '硫酸塩泉の施設を訪問しました',     'spring_type', '{"type":"spring_type","spring_code":"sulfate_spring"}'),
  ('spring_sulfur',       '硫黄泉マスター',       'Sulfur Spring Master',     '硫黄泉の施設を訪問しました',       'spring_type', '{"type":"spring_type","spring_code":"sulfur_spring"}'),
  ('spring_radioactive',  '放射能泉マスター',     'Radioactive Spring Master','放射能泉の施設を訪問しました',     'spring_type', '{"type":"spring_type","spring_code":"radioactive_spring"}'),
  ('spring_acidic',       '酸性泉マスター',       'Acidic Spring Master',     '酸性泉の施設を訪問しました',       'spring_type', '{"type":"spring_type","spring_code":"acidic_spring"}'),
  ('spring_iron',         '含鉄泉マスター',       'Iron Spring Master',       '含鉄泉の施設を訪問しました',       'spring_type', '{"type":"spring_type","spring_code":"iron_spring"}'),
  ('spring_all',          '泉質コンプリート',     'Spring Type Master',       '全8種類の泉質を制覇しました',       'spring_type', '{"type":"spring_all","count":8}')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 4. バッジ自動付与関数
-- ============================================================

-- ユーザー統計取得関数
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visit_count     INT;
  v_prefecture_count INT;
  v_badge_count     INT;
BEGIN
  SELECT COUNT(*)              INTO v_visit_count      FROM visits       WHERE user_id = p_user_id;
  SELECT COUNT(DISTINCT f.prefecture_id)
                               INTO v_prefecture_count
    FROM visits v
    JOIN facilities f ON v.facility_id = f.id
   WHERE v.user_id = p_user_id;
  SELECT COUNT(*)              INTO v_badge_count      FROM user_badges  WHERE user_id = p_user_id;

  RETURN json_build_object(
    'visit_count',      v_visit_count,
    'prefecture_count', v_prefecture_count,
    'badge_count',      v_badge_count
  );
END;
$$;

-- バッジ条件チェック & 付与関数（SECURITY DEFINER でRLSをバイパスして挿入）
CREATE OR REPLACE FUNCTION check_and_grant_badges(p_user_id UUID)
RETURNS SETOF TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visit_count        INT;
  v_badge              RECORD;
  v_spring_type_count  INT;
BEGIN
  -- 訪問数取得
  SELECT COUNT(*) INTO v_visit_count FROM visits WHERE user_id = p_user_id;

  -- ▼ マイルストーンバッジ判定
  FOR v_badge IN SELECT * FROM badges WHERE category = 'milestone' LOOP
    IF v_visit_count >= (v_badge.requirements->>'count')::INT THEN
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (p_user_id, v_badge.id)
      ON CONFLICT (user_id, badge_id) DO NOTHING;

      IF FOUND THEN
        RETURN NEXT v_badge.code;
      END IF;
    END IF;
  END LOOP;

  -- ▼ 都道府県バッジ判定
  FOR v_badge IN SELECT * FROM badges WHERE category = 'prefecture' LOOP
    IF EXISTS (
      SELECT 1
        FROM visits v
        JOIN facilities f  ON v.facility_id  = f.id
        JOIN prefectures p ON f.prefecture_id = p.id
       WHERE v.user_id = p_user_id
         AND p.name    = v_badge.requirements->>'name'
    ) THEN
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (p_user_id, v_badge.id)
      ON CONFLICT (user_id, badge_id) DO NOTHING;

      IF FOUND THEN
        RETURN NEXT v_badge.code;
      END IF;
    END IF;
  END LOOP;

  -- ▼ 泉質バッジ判定（個別）
  FOR v_badge IN SELECT * FROM badges WHERE category = 'spring_type' AND code != 'spring_all' LOOP
    IF EXISTS (
      SELECT 1
        FROM visits v
        JOIN facilities      f  ON v.facility_id = f.id
        JOIN facility_amenities fa ON f.id = fa.facility_id
        JOIN amenities       a  ON fa.amenity_id  = a.id
       WHERE v.user_id  = p_user_id
         AND a.code     = v_badge.requirements->>'spring_code'
         AND a.category = 'spring_type'
         AND fa.value   = 'true'
    ) THEN
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (p_user_id, v_badge.id)
      ON CONFLICT (user_id, badge_id) DO NOTHING;

      IF FOUND THEN
        RETURN NEXT v_badge.code;
      END IF;
    END IF;
  END LOOP;

  -- ▼ 全泉質コンプリートバッジ（spring_all）
  SELECT COUNT(DISTINCT a.code) INTO v_spring_type_count
    FROM visits v
    JOIN facilities      f  ON v.facility_id = f.id
    JOIN facility_amenities fa ON f.id = fa.facility_id
    JOIN amenities       a  ON fa.amenity_id = a.id
   WHERE v.user_id  = p_user_id
     AND a.category = 'spring_type'
     AND fa.value   = 'true';

  IF v_spring_type_count >= 8 THEN
    INSERT INTO user_badges (user_id, badge_id)
    SELECT p_user_id, b.id FROM badges b WHERE b.code = 'spring_all'
    ON CONFLICT (user_id, badge_id) DO NOTHING;

    IF FOUND THEN
      RETURN NEXT 'spring_all';
    END IF;
  END IF;
END;
$$;

-- ============================================================
-- 5. チェックイン時にバッジ付与トリガー
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_badge_check()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM check_and_grant_badges(NEW.user_id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_visit_badge_check
  AFTER INSERT ON visits
  FOR EACH ROW
  EXECUTE FUNCTION trigger_badge_check();
