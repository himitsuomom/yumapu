-- ============================================================
-- ランキングトリガー無限ループ修正
-- 2026-04-21
--
-- 問題:
--   visits INSERT
--     → update_ranking_on_visit() が user_rankings を INSERT/UPDATE
--     → on_ranking_change トリガーが trigger_ranking_update() を呼ぶ
--     → update_rank_positions() が user_rankings を UPDATE
--     → on_ranking_change がまた発火 → 無限ループ → 54001エラー
--
-- 修正:
--   trigger_ranking_update() に set_config / current_setting を使った
--   再入防止ガードを追加。
--   2回目の呼び出しは即座にリターンして無限ループを断ち切る。
-- ============================================================

CREATE OR REPLACE FUNCTION public.trigger_ranking_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- すでにこの関数が実行中なら再帰呼び出しをスキップして無限ループを防ぐ
  -- current_setting の第2引数 true = 変数が未設定でもエラーにしない
  IF current_setting('app.ranking_update_in_progress', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- フラグを立てる（第3引数 true = トランザクション終了時に自動リセット）
  PERFORM set_config('app.ranking_update_in_progress', 'true', true);

  -- 全ユーザーの順位を一括更新
  PERFORM public.update_rank_positions();

  -- フラグを下ろす
  PERFORM set_config('app.ranking_update_in_progress', 'false', true);

  RETURN NEW;
END;
$$;
