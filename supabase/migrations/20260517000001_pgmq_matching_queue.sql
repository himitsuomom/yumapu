-- ============================================================
-- W2-スケール: pgmq でマッチング処理を非同期化
-- ============================================================
-- 前提: Supabase Dashboard の Extensions で pgmq を有効化すること

CREATE EXTENSION IF NOT EXISTS pgmq;

SELECT pgmq.create('matching_queue');

CREATE OR REPLACE FUNCTION enqueue_matching_jobs(p_post_ids TEXT[])
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INT := 0;
  v_post_id TEXT;
BEGIN
  IF p_post_ids IS NULL OR cardinality(p_post_ids) = 0 THEN
    RETURN 0;
  END IF;

  FOREACH v_post_id IN ARRAY p_post_ids LOOP
    PERFORM pgmq.send(
      queue_name := 'matching_queue',
      msg        := jsonb_build_object('post_id', v_post_id, 'enqueued_at', NOW())
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION enqueue_matching_jobs(TEXT[]) TO service_role;

CREATE OR REPLACE FUNCTION read_matching_jobs(
  p_batch_size INT DEFAULT 50,
  p_vt_seconds INT DEFAULT 60
)
RETURNS TABLE (msg_id BIGINT, post_id TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    r.msg_id,
    (r.message->>'post_id')::TEXT AS post_id
  FROM pgmq.read('matching_queue', p_vt_seconds, p_batch_size) r;
$$;

GRANT EXECUTE ON FUNCTION read_matching_jobs(INT, INT) TO service_role;

CREATE OR REPLACE FUNCTION ack_matching_job(p_msg_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT pgmq.delete('matching_queue', p_msg_id);
$$;

GRANT EXECUTE ON FUNCTION ack_matching_job(BIGINT) TO service_role;

COMMENT ON FUNCTION enqueue_matching_jobs IS
  'source_posts 投入直後に呼ぶ。マッチング処理を Edge Function で非同期実行。';
