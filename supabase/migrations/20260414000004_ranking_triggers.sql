-- ============================================================
-- ランキング自動更新トリガー
-- 2026-04-14
--
-- 修正内容:
-- チェックイン・レビュー投稿・SNS投稿時に user_rankings を自動更新する。
-- これがないとランキング機能が全く動作しない。
--
-- ポイント設計:
--   explorer_points = 訪問数 × 100
--   social_points   = レビュー数 × 50 + 投稿数 × 30
--   total_points    = explorer_points + social_points (GENERATED列で自動計算済み)
-- ============================================================

-- ─────────────────────────────────────
-- ① 社会ポイント再計算ヘルパー
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.calc_social_points(p_user_id UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE((SELECT COUNT(*) FROM public.reviews WHERE user_id = p_user_id), 0) * 50
    + COALESCE((SELECT COUNT(*) FROM public.posts WHERE user_id = p_user_id), 0) * 30
$$;

-- ─────────────────────────────────────
-- ② 訪問時のランキング更新
--    初訪問時はレコードを新規作成（UPSERT）
--    称号は訪問数に応じて自動更新
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_ranking_on_visit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visit_count INT;
  v_title TEXT;
BEGIN
  SELECT COUNT(*) INTO v_visit_count
  FROM public.visits
  WHERE user_id = NEW.user_id;

  v_title := CASE
    WHEN v_visit_count >= 1000 THEN '湯めぐり王'
    WHEN v_visit_count >= 500  THEN '温泉マスター'
    WHEN v_visit_count >= 200  THEN '温泉上級者'
    WHEN v_visit_count >= 100  THEN '温泉愛好家'
    WHEN v_visit_count >= 50   THEN '温泉通'
    WHEN v_visit_count >= 20   THEN '湯めぐり中級者'
    WHEN v_visit_count >= 10   THEN '湯めぐり経験者'
    WHEN v_visit_count >= 5    THEN '湯めぐり見習い'
    ELSE                            '湯めぐり初心者'
  END;

  INSERT INTO public.user_rankings (
    user_id, explorer_points, visit_count, current_title, updated_at
  )
  VALUES (
    NEW.user_id, v_visit_count * 100, v_visit_count, v_title, NOW()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET
      explorer_points = EXCLUDED.explorer_points,
      visit_count     = EXCLUDED.visit_count,
      current_title   = EXCLUDED.current_title,
      updated_at      = NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_ranking_on_visit ON public.visits;
CREATE TRIGGER trg_update_ranking_on_visit
  AFTER INSERT ON public.visits
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ranking_on_visit();

-- ─────────────────────────────────────
-- ③ レビュー投稿時のランキング更新
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_ranking_on_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_review_count INT;
BEGIN
  SELECT COUNT(*) INTO v_review_count FROM public.reviews WHERE user_id = NEW.user_id;

  INSERT INTO public.user_rankings (user_id, social_points, review_count, updated_at)
  VALUES (NEW.user_id, public.calc_social_points(NEW.user_id), v_review_count, NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET
      social_points = public.calc_social_points(NEW.user_id),
      review_count  = EXCLUDED.review_count,
      updated_at    = NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_ranking_on_review ON public.reviews;
CREATE TRIGGER trg_update_ranking_on_review
  AFTER INSERT ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ranking_on_review();

-- ─────────────────────────────────────
-- ④ SNS投稿時のランキング更新
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_ranking_on_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_rankings (user_id, social_points, updated_at)
  VALUES (NEW.user_id, public.calc_social_points(NEW.user_id), NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET
      social_points = public.calc_social_points(NEW.user_id),
      updated_at    = NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_ranking_on_post ON public.posts;
CREATE TRIGGER trg_update_ranking_on_post
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ranking_on_post();

-- ─────────────────────────────────────
-- ⑤ 訪問削除時のランキング再計算
--    deleteVisit() 後に visit_count / explorer_points が古い値になるバグを修正
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_ranking_on_visit_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visit_count INT;
  v_title TEXT;
BEGIN
  SELECT COUNT(*) INTO v_visit_count
  FROM public.visits
  WHERE user_id = OLD.user_id;

  v_title := CASE
    WHEN v_visit_count >= 1000 THEN '湯めぐり王'
    WHEN v_visit_count >= 500  THEN '温泉マスター'
    WHEN v_visit_count >= 200  THEN '温泉上級者'
    WHEN v_visit_count >= 100  THEN '温泉愛好家'
    WHEN v_visit_count >= 50   THEN '温泉通'
    WHEN v_visit_count >= 20   THEN '湯めぐり中級者'
    WHEN v_visit_count >= 10   THEN '湯めぐり経験者'
    WHEN v_visit_count >= 5    THEN '湯めぐり見習い'
    ELSE                            '湯めぐり初心者'
  END;

  UPDATE public.user_rankings
  SET
    explorer_points = v_visit_count * 100,
    visit_count     = v_visit_count,
    current_title   = v_title,
    updated_at      = NOW()
  WHERE user_id = OLD.user_id;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_ranking_on_visit_delete ON public.visits;
CREATE TRIGGER trg_update_ranking_on_visit_delete
  AFTER DELETE ON public.visits
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ranking_on_visit_delete();
