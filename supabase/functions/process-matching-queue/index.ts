import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BATCH_SIZE = Number(Deno.env.get('MATCHING_BATCH_SIZE') ?? '50');
const VT_SECONDS = 120;

interface FacilityRow { id: string; name: string; }
interface MentionRow {
  facility_id: string;
  post_id: string;
  match_method: 'regex_brackets' | 'dict_aho';
  match_score: number;
  match_evidence: string;
  excerpt: string;
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

function makeExcerpt(text: string, name: string): string {
  const idx = text.indexOf(name);
  if (idx === -1) return text.slice(0, 120);
  const start = Math.max(0, idx - 40);
  const end = Math.min(text.length, idx + name.length + 80);
  return text.slice(start, end).slice(0, 120);
}

function matchFacilities(text: string, facilities: FacilityRow[]): Omit<MentionRow, 'post_id'>[] {
  const out: Omit<MentionRow, 'post_id'>[] = [];
  const seen = new Set<string>();

  for (const m of text.matchAll(/【([^】]{2,30})】/g)) {
    const candidate = m[1];
    for (const f of facilities) {
      if (f.name === candidate && !seen.has(f.id)) {
        seen.add(f.id);
        out.push({
          facility_id: f.id,
          match_method: 'regex_brackets',
          match_score: 1.0,
          match_evidence: candidate,
          excerpt: makeExcerpt(text, candidate),
        });
      }
    }
  }

  for (const f of facilities) {
    if (seen.has(f.id)) continue;
    if (f.name.length >= 4 && text.includes(f.name)) {
      seen.add(f.id);
      out.push({
        facility_id: f.id,
        match_method: 'dict_aho',
        match_score: 0.85,
        match_evidence: f.name,
        excerpt: makeExcerpt(text, f.name),
      });
    }
  }

  return out;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  const { data: facilities, error: facErr } = await supabase
    .from('facilities')
    .select('id, name')
    .not('name', 'is', null);
  if (facErr) return new Response(JSON.stringify({ error: facErr.message }), { status: 500 });

  const { data: jobs, error: dqErr } = await supabase.rpc('read_matching_jobs', {
    p_batch_size: BATCH_SIZE,
    p_vt_seconds: VT_SECONDS,
  });
  if (dqErr) return new Response(JSON.stringify({ error: dqErr.message }), { status: 500 });

  if (!jobs || (jobs as unknown[]).length === 0) {
    return new Response(JSON.stringify({ processed: 0, message: 'empty queue' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const postIds = (jobs as { msg_id: number; post_id: string }[]).map((j) => j.post_id);
  const { data: posts, error: pErr } = await supabase
    .from('source_posts')
    .select('id, title, content_text')
    .in('id', postIds);
  if (pErr) return new Response(JSON.stringify({ error: pErr.message }), { status: 500 });

  const postById = new Map((posts ?? []).map((p) => [p.id as string, p]));

  let totalMentions = 0;
  let acked = 0;

  for (const job of jobs as { msg_id: number; post_id: string }[]) {
    const post = postById.get(job.post_id);
    if (!post) {
      await supabase.rpc('ack_matching_job', { p_msg_id: job.msg_id });
      acked += 1;
      continue;
    }
    const text = (post.content_text as string | null) ?? stripHtml(((post.title as string | null) ?? ''));
    if (!text) {
      await supabase.rpc('ack_matching_job', { p_msg_id: job.msg_id });
      acked += 1;
      continue;
    }

    const found = matchFacilities(text, (facilities ?? []) as FacilityRow[]);
    if (found.length > 0) {
      const rows: MentionRow[] = found.map((f) => ({ ...f, post_id: job.post_id }));
      const { error: insErr } = await supabase
        .from('facility_mentions')
        .upsert(rows, { onConflict: 'facility_id,post_id', ignoreDuplicates: true });
      if (insErr) {
        console.error(`mention insert failed for ${job.post_id}:`, insErr.message);
        continue;
      }
      totalMentions += rows.length;
    }

    await supabase.rpc('ack_matching_job', { p_msg_id: job.msg_id });
    acked += 1;
  }

  return new Response(
    JSON.stringify({ processed: acked, mentions_created: totalMentions }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
