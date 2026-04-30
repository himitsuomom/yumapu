import { createClient } from '@supabase/supabase-js';
import { createHash } from 'node:crypto';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  throw new Error('SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を環境変数に設定してください');
}

export const supabase = createClient(url, key, {
  auth: { persistSession: false },
});

// NFKC正規化 + URL除去 + 空白正規化（content_hash の元テキスト生成用）
export function normalizeForHash(text: string): string {
  return text
    .normalize('NFKC')
    .replace(/https?:\/\/\S+/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function contentHash(text: string): string {
  return createHash('sha256').update(normalizeForHash(text)).digest('hex');
}

export interface SourcePost {
  id: string;
  source_id?: string;         // ingest_sources.id（任意）
  content_hash: string;       // NOT NULL: SHA256(normalized_text)
  url: string;
  title?: string;
  content_text?: string;
  content_html?: string;
  thumbnail_url?: string;
  published_at: string;
  raw?: object;
}

export async function upsertPosts(posts: SourcePost[]): Promise<number> {
  if (posts.length === 0) return 0;

  // 1. バッチ内の id・content_hash 両方で重複除去
  const seenIds = new Set<string>();
  const seenHashes = new Set<string>();
  const deduped = posts.filter((p) => {
    if (seenIds.has(p.id) || seenHashes.has(p.content_hash)) return false;
    seenIds.add(p.id);
    seenHashes.add(p.content_hash);
    return true;
  });

  // 2. DB の既存 id と content_hash を並列照合
  const ids    = deduped.map((p) => p.id);
  const hashes = deduped.map((p) => p.content_hash);
  const [{ data: existingById }, { data: existingByHash }] = await Promise.all([
    supabase.from('source_posts').select('id').in('id', ids),
    supabase.from('source_posts').select('content_hash').in('content_hash', hashes),
  ]);
  const existingIdSet   = new Set((existingById   ?? []).map((r: { id: string }) => r.id));
  const existingHashSet = new Set((existingByHash ?? []).map((r: { content_hash: string }) => r.content_hash));

  // 3. 両方の制約でフィルタして新規のみ plain insert（衝突ゼロ保証）
  const newPosts = deduped.filter(
    (p) => !existingIdSet.has(p.id) && !existingHashSet.has(p.content_hash)
  );
  if (newPosts.length === 0) return 0;

  const { error } = await supabase.from('source_posts').insert(newPosts);
  if (error) throw new Error(`upsertPosts: ${error.message}`);
  return newPosts.length;
}

export interface FacilityRow {
  id: string;
  name: string;
}

export async function loadFacilities(): Promise<FacilityRow[]> {
  const { data, error } = await supabase
    .from('facilities')
    .select('id, name')
    .not('name', 'is', null);
  if (error) throw new Error(`loadFacilities: ${error.message}`);
  return data ?? [];
}

// W1-1 スキーマに合わせた match_method 型
export type MatchMethod = 'regex_brackets' | 'dict_aho' | 'geocoded' | 'manual' | 'user_feedback';

export interface MentionRow {
  facility_id: string;
  post_id: string;
  match_method: MatchMethod;
  match_score: number;
  match_evidence: string;
  excerpt: string;
}

export async function upsertMentions(mentions: MentionRow[]): Promise<number> {
  if (mentions.length === 0) return 0;
  const { error } = await supabase
    .from('facility_mentions')
    .upsert(mentions, { onConflict: 'facility_id,post_id', ignoreDuplicates: true });
  if (error) throw new Error(`upsertMentions: ${error.message}`);
  return mentions.length;
}
