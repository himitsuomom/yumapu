# ROLLBACK — 事故時の復旧手順

このドキュメントは「あの時点に戻したい」事故が発生した際の復旧手順をまとめたものです。
冷静に対処するために、事前に読んでおいてください。

---

## 1. コミットの取り消し（ローカルのみ）

### 直前のコミットを取り消す（変更はステージに戻す）
```bash
git reset --soft HEAD~1
```

### 直前のコミットと変更を両方取り消す（危険: 変更が消える）
```bash
# 実行前に必ずバックアップブランチを作成すること
git branch backup/$(date +%Y%m%d-%H%M%S)
git reset --hard HEAD~1
```

### 特定コミットまで戻す
```bash
# コミットハッシュを確認
git log --oneline -20

# 指定コミットまでリセット（変更はステージに残る）
git reset --soft <commit-hash>
```

---

## 2. プッシュ済みブランチの修正

### ブランチ上で特定コミットを打ち消す（安全、履歴が残る）
```bash
# main ブランチへの直接push は GitHub のブランチ保護で禁止されているため
# feature ブランチで revert → PR を作成してマージ
git revert <commit-hash>
git push origin feat/your-branch
# → PR を作成してマージ
```

### 間違えて main に直接 push してしまった場合
```bash
# 1. まずバックアップ
git branch backup/main-$(date +%Y%m%d-%H%M%S)

# 2. origin/main の状態を確認
git log origin/main --oneline -10

# 3. 指定コミットまで revert
git revert <bad-commit-hash>
git push origin main
```

---

## 3. Supabase の復旧

### マイグレーションを間違えて適用した場合
```bash
# 現在の状態確認
supabase migration list

# ローカルマイグレーション確認
ls supabase/migrations/

# Supabase Dashboard → SQL Editor で手動 rollback SQL を実行
# 各 migration ファイルの inverse SQL を書いて実行する
```

### データを誤って削除した場合
- Supabase Dashboard → Database → Backups から Point-in-Time Recovery を使用
- 無料プランでは 7日間のバックアップが利用可能

---

## 4. 機密情報（API キー等）が漏洩した場合

### 即座に実施すること（順序厳守）

1. **漏洩したキーを無効化（最優先）**
   - Supabase: Dashboard → Settings → API → anon key を再生成
   - Google Maps: Cloud Console → API キー → 対象キーを削除して新規作成
   - RevenueCat: Dashboard → App Settings → API keys を再生成

2. **git 履歴から削除**
   ```bash
   # BFG Repo Cleaner を使用（推奨）
   brew install bfg
   bfg --delete-files .env repo.git

   # または git filter-repo
   pip install git-filter-repo
   git filter-repo --path .env --invert-paths
   ```

3. **強制プッシュ（GitHub に連絡も検討）**
   ```bash
   git push origin --force --all
   ```

4. **GitHub の Secret Scanning アラートを確認**
   - リポジトリ → Security → Secret scanning alerts

---

## 5. Flutter ビルドが壊れた場合

```bash
# キャッシュをクリアして再ビルド
flutter clean
flutter pub get
flutter analyze

# iOS の場合
cd ios && pod deintegrate && pod install && cd ..

# gradle キャッシュのクリア（Android）
cd android && ./gradlew clean && cd ..
```

---

## 6. よくある事故と対応

| 事故 | 対応 |
|---|---|
| `.env` を誤ってコミット | セクション4の手順を即実施 |
| 本番 DB を誤って変更 | Supabase バックアップから復元 |
| main への直接 push | セクション2の revert 手順 |
| ビルドが通らなくなった | `flutter clean` → セクション5 |
| 依存関係が壊れた | `pubspec.lock` を git で確認、前のコミットの値に戻す |

---

## 重要なコミットハッシュ（随時更新）

| タイミング | ハッシュ | メモ |
|---|---|---|
| Phase 0.5 開始時点 | e8308d9 | セッション50完了・CI設定済み |

> このファイルは事故が起きる前に読んでおくことで効果があります。
> 事故後に慌てて読んでも OK ですが、冷静さを保ってください。
