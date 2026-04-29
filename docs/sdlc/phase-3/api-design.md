# API設計書 — YuMap リリース前改善（Wave 1〜4）

作成日: 2026-04-29
フェーズ: Phase 3（設計）
認証方式: Supabase Auth（JWT Bearer Token）

---

## Context

- クライアント: Flutter（iOS/Android）
- 既存 Edge Functions: `calculate-ranking`, `directions`, `verify-contribution`
- 既存 RPC: `get_facilities_in_bounds` など
- 認証: Supabase Auth JWT（`Authorization: Bearer <token>` ヘッダー）
- バージョニング: `/v1/` プレフィックスなし（Supabase Edge Functions は URL で直接指定）

---

## Spec

### Wave 1: 認証強化

#### Supabase Auth プロバイダ設定（ダッシュボード操作）

Supabase Auth の API は SDK 経由で使用するため、REST エンドポイントを直接定義しない。
Flutter 側の呼び出しシグネチャを設計する。

```dart
// lib/services/auth_service.dart

class AuthService {
  final SupabaseClient _supabase;

  // Google ログイン（Wave 1a）
  Future<AuthResponse> signInWithGoogle() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.yumap://login-callback',
    );
  }

  // Apple ログイン（Wave 1b）
  Future<AuthResponse> signInWithApple() async {
    // iOS のみ有効
    if (!Platform.isIOS) throw UnsupportedError('Apple login is iOS only');
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.yumap://login-callback',
    );
  }

  // 既存メール/パスワード（変更なし）
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
```

#### Deep Link 設定（Wave 1 で必要）

| プラットフォーム | 設定ファイル | 値 |
|---|---|---|
| iOS | `ios/Runner/Info.plist` | URL Scheme: `io.supabase.yumap` |
| Android | `android/app/src/main/AndroidManifest.xml` | Intent Filter: `io.supabase.yumap://login-callback` |

#### Firebase Console 作業手順（Google ログイン）

1. Firebase Console → `yumap-bcb7e` → Authentication → Sign-in method → Google を有効化
2. iOS 用: `GoogleService-Info.plist` を再ダウンロードして差し替え（CLIENT_ID が追記される）
3. Android 用: SHA-1 を `google-services.json` に登録（`keytool` で取得）
4. Supabase ダッシュボード → Authentication → Providers → Google → Client ID / Secret を入力

---

### Wave 2: モデレーション Edge Functions

#### POST `/functions/v1/moderate-image`

```typescript
// supabase/functions/moderate-image/index.ts

// リクエスト
interface ModerateImageRequest {
  image_url: string;    // Supabase Storage の公開 URL
}

// レスポンス（正常）
interface ModerateImageResponse {
  passed: boolean;
  categories: string[];     // ['nsfw', 'violence', 'disturbing', ...]
  confidence: number;       // 0.0 〜 1.0
  reason?: string;          // blocked の場合の説明
  provider: string;         // 'aws_rekognition' | 'google_vision' | 'mock'
}

// エラーレスポンス（共通形式）
interface ErrorResponse {
  error: string;
  code: 'TIMEOUT' | 'PROVIDER_ERROR' | 'INVALID_INPUT' | 'UNAUTHORIZED';
}
```

- **認証**: `Authorization: Bearer <JWT>` 必須（authenticated ユーザーのみ）
- **タイムアウト**: 5秒（タイムアウト時は `{ passed: false, reason: 'timeout' }` を返す）
- **プロバイダ**: `MODERATION_IMAGE_PROVIDER` 環境変数で切替（AWS Rekognition 第一候補）
- **APIキー**: Supabase Secrets `REKOGNITION_ACCESS_KEY` / `REKOGNITION_SECRET_KEY` で管理

#### POST `/functions/v1/moderate-text`

```typescript
// supabase/functions/moderate-text/index.ts

// リクエスト
interface ModerateTextRequest {
  text: string;              // レビュー本文
  context?: 'review' | 'post' | 'comment';
}

// レスポンス
interface ModerateTextResponse {
  passed: boolean;
  categories: string[];      // ['harassment', 'hate', 'spam', 'violence', ...]
  confidence: number;
  reason?: string;
  provider: string;          // 'openai_moderation' | 'mock'
}
```

- **認証**: Bearer JWT 必須
- **プロバイダ**: OpenAI Moderation API（`OPENAI_API_KEY` in Supabase Secrets）
- **タイムアウト**: 5秒
- **NGワード辞書**: Edge Function 内に日本語 NGワードリストを同梱（ハードコード）

#### GET `/functions/v1/health-check`

```typescript
// supabase/functions/health-check/index.ts

// レスポンス
interface HealthCheckResponse {
  healthy: boolean;
  providers: {
    image_moderation: 'ok' | 'degraded' | 'down';
    text_moderation: 'ok' | 'degraded' | 'down';
  };
  checked_at: string;  // ISO 8601
}
```

- **認証**: 不要（Public）
- **TTL**: レスポンスを 30秒キャッシュ（頻繁なポーリング対策）
- **Flutter 側**: 投稿前に呼び出し → `healthy: false` なら投稿ボタン disable

