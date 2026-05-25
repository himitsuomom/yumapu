-- posts テーブルに image_urls 配列カラムを追加（image_url との後方互換を維持）
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';

-- 既存の image_url データを image_urls に移行
UPDATE posts
SET image_urls = ARRAY[image_url]
WHERE image_url IS NOT NULL
  AND image_url != ''
  AND image_urls = '{}';
