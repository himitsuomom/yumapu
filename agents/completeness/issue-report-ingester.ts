import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!)

export async function ingestIssueReports(): Promise<{ applied: number; skipped: number }> {
  const { data: reports } = await supabase
    .from('facility_issue_reports')
    .select('id, facility_id, suggested_url')
    .eq('status', 'pending')
    .not('suggested_url', 'is', null)
    .is('ingested_at', null)
    .limit(500)

  let applied = 0, skipped = 0
  for (const r of reports ?? []) {
    const { data: ok } = await supabase.rpc('apply_url_with_priority', {
      p_facility_id: r.facility_id,
      p_url: r.suggested_url,
      p_source: 'user_report',
    })
    if (ok) {
      applied++
      console.log(`  ✅ ${r.facility_id.slice(0, 8)} → ${r.suggested_url!.slice(0, 50)}`)
    } else skipped++

    await supabase.from('facility_issue_reports')
      .update({ status: 'reviewed', ingested_at: new Date().toISOString() })
      .eq('id', r.id)
  }
  if (applied + skipped > 0)
    console.log(`\n📥 報告取り込み: 適用${applied}件 / スキップ${skipped}件`)
  return { applied, skipped }
}

if (process.argv[1]?.includes('issue-report-ingester')) {
  ingestIssueReports().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1) })
}
