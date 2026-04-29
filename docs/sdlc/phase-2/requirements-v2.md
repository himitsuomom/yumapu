# 要求定義書 v2 — YuMap リリース前改善イニシアチブ（George レビュー反映版）

作成日: 2026-04-29
バージョン: 2.0（George レビュー後）
担当: Eric → George 経由
入力: `docs/sdlc/phase-2/requirements.md` + `docs/sdlc/phase-2/george-review.md`

> v1 からの主な変更点:
> - FR-005 アカウントリンクをスコープアウト
> - NFR-008 マーカー描画要件を現実的な値に緩和
> - FR-007 のテキストモデレーション AI を第一候補確定（OpenAI Moderation）
> - FR-012 連続レビュー制限の N時間を確定（24時間）
> - FR-013 管理者ロールの実装方法を確定（app_admins テーブル）
> - NFR-016 通報後通知を確定（Supabase ダッシュボード）
> - NFR-004 フォールバック UX を具体化（health-check + 5分後リトライ）
> - 工数を Wave 別に分解
> - **5件の前提確認事項** をユーザーに提示（最後尾）

---

## 0. 着手順序（変更なし）

| Wave | テーマ | 想定工数 | 理由 |
|---|---|---|---|
| **Wave 1** | 認証強化 | 約1週間 | 後続テストの基盤・Apple Dev Program 確認も同時 |
| **Wave 2** | 信憑性向上 | 約1〜2週間 | 投稿安全性は他機能の前提 |
| **Wave 3** | UI改善 | 約1週間 | 信頼性後に触り心地を磨く |
| **Wave 4** | ボタン網羅テスト | 数日 | 全変更後にまとめて実施 |

合計: **3〜4週間**（NFR-017 を Wave別に再分解）

---

## 1. 機能要件（FR）

### Wave 1: 認証強化

| ID | 機能 | 誰が | 何を | なぜ | 優先度 | 変更 |
|---|---|---|---|---|---|---|
| FR-001 | Google ログイン | 一般ユーザー | Google でサインイン/サインアップ | 新規獲得障壁低減 | 高 | — |
| FR-002 | Apple ログイン | iOS ユーザー | Apple ID でサインイン/サインアップ | iOS 審査要件 | 高 | — |
| FR-003 | 既存メール認証維持 | 既存ユーザー | メール/PW で継続ログイン | アカウント継続性 | 高 | — |
| FR-004 | 規約・ポリシー導線 | 新規ユーザー | サインアップ画面から参照 | 法的・審査要件 | 高 | — |
| ~~FR-005~~ | ~~アカウントリンク~~ | — | — | — | — | **スコープアウト**（Supabase Identity Linking が β、リリース直前に重い）|

### Wave 2: 信憑性向上

| ID | 機能 | 誰が | 何を | なぜ | 優先度 |
|---|---|---|---|---|---|
| FR-006 | 写真モデレーション | 投稿者 | 投稿時に画像が NSFW/暴力 判定される | 不適切画像をブロック | 高 |
| FR-007 | テキストモデレーション | 投稿者 | NGワード辞書 + **OpenAI Moderation API** で検査 | スパム/誹謗中傷の混入防止 | 高 |
| FR-008 | チェックイン GPS サーバー検証 | チェックインユーザー | RPC で距離を再計算 | クライアント改竄バイパス防止 | 高 |
| FR-009 | 通報ボタン（レビュー） | 閲覧ユーザー | 不適切レビューを通報 | 嫌がらせ事後対応 | 高 |
| FR-010 | 通報ボタン（写真） | 閲覧ユーザー | 不適切写真を通報 | 嫌がらせ事後対応 | 高 |
| FR-011 | 通報ボタン（ユーザー） | 閲覧ユーザー | 嫌がらせユーザーを通報 | 嫌がらせ事後対応 | 中 |
| FR-012 | 連続レビュー制限 | 投稿者 | 同一施設 **24時間以内**は再レビュー不可 | スパム対策 | 中 |
| FR-013 | 管理者削除権限 | 管理者 | 通報コンテンツを手動削除 | 自動判定の最終バックアップ | 中 |
| FR-014 (新) | 管理者画面（最小） | 管理者 | reports テーブルを一覧・対応ステータス更新 | 1人運用の最低限ツール | 中 |

### Wave 3: UI改善