---

### Wave 2: チェックイン検証 RPC

#### `validate_checkin` RPC

```dart
// Flutter 側の呼び出し
final result = await Supabase.instance.client
    .rpc('validate_checkin', params: {
      'p_facility_id': facilityId,
      'p_user_lat': userLocation.latitude,
      'p_user_lon': userLocation.longitude,
      'p_max_meters': 100.0,
    });

// レスポンス型
class CheckinValidationResult {
  final bool allowed;
  final double? distanceMeters;
  final String? reason;  // 'facility_not_found' | 'too_far'
  final double? maxMeters;
}
```

- **認証**: `authenticated` ロールのみ実行可（SECURITY DEFINER）
- **エラー**: `allowed: false` + reason で拒否理由を明示
- **既存実装との関係**: `lib/services/checkin_service.dart` の既存クライアント検証を維持しつつ、RPC 側でサーバー検証を追加（両方通った場合のみチェックイン記録）

---

### Wave 2: 通報 API（Supabase テーブル直接操作）

```dart
// lib/services/report_service.dart

class ReportService {
  // 通報送信
  Future<void> submitReport({
    required ReportTargetType type,    // review | photo | user | post
    required String targetId,
    required String reason,
  }) async {
    // 投稿前に health-check を呼ぶ必要はない（モデレーション API 非使用）
    await Supabase.instance.client.from('reports').insert({
      'reporter_id': Supabase.instance.client.auth.currentUser!.id,
      'target_type': type.name,
      'target_id': targetId,
      'reason': reason,
    });
  }

  // 管理者: 通報一覧取得（管理者画面用）
  Future<List<Map<String, dynamic>>> fetchPendingReports() async {
    return await Supabase.instance.client
        .from('reports')
        .select('*, reporter:reporter_id(username)')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .then((data) => List<Map<String, dynamic>>.from(data));
  }

  // 管理者: 解決済みに更新
  Future<void> resolveReport(String reportId, {String? adminNote}) async {
    await Supabase.instance.client.from('reports').update({
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
      'resolved_by': Supabase.instance.client.auth.currentUser!.id,
      'admin_note': adminNote,
    }).eq('id', reportId);
  }
}
```

---

### Wave 2: 連続レビュー制限チェック

```dart
// lib/services/review_service.dart（既存ファイルへの追加）

// 24時間以内に同一施設にレビューしたか確認
Future<bool> canSubmitReview(String facilityId) async {
  final since = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
  final result = await Supabase.instance.client
      .from('reviews')
      .select('id')
      .eq('facility_id', facilityId)
      .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
      .gte('created_at', since)
      .limit(1);
  return result.isEmpty;  // true なら投稿可能
}
```

---

## エラーレスポンス形式（統一）

```typescript
// 全 Edge Function で統一するエラー形式
interface ErrorResponse {
  error: string;           // ユーザー表示用メッセージ（日本語）
  code: ErrorCode;
  details?: unknown;       // デバッグ用（本番は除去）
}

type ErrorCode =
  | 'UNAUTHORIZED'          // 認証なし
  | 'FORBIDDEN'             // 権限不足
  | 'TIMEOUT'               // 外部APIタイムアウト
  | 'PROVIDER_ERROR'        // モデレーションAPI障害
  | 'INVALID_INPUT'         // バリデーション失敗
  | 'RATE_LIMITED'          // レートリミット超過
  | 'NOT_FOUND';            // リソース不存在
```

---

## 認可ルール一覧

| エンドポイント / RPC | 誰が叩けるか |
|---|---|
| `moderate-image` | authenticated ユーザーのみ |
| `moderate-text` | authenticated ユーザーのみ |
| `health-check` | 誰でも（Public） |
| `validate_checkin` | authenticated ユーザーのみ |
| `reports` INSERT | authenticated ユーザーのみ |
| `reports` SELECT（全件） | `app_admins` メンバーのみ |
| `reports` UPDATE | `app_admins` メンバーのみ |
| `app_admins` SELECT | 自分の行のみ（RLS） |
| `app_admins` INSERT/UPDATE/DELETE | サービスロールのみ（ダッシュボード直接操作） |

---

## レートリミット

| エンドポイント | 制限 | 方式 |
|---|---|---|
| `moderate-image` | 10 req/min/user | Supabase Edge Function のデフォルト制限に依存 |
| `moderate-text` | 30 req/min/user | 同上 |
| `health-check` | 60 req/min | TTL 30秒キャッシュで実質低減 |
| `validate_checkin` | 5 req/min/user | RPC 側でチェック（連続チェックイン防止） |

---

## Constraints（変えてはいけないこと）

- 既存 RPC（`get_facilities_in_bounds` など）のシグネチャは変更しない
- Edge Functions の URL パスは `supabase/functions/{name}/index.ts` の規則を守る
- JWT の検証は Supabase Auth に委譲する（自前実装しない）
- 破壊的変更: Edge Functions は URL が変わるため、旧 URL は削除せずに 404 or redirect で対応
- クライアントから Supabase の `service_role` キーを使わない（`anon` キーのみ）
