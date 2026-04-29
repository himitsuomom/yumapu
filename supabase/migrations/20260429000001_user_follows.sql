-- ============================================================
-- user_follows テーブル
-- フォロー/フォロワー機能の基盤
-- follower_id: フォローする人（自分）
-- following_id: フォローされる人（相手）
-- ============================================================

CREATE TABLE user_follows (
    follower_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id),
    CONSTRAINT no_self_follow CHECK (follower_id != following_id)
);

-- 検索効率のためのインデックス
-- follower_id → 「自分がフォローしている人一覧」取得に使う
-- following_id → 「自分のフォロワー一覧」取得に使う
CREATE INDEX idx_user_follows_follower  ON user_follows (follower_id);
CREATE INDEX idx_user_follows_following ON user_follows (following_id);

-- ── RLS（Row Level Security: 行単位のアクセス制御）──────────────────────────

ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

-- フォロー関係は公開情報として誰でも閲覧可能
CREATE POLICY "anyone can view follows"
    ON user_follows FOR SELECT
    USING (true);

-- 自分がフォロワーとして登録できる（自分からのフォローのみ）
CREATE POLICY "users can follow"
    ON user_follows FOR INSERT
    WITH CHECK (auth.uid() = follower_id);

-- 自分がフォロワーとして削除できる（アンフォローのみ）
CREATE POLICY "users can unfollow"
    ON user_follows FOR DELETE
    USING (auth.uid() = follower_id);

-- ── フォロー中ユーザーの投稿を取得するRPC ───────────────────────────────────
-- RPCとして実装する理由:
-- 「フォロー中のユーザーIDリスト」→「そのユーザーの投稿」という
-- サブクエリをFlutter側で書くより、DB側でまとめて処理する方が高速。
-- SECURITY DEFINER: RLSを無視して実行（パフォーマンス確保のため）

CREATE OR REPLACE FUNCTION get_following_posts(
    p_user_id UUID,
    p_limit    INT         DEFAULT 20,
    p_cursor   TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    id             UUID,
    user_id        UUID,
    content        TEXT,
    facility_id    UUID,
    facility_name  TEXT,
    image_url      TEXT,
    likes_count    INT,
    comments_count INT,
    created_at     TIMESTAMPTZ,
    display_name   TEXT,
    username       TEXT,
    avatar_url     TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        p.id,
        p.user_id,
        p.content,
        p.facility_id,
        p.facility_name,
        p.image_url,
        p.likes_count,
        p.comments_count,
        p.created_at,
        u.display_name,
        u.username,
        u.avatar_url
    FROM posts p
    JOIN users u ON u.id = p.user_id
    WHERE p.user_id IN (
        SELECT following_id
        FROM   user_follows
        WHERE  follower_id = p_user_id
    )
    AND (p_cursor IS NULL OR p.created_at < p_cursor)
    ORDER BY p.created_at DESC
    LIMIT p_limit;
$$;

-- ── フォロワー数・フォロー中数を一括取得するRPC ──────────────────────────────

CREATE OR REPLACE FUNCTION get_follow_counts(p_user_id UUID)
RETURNS TABLE (
    followers_count BIGINT,
    following_count BIGINT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        (SELECT COUNT(*) FROM user_follows WHERE following_id = p_user_id) AS followers_count,
        (SELECT COUNT(*) FROM user_follows WHERE follower_id  = p_user_id) AS following_count;
$$;

-- ── 特定ユーザーをフォローしているか確認するRPC ──────────────────────────────

CREATE OR REPLACE FUNCTION is_following(
    p_follower_id  UUID,
    p_following_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   user_follows
        WHERE  follower_id  = p_follower_id
        AND    following_id = p_following_id
    );
$$;
