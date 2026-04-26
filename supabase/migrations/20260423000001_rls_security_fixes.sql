-- ============================================================
-- RLS セキュリティ修正
-- 2026-04-23
--
-- 修正内容:
-- 1. visits テーブルに RLS を有効化 + SELECT/INSERT ポリシー追加
--    ※ DELETE ポリシーは 20260414000003 で追加済み
-- 2. facility_reports テーブルに RLS を有効化 + ポリシー追加
-- 3. facility_amenities テーブルに RLS を有効化 + INSERT ポリシー追加
-- 4. photos ストレージの SELECT ポリシーを追加
-- ============================================================

-- ─────────────────────────────────────
-- 1. visits テーブルの RLS 設定
-- ─────────────────────────────────────

ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

-- 自分の訪問記録のみ閲覧可能（他ユーザーの訪問は見えない）
DROP POLICY IF EXISTS "Users can view own visits" ON visits;
CREATE POLICY "Users can view own visits"
  ON visits FOR SELECT
  USING (auth.uid() = user_id);

-- ログイン済みユーザーが自分のIDで訪問記録を追加できる
DROP POLICY IF EXISTS "Users can insert own visits" ON visits;
CREATE POLICY "Users can insert own visits"
  ON visits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE ポリシー（メモや評価の更新を自分の記録のみ許可）
DROP POLICY IF EXISTS "Users can update own visits" ON visits;
CREATE POLICY "Users can update own visits"
  ON visits FOR UPDATE
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────
-- 2. facility_reports テーブルの RLS 設定
-- ─────────────────────────────────────

ALTER TABLE facility_reports ENABLE ROW LEVEL SECURITY;

-- 自分が提出した報告のみ閲覧可能（他ユーザーの報告は見えない）
DROP POLICY IF EXISTS "Users can view own facility reports" ON facility_reports;
CREATE POLICY "Users can view own facility reports"
  ON facility_reports FOR SELECT
  USING (auth.uid() = user_id);

-- ログイン済みユーザーが報告を提出できる（自分のuser_id必須）
DROP POLICY IF EXISTS "Users can insert facility reports" ON facility_reports;
CREATE POLICY "Users can insert facility reports"
  ON facility_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 管理者（admin ロール）は全報告を閲覧・管理できる
-- 注意: Supabase の service_role を使う場合は RLS をバイパスするため不要だが
--       Dashboard でのデータ閲覧のために残す
DROP POLICY IF EXISTS "Admins can view all facility reports" ON facility_reports;
CREATE POLICY "Admins can view all facility reports"
  ON facility_reports FOR SELECT
  USING (
    auth.jwt() ->> 'role' = 'admin'
  );

-- ─────────────────────────────────────
-- 3. facility_amenities テーブルの RLS 設定
-- ─────────────────────────────────────

ALTER TABLE facility_amenities ENABLE ROW LEVEL SECURITY;

-- 誰でも閲覧可能（施設のアメニティ情報はパブリック）
-- ※ すでに POLICY が存在するため DROP IF EXISTS してから再作成
DROP POLICY IF EXISTS "Facility amenities are viewable by everyone" ON facility_amenities;
CREATE POLICY "Facility amenities are viewable by everyone"
  ON facility_amenities FOR SELECT
  USING (true);

-- INSERT は認証済みユーザー（施設オーナー・管理者）のみ
-- 通常ユーザーはINSERTできないよう制限する
DROP POLICY IF EXISTS "Authenticated users cannot insert facility amenities" ON facility_amenities;
-- 管理者（service_role）のみ INSERT を許可する。
-- 一般ユーザーからの INSERT はデフォルトで拒否される（ポリシーなし = 拒否）。
-- オーナーが更新する場合はサーバーサイド関数（Edge Function）経由で行う想定。

-- ─────────────────────────────────────
-- 4. photos バケット SELECT ポリシーを追加
-- ─────────────────────────────────────

-- facility写真: URL を知っていれば誰でも読める（パブリック用途）
DROP POLICY IF EXISTS "photos: public read by path" ON storage.objects;
CREATE POLICY "photos: public read by path"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'photos');

-- facility写真: 認証済みユーザーがアップロードできる
DROP POLICY IF EXISTS "photos: authenticated upload" ON storage.objects;
CREATE POLICY "photos: authenticated upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'photos'
    AND auth.role() = 'authenticated'
  );

-- facility写真: 自分がアップロードした写真のみ削除可能
-- パス形式: facilities/{facilityId}/{uuid}.{ext}
-- storage.objects の owner は INSERT 時に auth.uid() が自動設定される
DROP POLICY IF EXISTS "photos: owner can delete" ON storage.objects;
CREATE POLICY "photos: owner can delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'photos'
    AND owner = auth.uid()
  );
