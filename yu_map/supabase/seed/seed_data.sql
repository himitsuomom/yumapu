-- Seed data for Yu-Map
-- Run after migrations: psql -f seed_data.sql

-- ============================================================
-- PREFECTURES (47 prefectures)
-- ============================================================
INSERT INTO prefectures (name, name_en, region) VALUES
  ('北海道', 'Hokkaido', '北海道'),
  ('青森県', 'Aomori', '東北'),
  ('岩手県', 'Iwate', '東北'),
  ('宮城県', 'Miyagi', '東北'),
  ('秋田県', 'Akita', '東北'),
  ('山形県', 'Yamagata', '東北'),
  ('福島県', 'Fukushima', '東北'),
  ('茨城県', 'Ibaraki', '関東'),
  ('栃木県', 'Tochigi', '関東'),
  ('群馬県', 'Gunma', '関東'),
  ('埼玉県', 'Saitama', '関東'),
  ('千葉県', 'Chiba', '関東'),
  ('東京都', 'Tokyo', '関東'),
  ('神奈川県', 'Kanagawa', '関東'),
  ('新潟県', 'Niigata', '中部'),
  ('富山県', 'Toyama', '中部'),
  ('石川県', 'Ishikawa', '中部'),
  ('福井県', 'Fukui', '中部'),
  ('山梨県', 'Yamanashi', '中部'),
  ('長野県', 'Nagano', '中部'),
  ('岐阜県', 'Gifu', '中部'),
  ('静岡県', 'Shizuoka', '中部'),
  ('愛知県', 'Aichi', '中部'),
  ('三重県', 'Mie', '近畿'),
  ('滋賀県', 'Shiga', '近畿'),
  ('京都府', 'Kyoto', '近畿'),
  ('大阪府', 'Osaka', '近畿'),
  ('兵庫県', 'Hyogo', '近畿'),
  ('奈良県', 'Nara', '近畿'),
  ('和歌山県', 'Wakayama', '近畿'),
  ('鳥取県', 'Tottori', '中国'),
  ('島根県', 'Shimane', '中国'),
  ('岡山県', 'Okayama', '中国'),
  ('広島県', 'Hiroshima', '中国'),
  ('山口県', 'Yamaguchi', '中国'),
  ('徳島県', 'Tokushima', '四国'),
  ('香川県', 'Kagawa', '四国'),
  ('愛媛県', 'Ehime', '四国'),
  ('高知県', 'Kochi', '四国'),
  ('福岡県', 'Fukuoka', '九州'),
  ('佐賀県', 'Saga', '九州'),
  ('長崎県', 'Nagasaki', '九州'),
  ('熊本県', 'Kumamoto', '九州'),
  ('大分県', 'Oita', '九州'),
  ('宮崎県', 'Miyazaki', '九州'),
  ('鹿児島県', 'Kagoshima', '九州'),
  ('沖縄県', 'Okinawa', '九州')
ON CONFLICT DO NOTHING;

-- ============================================================
-- FACILITY TYPES
-- ============================================================
INSERT INTO facility_types (code, name_ja, name_en) VALUES
  ('onsen', '温泉', 'Hot Spring'),
  ('sento', '銭湯', 'Public Bath'),
  ('super_sento', 'スーパー銭湯', 'Super Public Bath'),
  ('sauna', 'サウナ専門', 'Sauna Facility'),
  ('ryokan', '旅館', 'Japanese Inn'),
  ('hotel', 'ホテル', 'Hotel'),
  ('day_spa', '日帰り温泉', 'Day Spa'),
  ('foot_bath', '足湯', 'Foot Bath')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- BADGES
-- ============================================================
INSERT INTO badges (code, name_ja, name_en, description_ja, category) VALUES
  ('first_visit',   '初めての湯',   'First Visit',     '初めて施設にチェックインしました', 'explorer'),
  ('explorer_10',   '湯めぐり10',   'Explorer 10',     '10ヶ所の施設に訪問しました',       'explorer'),
  ('explorer_50',   '湯めぐり50',   'Explorer 50',     '50ヶ所の施設に訪問しました',       'explorer'),
  ('explorer_100',  '湯マスター',   'Explorer 100',    '100ヶ所の施設に訪問しました',      'explorer'),
  ('first_review',  '初レビュー',   'First Review',    '初めてレビューを投稿しました',     'social'),
  ('reviewer_10',   'レビュー達人',  'Reviewer 10',    '10件のレビューを投稿しました',     'social'),
  ('reviewer_50',   'レビューマスター', 'Reviewer 50', '50件のレビューを投稿しました',     'social'),
  ('all_prefectures', '全国制覇',   'All Prefectures', '全47都道府県の施設を訪問しました', 'special')
ON CONFLICT (code) DO NOTHING;
