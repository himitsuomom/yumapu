-- ============================================================
-- push_tokens テーブル — FCM デバイストークン管理
-- ============================================================
-- プッシュ通知（いいね・コメント・フォロー・バッジ獲得）を送るために
-- ユーザーのデバイストークンを保存する。
-- Flutter 側の NotificationService.registerToken() が UPSERT する。
-- ============================================================

CREATE TABLE IF NOT EXISTS push_tokens (
    id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       TEXT        NOT NULL,
    platform    TEXT        NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, token)
);

-- インデックス: user_id → そのユーザーの全デバイスを高速取得
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON push_tokens (user_id);

-- RLS: ユーザーは自分のトークンのみ操作可能
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users manage own push tokens"
    ON push_tokens FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 通知を送信する Edge Function で使うヘルパービュー
-- （どのユーザーがどのトークンを持つかを Edge Function が参照）
-- ============================================================
-- Edge Function 側のコード例（Deno）:
--
--   const { data } = await supabase
--     .from('push_tokens')
--     .select('token, platform')
--     .eq('user_id', targetUserId);
--
--   for (const { token } of data) {
--     await sendFcmNotification(token, { title, body, data });
--   }
-- ============================================================
