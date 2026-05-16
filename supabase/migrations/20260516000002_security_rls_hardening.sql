-- ============================================================
-- セキュリティ強化: RLS ポリシー精緻化 + ビュー修正
-- ============================================================

-- ① 内部テーブル（RLS有効・ポリシーなし）→ 明示的アクセス拒否
-- service_role は RLS をバイパスするため影響なし
CREATE POLICY deny_public_access ON public.api_usage_log
  FOR ALL USING (false) WITH CHECK (false);

CREATE POLICY deny_public_access ON public.ingest_dead_letters
  FOR ALL USING (false) WITH CHECK (false);

CREATE POLICY deny_public_access ON public.ingest_runs
  FOR ALL USING (false) WITH CHECK (false);

CREATE POLICY deny_public_access ON public.places_cache
  FOR ALL USING (false) WITH CHECK (false);

-- ② facility_mentions.facility_mentions_feedback:
--    USING/WITH CHECK が常に true → auth.uid() 存在チェックに変更
DROP POLICY IF EXISTS facility_mentions_feedback ON public.facility_mentions;
CREATE POLICY facility_mentions_feedback ON public.facility_mentions
  FOR UPDATE TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- ③ removal_requests.removal_requests_insert:
--    WITH CHECK が常に true → 未承認状態のみ挿入可に制限
DROP POLICY IF EXISTS removal_requests_insert ON public.removal_requests;
CREATE POLICY removal_requests_insert ON public.removal_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    status = 'pending'
    AND resolved_at IS NULL
    AND resolved_by IS NULL
  );

-- ④ facility_mention_counts ビュー: SECURITY DEFINER → SECURITY INVOKER
CREATE OR REPLACE VIEW public.facility_mention_counts
  WITH (security_invoker = true)
AS
  SELECT
    facility_id,
    count(*) FILTER (WHERE created_at >= (now() - '7 days'::interval))  AS mentions_7d,
    count(*) FILTER (WHERE created_at >= (now() - '30 days'::interval)) AS mentions_30d,
    count(*) AS mentions_total
  FROM facility_mentions
  GROUP BY facility_id;

-- ⑤ ストレージバケットのリスト取得制限
DROP POLICY IF EXISTS "post-images: public read by path" ON storage.objects;
CREATE POLICY "post-images: public read objects only"
  ON storage.objects FOR SELECT TO public
  USING (
    bucket_id = 'post-images'
    AND name NOT LIKE '%/'
    AND (storage.foldername(name))[1] IS NOT NULL
  );

DROP POLICY IF EXISTS "post_media_select" ON storage.objects;
CREATE POLICY "post_media_select: public read objects only"
  ON storage.objects FOR SELECT TO public
  USING (
    bucket_id = 'post-media'
    AND name NOT LIKE '%/'
    AND (storage.foldername(name))[1] IS NOT NULL
  );