| ID | 機能 | 誰が | 何を | なぜ | 優先度 |
|---|---|---|---|---|---|
| FR-015 | マーカークラスタリング安定化 | 地図利用者 | ズーム時に崩れない | 視覚的バグ除去 | 高 |
| ~~FR-016~~ | ~~マーカー色分け視認性~~ | — | — | — | **既存実装確認後に判断**（セッション32で確認済みのため、現状で十分なら削除）|
| FR-017 | ボトムシート操作性 | 施設詳細閲覧者 | スワイプ・カルーセル | 操作のもたつき解消 | 中 |
| FR-018 | 検索の地図移動連動 | 検索ユーザー | 表示中エリア結果に絞られる | 「ここで探す」体験 | 中 |
| FR-019 | 検索リアルタイム応答 | 検索ユーザー | 入力中即時更新 | 摩擦低減 | 中 |
| FR-020 | フィード無限スクロール改善 | フィード閲覧者 | 末尾でスムーズに次ページ | がたつき解消 | 中 |
| FR-021 | フィード施設絞り込み | フィード閲覧者 | 特定施設のフィード | 関心の的を絞る | 低 |

### Wave 4: ボタン動作確認

| ID | 機能 | 誰が | 何を | なぜ | 優先度 |
|---|---|---|---|---|---|
| FR-022 | 必須パス網羅 | 開発者 | ログイン→地図→詳細→レビュー→チェックイン→お気に入り→プロフィール | 主動線リグレッション検出 | 高 |
| FR-023 | 設定系網羅 | 開発者 | 通知/アカウント削除/ログアウト | 副動線リグレッション検出 | 高 |
| FR-024 | 管理系網羅 | 開発者 | 投稿編集/削除/レビュー削除/写真削除 | 投稿管理の信頼性 | 中 |
| FR-025 | テストマトリクス記録 | 開発者 | `button-test-matrix.md` に記録 | 履歴・再現性 | 高 |

---

## 2. 非機能要件（NFR）— v2 で更新

| ID | 種別 | 要件 | 測定方法 | v1 からの変更 |
|---|---|---|---|---|
| NFR-001 | パフォーマンス | 写真モデレーション API: P95 < 2秒 | Edge Function ログ | — |
| NFR-002 | パフォーマンス | テキストモデレーション API: P95 < 1秒 | 同上 | — |
| NFR-003 | パフォーマンス | モデレーション API タイムアウト: 5秒 | コード設定値 | — |
| NFR-004 | 可用性 | API 障害時: **拒否方式 + health-check エンドポイント + 「5分後リトライ」UI 明示** | 障害シミュレーション | UX を具体化 |
| NFR-005 | パフォーマンス | チェックイン RPC: P95 < 500ms | Supabase logs | — |
| NFR-006 | パフォーマンス | チェックイン GPS 距離: デフォルト 100m（設定可） | 設定ファイル | — |
| NFR-007 | パフォーマンス | ログイン処理: P95 < 3秒 | 計測ログ | — |
| **NFR-008** | パフォーマンス | **マーカー描画: ズーム時1秒以内に再描画完了 / スクロール中30fps以上 / クラスタリングで画面内100件以下に抑制** | Flutter DevTools | **緩和**（60fps→30fps、100件制約追加）|
| NFR-009 | パフォーマンス | 検索リアルタイム応答: 入力後 300ms | UI計測 | — |
| NFR-010 | セキュリティ | RLS 設定の継続的維持 | Supabase Advisors | — |
| NFR-011 | セキュリティ | OWASP Top 10 準拠 | 手動チェック | — |
| NFR-012 | セキュリティ | チェックイン距離検証はサーバー必須 | コードレビュー | — |
| NFR-013 | 互換性 | iOS / Android 両対応 | 実機テスト | — |
| NFR-014 | 互換性 | 既存実装リグレッションゼロ | Wave 4 全PASS | — |
| NFR-015 | 運用性 | モデレーション拒否時のユーザーメッセージ表示 | UI実装 | — |
| **NFR-016** | 運用性 | **通報後の管理者通知: Supabase reports テーブル + 管理者画面（FR-014）。メール/Slack はリリース後に追加検討** | DB+UI実装 | **手段確定** |
| NFR-017 | 開発リソース | Wave 1: 1週間 / Wave 2: 1〜2週間 / Wave 3: 1週間 / Wave 4: 数日 | Wave別進捗 | **Wave別に分解** |
| NFR-018 | 法令遵守 | 規約・ポリシーをサインアップ前に提示 | UI実装 | — |
| NFR-019 (新) | セキュリティ | API キーは Supabase Secrets で管理（クライアント送信禁止） | コードレビュー | — |
| NFR-020 (新) | 法令遵守 | アカウント削除時の投稿の扱い: **匿名化（user_id を NULL or 'deleted' に）** | DB マイグレーション | GDPR 配慮 |

---

## 3. 関数シグネチャ（v2 で確定）

```dart
// 認証
Future<AuthResult> signInWithGoogle();
Future<AuthResult> signInWithApple();   // iOS のみ Available チェック
Future<AuthResult> signInWithEmail(String email, String password);

// モデレーション (Flutter ラッパー)
class ModerationService {
  Future<ModerationResult> checkPhoto(Uint8List image);
  Future<ModerationResult> checkText(String text);
  Future<bool> isApiHealthy();   // ヘルスチェック (NFR-004)
}

// 通報
enum ReportTargetType { review, photo, user }
Future<void> reportContent({
  required ReportTargetType type,
  required String targetId,
  required String reason,
});

// 連続レビュー制限チェック
Future<bool> canSubmitReview(String facilityId);  // 24h 以内なら false
```

