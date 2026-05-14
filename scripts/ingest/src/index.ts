#!/usr/bin/env node
/**
 * 湯マップ情報収集スクリプト
 *
 * 使い方:
 *   npm run fediverse   # Misskey + Mastodon（30分cron用）
 *   npm run youtube     # YouTube RSS（6時間cron用）
 *   npm run rss         # ブログ・メディア RSS（6時間cron用）
 *   npm run all         # 全ソース
 *
 * 環境変数（.env または GitHub Secrets）:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */

import { ingestMisskey, ingestMastodon } from './sources/fediverse.ts';
import { ingestYoutube } from './sources/youtube.ts';
import { ingestRss } from './sources/rss.ts';
import { upsertPosts, enqueueMatching, loadFacilities } from './supabase-client.ts';
import type { SourcePost } from './supabase-client.ts';

async function processAndSave(source: string, posts: SourcePost[]) {
  if (posts.length === 0) return;
  const insertedIds = await upsertPosts(posts);
  const enqueued = await enqueueMatching([...insertedIds]);
  console.log(`[${source}] 投稿 ${insertedIds.size}件 新規保存 / matching_queue ${enqueued}件 enqueue`);
}

async function main() {
  const mode = process.argv[2] ?? 'all';
  console.log(`[ingest] モード: ${mode}  開始: ${new Date().toISOString()}`);

  const facilities = await loadFacilities();
  console.log(`[ingest] 施設DB ${facilities.length}件 ロード完了`);

  if (mode === 'fediverse' || mode === 'all') {
    console.log('--- Misskey ---');
    const mp = await ingestMisskey();
    await processAndSave('misskey', mp);

    console.log('--- Mastodon ---');
    const msp = await ingestMastodon();
    await processAndSave('mastodon', msp);
  }

  if (mode === 'youtube' || mode === 'all') {
    console.log('--- YouTube RSS ---');
    const yp = await ingestYoutube();
    await processAndSave('youtube', yp);
  }

  if (mode === 'rss' || mode === 'all') {
    console.log('--- ブログ・メディア RSS ---');
    const rp = await ingestRss();
    await processAndSave('rss', rp);
  }

  console.log(`[ingest] 完了: ${new Date().toISOString()}`);
}

main().catch((err) => {
  console.error('[ingest] 致命的エラー:', err);
  process.exit(1);
});
