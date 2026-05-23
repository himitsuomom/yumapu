import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL!;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const annotator = process.env.ANNOTATOR ?? 'reviewer_default';

const supabase = createClient(url, key, { auth: { persistSession: false } });

async function main() {
  const { data: mentions, error } = await supabase
    .from('facility_mentions')
    .select('post_id, facility_id, match_evidence, is_correct')
    .not('is_correct', 'is', null)
    .limit(5000);
  if (error) throw new Error(error.message);
  if (!mentions) return;

  const rows = (mentions as { post_id: string; facility_id: string; match_evidence: string; is_correct: boolean }[]).map((m) => ({
    post_id: m.post_id,
    entity_text: m.match_evidence ?? '',
    entity_type: m.is_correct ? 'facility' : 'non_facility',
    expected_facility_id: m.is_correct ? m.facility_id : null,
    annotator,
    notes: 'seeded from facility_mentions.is_correct',
  }));

  const { error: insErr } = await supabase
    .from('gold_annotations')
    .upsert(rows, { onConflict: 'post_id,entity_text,annotator', ignoreDuplicates: true });
  if (insErr) throw new Error(insErr.message);

  console.log(`[seed-gold] ${rows.length}件を gold_annotations に投入しました`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
