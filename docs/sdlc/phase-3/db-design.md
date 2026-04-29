# DB設計書 — YuMap リリース前改善（Wave 1〜4）

作成日: 2026-04-29
フェーズ: Phase 3（設計）
DB: PostgreSQL（Supabase）+ PostGIS（initial_schema.sql で有効化済み）

---

## Context

- 既存テーブルは `supabase/migrations/20240209000000_initial_schema.sql` で定義
- PostGIS 拡張は最初から有効（`create extension if not exists postgis;` 済み）
- `facilities.location` は `GEOGRAPHY(POINT, 4326)` 型 → `ST_DWithin` がそのまま使える
- 命名規則: snake_case、PK は UUID、タイムスタンプは TIMESTAMPTZ

---

## Spec（新規テーブル・変更）

### Wave 1: 認証強化

#### 既存 `users` テーブルへの追加カラム

```sql
-- supabase/migrations/20260429000001_add_social_auth.sql

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS auth_provider TEXT DEFAULT 'email'
    CHECK (auth_provider IN ('email', 'google', 'apple', 'multiple')),
  ADD COLUMN IF NOT EXISTS provider_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN users.auth_provider IS 'サインインプロバイダ: email / google / apple / multiple';
```

> **注意**: Supabase Auth 側のプロバイダ情報は `auth.identities` テーブルで管理される。
> `users.auth_provider` は表示用の補助カラムで、権限制御には使わない。

---

### Wave 2: 信憑性向上

#### 既存 `reviews` テーブルへの追加カラム

```sql
-- supabase/migrations/20260429000002_moderation.sql

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'pending'
    CHECK (moderation_status IN ('pending', 'passed', 'blocked')),
  ADD COLUMN IF NOT EXISTS moderation_checked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS moderation_reason TEXT;

-- 投稿直後は pending → Edge Function が passed/blocked に更新
-- blocked のレビューは一般ユーザーには表示しない（RLS で制御）
```

#### 既存 `facility_photos`（または photos）テーブルへの追加

```sql
ALTER TABLE facility_photos
  ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'pending'
    CHECK (moderation_status IN ('pending', 'passed', 'blocked')),
  ADD COLUMN IF NOT EXISTS moderation_checked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS moderation_reason TEXT;
```

> **確認事項**: 写真テーブル名を Phase 4 で実コードから確認する。`facility_photos` か別名の可能性あり。

#### `reports` テーブル（新規）

```sql
-- supabase/migrations/20260429000003_reports.sql

CREATE TABLE reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  target_type   TEXT NOT NULL
                  CHECK (target_type IN ('review', 'photo', 'user', 'post')),
  target_id     UUID NOT NULL,
  reason        TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'resolved', 'dismissed')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at   TIMESTAMPTZ,
  resolved_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_note    TEXT
);

-- インデックス
CREATE INDEX idx_reports_status       ON reports (status);
CREATE INDEX idx_reports_target       ON reports (target_type, target_id);
CREATE INDEX idx_reports_reporter     ON reports (reporter_id);
CREATE INDEX idx_reports_created_at   ON reports (created_at DESC);

-- RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- 通報者は自分の通報のみ参照可
CREATE POLICY "reports_select_own" ON reports
  FOR SELECT USING (reporter_id = auth.uid());

-- 誰でも通報作成可（ログイン必須）
CREATE POLICY "reports_insert_auth" ON reports
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 管理者のみ全件参照・更新
CREATE POLICY "reports_admin_all" ON reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM app_admins WHERE user_id = auth.uid())
  );
```

#### `app_admins` テーブル（新規）

```sql
-- supabase/migrations/20260429000004_app_admins.sql

CREATE TABLE app_admins (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  note       TEXT
);

-- RLS
ALTER TABLE app_admins ENABLE ROW LEVEL SECURITY;

-- 管理者のみ参照可（自分がリストに入っているか確認するため）
CREATE POLICY "app_admins_select_self" ON app_admins
  FOR SELECT USING (user_id = auth.uid());

-- INSERT/UPDATE/DELETE はサービスロールのみ（Supabase ダッシュボードから直接操作）
```

> **初期データ投入**: Supabase Table Editor から自分のユーザー ID を `app_admins` に INSERT する。

#### `validate_checkin` RPC（新規）

