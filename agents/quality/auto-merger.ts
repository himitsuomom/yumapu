import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!)

export async function runAutoMerge(limit = 200): Promise<{ merged: number; flagged: number }> {
  const { data: candidates } = await supabase.rpc('get_auto_merge_candidates', { p_limit: limit })
  if (!candidates?.length) { console.log('  自動マージ対象なし'); return { merged: 0, flagged: 0 } }

  let merged = 0, flagged = 0
  for (const c of candidates as Array<{ facility_id: string }>) {
    try {
      // raw_facility_data から最新の高信頼データを取得
      const { data: raw } = await supabase
        .from('raw_facility_data')
        .select('raw_json, conflict_info')
        .eq('facility_id', c.facility_id)
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (!raw) continue

      const rj = raw.raw_json as Record<string, unknown>
      const hasIssues = (raw.conflict_info as Record<string, unknown> | null)?.validation_issues

      if (hasIssues) {
        await supabase.from('raw_facility_data')
          .update({ status: 'flagged' })
          .eq('facility_id', c.facility_id).eq('status', 'pending')
        flagged++
      } else {
        // facilities にマージ
        const updates: Record<string, unknown> = {}
        if (rj.price_adult != null) updates['price_info'] = { adult: rj.price_adult, description: `大人 ${rj.price_adult}円` }
        if (rj.hours != null) updates['business_hours'] = { description: rj.hours }
        if (rj.phone != null) updates['phone'] = rj.phone

        if (Object.keys(updates).length > 0) {
          await supabase.from('facilities').update(updates).eq('id', c.facility_id)
        }
        await supabase.from('raw_facility_data')
          .update({ status: 'merged' })
          .eq('facility_id', c.facility_id).eq('status', 'pending')
        await supabase.from('crawl_schedule')
          .update({ data_complete: true })
          .eq('facility_id', c.facility_id)
        merged++
        console.log(`  ✅ ${c.facility_id.slice(0, 8)} マージ完了`)
      }
    } catch (err: unknown) {
      console.error(`  ❌ ${c.facility_id.slice(0, 8)} エラー:`, err instanceof Error ? err.message : err)
    }
  }
  console.log(`🔀 自動マージ: ${merged}件 / フラグ:${flagged}件`)
  return { merged, flagged }
}

if (process.argv[1]?.includes('auto-merger')) {
  runAutoMerge().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1) })
}
