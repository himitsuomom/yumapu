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
import { upsertPosts, upsertMentions, loadFacilities } from './supabase-client.ts';
import { buildMentions, stripHtml } from './matcher.ts';
import type { SourcePost } from './supabase-client.ts';

async function processAndSave(source: string, posts: SourcePost[], facilities: Awaited<ReturnType<typeof loadFacilities>>) {
  if (posts.length === 0) return;
  const insertedIds = await upsertPosts(posts);

  let mentionCount = 0;
  for (const post of posts) {
    // ON CONFLICT DO NOTHING でスキップされた投稿（content_hash重複）はFKエラー回避のためスキップ
    if (!insertedIds.has(post.id)) continue;
    const text = post.content_text ?? (post.title ? stripHtml(post.title) : '');
    if (!text) continue;
    const mentions = buildMentions(post.id, text, facilities);
    if (mentions.length > 0) {
      await upsertMentions(mentions);
      mentionCount += mentions.length;
    }
  }
  console.log(`[${source}] 投稿 ${insertedIds.size}件 新規保存 / 施設言及 ${mentionCount}件`);
}

async function main() {
  const mode = process.argv[2] ?? 'all';
  console.log(`[ingest] モード: ${mode}  開始: ${new Date().toISOString()}`);

  const facilities = await loadFacilities();
  console.log(`[ingest] 施設DB ${facilities.length}件 ロード完了`);

  if (mode === 'fediverse' || mode === 'all') {
    console.log('--- Misskey ---');
    const mp = await ingestMisskey();
    await processAndSave('misskey', mp, facilities);

    console.log('--- Mastodon ---');
    const msp = await ingestMastodon();
    await processAndSave('mastodon', msp, facilities);
  }

  if (mode === 'youtube' || mode === 'all') {
    console.log('--- YouTube RSS ---');
    const yp = await ingestYoutube();
    await processAndSave('youtube', yp, facilities);
  }

  if (mode === 'rss' || mode === 'all') {
    console.log('--- ブログ・メディア RSS ---');
    const rp = await ingestRss();
    await processAndSave('rss', rp, facilities);
  }

  console.log(`[ingest] 完了: ${new Date().toISOString()}`);
}

main().catch((err) => {
  console.error('[ingest] 致命的エラー:', err);
  process.exit(1);
});