```typescript
// Edge Function
interface ModerationResult {
  passed: boolean;
  categories: string[];
  confidence: number;
  reason?: string;
}
async function moderateImage(imageUrl: string): Promise<ModerationResult>;
async function moderateText(text: string): Promise<ModerationResult>;
async function healthCheck(): Promise<{ healthy: boolean; provider: string }>;
```

```sql
-- チェックイン距離検証 (PostGIS なしバージョン: earth_distance 拡張)
CREATE OR REPLACE FUNCTION validate_checkin(
  p_facility_id UUID,
  p_user_lat NUMERIC,
  p_user_lon NUMERIC
) RETURNS JSON AS $$
  -- earth_distance(ll_to_earth(...)) で距離計算 → 100m以内なら PASS
$$;

-- 管理者テーブル
CREATE TABLE app_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  added_at TIMESTAMPTZ DEFAULT now()
);

-- 通報テーブル
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES auth.users(id),
  target_type TEXT CHECK (target_type IN ('review', 'photo', 'user')),
  target_id UUID NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending',  -- pending / resolved / dismissed
  created_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES app_admins(user_id)
);
```

---

## 4. 受入テスト骨子（v1 から追加・更新分のみ）

| ID | Given | When | Then |
|---|---|---|---|
| AT-011v2 | モデレーション API 障害中 | 写真投稿しようとする | health-check が unhealthy 検出 → 投稿ボタン disable + 「5分後にお試しください」表示 |
| AT-015v2 | 同一施設に **24時間以内**に再投稿試行 | 投稿ボタンを押す | 拒否 + 残り時間表示 |
| AT-040 (新) | 管理者として通報一覧を開く | reports 一覧画面で対象を選び「削除」 | 対象コンテンツが削除され、reports.status が resolved に |
| AT-041 (新) | アカウント削除実行 | 確認 → 削除 | 自分のレビュー/写真は user_id が匿名化され表示は維持される |

---

## 5. スコープ外（v2 で追記）

- ~~アカウントリンク（FR-005）~~ — Supabase Identity Linking が β のためリリース後に検討
- マーカー色分けの再調整 — 既存実装確認後に判断（おそらく不要）
- 管理者通知のメール/Slack 連携 — 通報数が増えたら追加検討

---

## 6. 制約・前提（v2 で追加）

### 必須前提（**Wave 1 開始前にユーザー確認**）

| # | 確認事項 | 理由 |
|---|---|---|
| Q1 | **Apple Developer Program に加入していますか？** | Apple Sign in は加入必須（年 $99） |
| Q2 | **既存の Firebase / GCP プロジェクトはありますか？** | Google ログインの OAuth Client ID 発行に必要 |
| Q3 | **Supabase に PostGIS 拡張を入れて良いですか？** | 入れなくても earth_distance で代替可能。判断による |
| Q4 | **アカウントリンク（FR-005）スコープアウトで OK ですか？** | リリース直前に重い機能のため |
| Q5 | **管理者は当面1名（あなた自身）で OK ですか？** | app_admins に自分のユーザーIDを INSERT で済ませる |

→ 上記5件の回答後に Phase 3（設計）へ進む。

---

## 7. Phase 3 への引き継ぎ事項

### 設計が必要な領域
1. **モデレーション API の最終確定**: 第一候補 OpenAI Moderation（テキスト）+ AWS Rekognition or Google Vision SafeSearch（画像）。Phase 3 で比較表 + コスト試算
2. **チェックイン RPC の SQL**: Q3（PostGIS可否）次第
3. **OAuth リダイレクト URL 設計**: bundle ID / Services ID / SHA-1
4. **通報フロー UI 設計**: 通報 → 一覧 → 対応 のワイヤーフレーム
5. **アカウント削除時の匿名化マイグレーション**: user_id NULL 化 or 'deleted' 文字列化の選択

### 環境変数・設定
- Supabase Secrets: `OPENAI_API_KEY`, `MODERATION_PROVIDER_KEY`
- iOS: GoogleService-Info.plist, Apple Services ID
- Android: google-services.json, SHA-1 登録

### 監視
- 通報数ダッシュボード（Supabase 標準クエリで可）
- モデレーション拒否率ダッシュボード

---

## 次フェーズ

ユーザーから Q1〜Q5 の回答を得たうえで:

→ **Phase 3（設計書）**: `/sdlc-phase-3 "YuMap リリース前改善（Wave 1〜4 設計）"`

成果物想定: `system-design.md`, `db-design.md`, `api-design.md`
