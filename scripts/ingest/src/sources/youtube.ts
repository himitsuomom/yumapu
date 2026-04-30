import { XMLParser } from 'fast-xml-parser';
import { YOUTUBE_CHANNELS, USER_AGENT, FETCH_DELAY_MS } from '../config.ts';
import { contentHash } from '../supabase-client.ts';
import type { SourcePost } from '../supabase-client.ts';

const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_' });

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

async function fetchChannelRss(channelId: string, channelName: string): Promise<SourcePost[]> {
  const url = `https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT },
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) {
    // YouTube は ローカルIPからブロックされることがある（GitHub Actions では通る可能性あり）
    console.warn(`  YouTube ${channelName} → ${res.status}`);
    return [];
  }
  const xml = await res.text();
  const feed = parser.parse(xml);
  const entries: Record<string, unknown>[] = Array.isArray(feed.feed?.entry)
    ? feed.feed.entry
    : feed.feed?.entry
    ? [feed.feed.entry]
    : [];

  return entries.map((e) => {
    const videoId = String(e['yt:videoId'] ?? '');
    const title = String(e['title'] ?? '');
    const published = String(e['published'] ?? new Date().toISOString());
    const description = String(
      ((e['media:group'] as Record<string, unknown>)?.['media:description']) ?? ''
    );
    const thumbnail = String(
      ((e['media:group'] as Record<string, unknown>)?.['media:thumbnail'] as Record<string, unknown>)?.['@_url'] ?? ''
    );
    const text = `${title} ${description}`.slice(0, 2000);
    return {
      id: `youtube:${videoId}`,
      content_hash: contentHash(text),
      url: `https://www.youtube.com/watch?v=${videoId}`,
      title: title.slice(0, 500),
      content_text: description.slice(0, 2000),
      thumbnail_url: thumbnail || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
      published_at: published,
      raw: e,
    } satisfies SourcePost;
  });
}

export async function ingestYoutube(): Promise<SourcePost[]> {
  const posts: SourcePost[] = [];
  for (const ch of YOUTUBE_CHANNELS) {
    try {
      const batch = await fetchChannelRss(ch.id, ch.name);
      posts.push(...batch);
      console.log(`  YouTube ${ch.name} → ${batch.length}件`);
    } catch (e) {
      console.warn(`  YouTube ${ch.name} エラー: ${e}`);
    }
    await sleep(FETCH_DELAY_MS);
  }
  return posts;
}
