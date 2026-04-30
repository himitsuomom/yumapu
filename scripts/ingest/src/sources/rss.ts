import { XMLParser } from 'fast-xml-parser';
import { createHash } from 'node:crypto';
import { RSS_SOURCES, USER_AGENT, FETCH_DELAY_MS } from '../config.ts';
import { contentHash } from '../supabase-client.ts';
import type { SourcePost } from '../supabase-client.ts';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  processEntities: true,
  htmlEntities: true,
  allowBooleanAttributes: true,
});

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

// Hatena 既知問題: 多重エンコードされた XML エンティティを前処理で正規化
function preProcessXml(xml: string): string {
  // &amp;amp; → &amp; → & のような多重エンコードを1段階展開
  return xml.replace(/&amp;(amp|lt|gt|quot|apos);/g, '&$1;');
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

function parseDate(raw: unknown): string {
  if (!raw) return new Date().toISOString();
  const d = new Date(String(raw));
  return isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
}

function extractEntries(parsed: Record<string, unknown>): Array<Record<string, unknown>> {
  // RSS 2.0
  const rssChannel = (parsed.rss as Record<string, unknown>)?.channel;
  if (rssChannel) {
    const items = (rssChannel as Record<string, unknown>).item;
    return Array.isArray(items) ? items : items ? [items as Record<string, unknown>] : [];
  }
  // Atom
  const atomFeed = parsed.feed as Record<string, unknown> | undefined;
  if (atomFeed) {
    const entries = atomFeed.entry;
    return Array.isArray(entries) ? entries : entries ? [entries as Record<string, unknown>] : [];
  }
  // RSS 1.0 (RDF)
  const rdf = (parsed['rdf:RDF'] ?? parsed['RDF']) as Record<string, unknown> | undefined;
  if (rdf) {
    const items = rdf.item;
    return Array.isArray(items) ? items : items ? [items as Record<string, unknown>] : [];
  }
  return [];
}

function entryToPost(entry: Record<string, unknown>, sourceName: string): SourcePost | null {
  const link =
    (entry.link as { '@_href'?: string } | string | undefined) instanceof Object
      ? (entry.link as { '@_href'?: string })['@_href'] ?? ''
      : String(entry.link ?? '');
  if (!link) return null;

  // SHA-256 ハッシュでID生成（衝突防止）
  const id = `rss:${createHash('sha256').update(link).digest('hex').slice(0, 32)}`;
  const title = String(entry.title ?? '').trim();
  const rawContent = String(
    entry['content:encoded'] ?? entry.description ?? entry.content ?? entry.summary ?? ''
  );
  const text = stripHtml(rawContent).slice(0, 2000);
  const published = parseDate(entry.pubDate ?? entry.published ?? entry['dc:date']);

  return {
    id,
    content_hash: contentHash(`${title} ${text}`),
    url: link,
    title: title.slice(0, 500),
    content_text: text,
    published_at: published,
    raw: entry,
  };
}

async function fetchRss(url: string, sourceName: string): Promise<SourcePost[]> {
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT },
    signal: AbortSignal.timeout(20000),
  });
  if (!res.ok) {
    console.warn(`  RSS ${sourceName} → ${res.status}`);
    return [];
  }
  const raw = await res.text();
  const xml = preProcessXml(raw); // Hatena エンティティ問題対策
  let parsed: Record<string, unknown>;
  try {
    parsed = parser.parse(xml) as Record<string, unknown>;
  } catch (e) {
    console.warn(`  RSS ${sourceName} XML パースエラー: ${e}`);
    return [];
  }
  const entries = extractEntries(parsed);
  return entries
    .map((e) => entryToPost(e, sourceName))
    .filter((p): p is SourcePost => p !== null);
}

export async function ingestRss(): Promise<SourcePost[]> {
  const posts: SourcePost[] = [];
  for (const src of RSS_SOURCES) {
    try {
      const batch = await fetchRss(src.url, src.name);
      posts.push(...batch);
      console.log(`  RSS ${src.name} → ${batch.length}件`);
    } catch (e) {
      console.warn(`  RSS ${src.name} エラー: ${e}`);
    }
    await sleep(FETCH_DELAY_MS);
  }
  return posts;
}
