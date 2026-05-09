import type { FacilityRow, MentionRow, MatchMethod } from './supabase-client.ts';

// HTMLタグ除去
export function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

// 抜粋（DB制約: 200文字以内、施設名前後の文脈）
function makeExcerpt(text: string, facilityName: string): string {
  const idx = text.indexOf(facilityName);
  if (idx === -1) return text.slice(0, 120);
  const start = Math.max(0, idx - 40);
  const end = Math.min(text.length, idx + facilityName.length + 80);
  return text.slice(start, end).slice(0, 120); // 120 < 200 (DB制約)
}

export interface MatchResult {
  facilityId: string;
  method: MatchMethod;
  score: number;
  evidence: string;
  excerpt: string;
}

export function matchFacilities(
  text: string,
  facilities: FacilityRow[],
): MatchResult[] {
  const results: MatchResult[] = [];
  const seen = new Set<string>();

  // 第1層: 【施設名】パターン（最高信頼度）
  for (const m of text.matchAll(/【([^】]{2,30})】/g)) {
    const candidate = m[1];
    for (const f of facilities) {
      if (f.name === candidate && !seen.has(f.id)) {
        seen.add(f.id);
        results.push({
          facilityId: f.id,
          method: 'regex_brackets',
          score: 1.0,
          evidence: candidate,
          excerpt: makeExcerpt(text, candidate),
        });
      }
    }
  }

  // 第2層: 辞書マッチ（4文字以上。2〜3文字は誤検知が多いためスキップ）
  for (const f of facilities) {
    if (seen.has(f.id)) continue;
    const name = f.name;
    if (name.length >= 4 && text.includes(name)) {
      seen.add(f.id);
      results.push({
        facilityId: f.id,
        method: 'dict_aho',
        score: 0.85,
        evidence: name,
        excerpt: makeExcerpt(text, name),
      });
    }
  }

  return results;
}

export function buildMentions(
  postId: string,
  text: string,
  facilities: FacilityRow[],
): MentionRow[] {
  return matchFacilities(text, facilities).map((m) => ({
    facility_id: m.facilityId,
    post_id: postId,
    match_method: m.method,
    match_score: m.score,
    match_evidence: m.evidence,
    excerpt: m.excerpt,
  }));
}
