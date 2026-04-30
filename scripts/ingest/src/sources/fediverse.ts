import { FEDIVERSE_HASHTAGS, MISSKEY_INSTANCES, MASTODON_INSTANCES, USER_AGENT, FETCH_DELAY_MS } from '../config.ts';
import { contentHash } from '../supabase-client.ts';
import type { SourcePost } from '../supabase-client.ts';

function plain(html: string): string {
  return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

// --- Misskey ---

interface MisskeyNote {
  id: string;
  createdAt: string;
  text: string | null;
  user: { username: string; host?: string };
  uri?: string;
}

async function fetchMisskeyTag(instance: string, tag: string): Promise<SourcePost[]> {
  const res = await fetch(`https://${instance}/api/notes/search-by-tag`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': USER_AGENT },
    body: JSON.stringify({ tag, limit: 100, reply: false, renote: false }),
    signal: AbortSignal.timeout(30000),
  });
  if (!res.ok) {
    console.warn(`  Misskey ${instance} #${tag} → ${res.status}`);
    return [];
  }
  const notes = (await res.json()) as MisskeyNote[];
  return notes
    .filter((n) => n.text && n.text.length > 0)
    .map((n) => {
      const host = n.user.host ?? instance;
      const text = (n.text ?? '').slice(0, 2000);
      return {
        id: `misskey:${n.id}`,
        content_hash: contentHash(text),
        url: n.uri ?? `https://${instance}/notes/${n.id}`,
        content_text: text,
        published_at: n.createdAt,
        raw: n,
      } satisfies SourcePost;
    });
}

export async function ingestMisskey(): Promise<SourcePost[]> {
  const posts: SourcePost[] = [];
  for (const instance of MISSKEY_INSTANCES) {
    for (const tag of FEDIVERSE_HASHTAGS) {
      try {
        const batch = await fetchMisskeyTag(instance, tag);
        posts.push(...batch);
        console.log(`  Misskey ${instance} #${tag} → ${batch.length}件`);
      } catch (e) {
        console.warn(`  Misskey ${instance} #${tag} エラー: ${e}`);
      }
      await sleep(FETCH_DELAY_MS);
    }
  }
  return dedup(posts);
}

// --- Mastodon ---

interface MastodonStatus {
  id: string;
  created_at: string;
  content: string;
  url: string;
  account: { acct: string };
  media_attachments: Array<{ preview_url?: string }>;
}

async function fetchMastodonTag(instance: string, hashtag: string): Promise<SourcePost[]> {
  const url = `https://${instance}/api/v1/timelines/tag/${encodeURIComponent(hashtag)}?limit=40`;
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT },
    signal: AbortSignal.timeout(30000), // mstdn.jp が遅いため30秒に延長（既知問題）
  });
  if (res.status === 401 || res.status === 403) {
    console.warn(`  Mastodon ${instance} #${hashtag} → ${res.status}（public preview 無効、スキップ）`);
    return [];
  }
  if (!res.ok) {
    console.warn(`  Mastodon ${instance} #${hashtag} → ${res.status}`);
    return [];
  }
  const statuses = (await res.json()) as MastodonStatus[];
  return statuses.map((s) => {
    const text = plain(s.content).slice(0, 2000);
    return {
      id: `mastodon:${s.id}`,
      content_hash: contentHash(text),
      url: s.url,
      content_text: text,
      content_html: s.content.slice(0, 4000),
      thumbnail_url: s.media_attachments[0]?.preview_url,
      published_at: s.created_at,
      raw: s,
    } satisfies SourcePost;
  });
}

export async function ingestMastodon(): Promise<SourcePost[]> {
  const posts: SourcePost[] = [];
  for (const instance of MASTODON_INSTANCES) {
    for (const tag of FEDIVERSE_HASHTAGS) {
      try {
        const batch = await fetchMastodonTag(instance, tag);
        posts.push(...batch);
        console.log(`  Mastodon ${instance} #${tag} → ${batch.length}件`);
      } catch (e) {
        console.warn(`  Mastodon ${instance} #${tag} エラー: ${e}`);
      }
      await sleep(FETCH_DELAY_MS);
    }
  }
  return dedup(posts);
}

function dedup(posts: SourcePost[]): SourcePost[] {
  const seen = new Set<string>();
  return posts.filter((p) => {
    if (seen.has(p.id)) return false;
    seen.add(p.id);
    return true;
  });
}
