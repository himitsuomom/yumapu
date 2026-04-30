-- RPC: insert_source_posts_safe
-- ON CONFLICT DO NOTHING (no target) で id(PK) と content_hash(UNIQUE) 両方の
-- 衝突を無視して安全に投稿を挿入する。実際にINSERTされた行のIDを返す。
-- Supabase JS の upsert() は単一のconflict targetしか指定できないため
-- このRPCで2つのUNIQUE制約を同時にスキップする。

CREATE OR REPLACE FUNCTION insert_source_posts_safe(posts JSONB)
RETURNS TABLE(inserted_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO source_posts (
    id, source_id, content_hash, url, title,
    content_text, content_html, thumbnail_url, published_at, raw
  )
  SELECT
    (p->>'id'),
    (p->>'source_id')::UUID,
    (p->>'content_hash'),
    (p->>'url'),
    (p->>'title'),
    (p->>'content_text'),
    (p->>'content_html'),
    (p->>'thumbnail_url'),
    (p->>'published_at')::TIMESTAMPTZ,
    CASE WHEN p->'raw' IS NOT NULL THEN (p->'raw') ELSE NULL END
  FROM jsonb_array_elements(posts) AS p
  ON CONFLICT DO NOTHING
  RETURNING id;
END;
$$;

GRANT EXECUTE ON FUNCTION insert_source_posts_safe(JSONB) TO service_role;