```sql
-- supabase/migrations/20260429000005_validate_checkin_rpc.sql

CREATE OR REPLACE FUNCTION validate_checkin(
  p_facility_id UUID,
  p_user_lat    DOUBLE PRECISION,
  p_user_lon    DOUBLE PRECISION,
  p_max_meters  DOUBLE PRECISION DEFAULT 100.0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_facility_location GEOGRAPHY;
  v_distance          DOUBLE PRECISION;
BEGIN
  -- 施設の座標を取得
  SELECT location INTO v_facility_location
  FROM facilities
  WHERE id = p_facility_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'allowed', false,
      'reason', 'facility_not_found'
    );
  END IF;

  -- ST_DWithin で距離チェック（PostGIS）
  IF ST_DWithin(
    v_facility_location,
    ST_SetSRID(ST_MakePoint(p_user_lon, p_user_lat), 4326)::geography,
    p_max_meters
  ) THEN
    -- チェックイン許可: visits テーブルに記録（既存の verify-contribution と統合）
    RETURN json_build_object(
      'allowed', true,
      'distance_meters', ST_Distance(
        v_facility_location,
        ST_SetSRID(ST_MakePoint(p_user_lon, p_user_lat), 4326)::geography
      )
    );
  ELSE
    v_distance := ST_Distance(
      v_facility_location,
      ST_SetSRID(ST_MakePoint(p_user_lon, p_user_lat), 4326)::geography
    );
    RETURN json_build_object(
      'allowed', false,
      'reason', 'too_far',
      'distance_meters', v_distance,
      'max_meters', p_max_meters
    );
  END IF;
END;
$$;

-- ログインユーザーのみ実行可
REVOKE ALL ON FUNCTION validate_checkin FROM PUBLIC;
GRANT EXECUTE ON FUNCTION validate_checkin TO authenticated;
```

---

## ER図（新規テーブルのみ）

```mermaid
erDiagram
  auth_users {
    uuid id PK
  }

  users {
    uuid id PK
    text auth_provider
    timestamptz provider_updated_at
  }

  reviews {
    uuid id PK
    text moderation_status
    timestamptz moderation_checked_at
    text moderation_reason
  }

  facility_photos {
    uuid id PK
    text moderation_status
    timestamptz moderation_checked_at
    text moderation_reason
  }

  reports {
    uuid id PK
    uuid reporter_id FK
    text target_type
    uuid target_id
    text reason
    text status
    timestamptz created_at
    timestamptz resolved_at
    uuid resolved_by FK
    text admin_note
  }

  app_admins {
    uuid user_id PK_FK
    timestamptz added_at
    text note
  }

  auth_users ||--o{ users : "extends"
  auth_users ||--o{ reports : "reporter"
  auth_users ||--o{ app_admins : "is_admin"
  auth_users ||--o{ reports : "resolved_by"
```

---

## Constraints（制約・方針）

### 命名規則
- テーブル名: snake_case・複数形（`reports`, `app_admins`）
- カラム名: snake_case（`moderation_status`, `created_at`）
- PK: UUID、`gen_random_uuid()` デフォルト
- タイムスタンプ: `TIMESTAMPTZ`（UTC保存、TZ aware）

### 正規化方針
- 第3正規形まで維持
- `reports.target_id` はポリモーフィック設計（type + id の複合）。FK は設定しない（型別に異なるテーブルを参照するため）

### 個人情報・機密データ
| カラム | 機密度 | 方針 |
|---|---|---|
| `users.email` | 高 | Supabase Auth 管理、アプリから直接読み取らない |
| `reports.reporter_id` | 中 | RLS で自分のみ参照、管理者は全件参照 |
| `app_admins.user_id` | 高 | RLS で自分のみ参照、INSERT はダッシュボードから直接 |

### 既存テーブルの変更ルール
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` のみ使用（既存カラムの変更・削除禁止）
- 新規 NOT NULL カラムには必ず DEFAULT を付ける（既存行が壊れないように）
- インデックスは `CREATE INDEX IF NOT EXISTS` で冪等に

### アカウント削除時の匿名化（NFR-020）
```sql
-- アカウント削除トリガー（既存の ON DELETE CASCADE を活用しつつ）
-- reviews / posts の user_id を NULL にする（or 'deleted' ユーザーに付け替える）
-- Phase 5 の実装時に詳細化
```
