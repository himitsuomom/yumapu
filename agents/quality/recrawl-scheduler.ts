import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!)

export async function scheduleRecrawls(limit = 100): Promise<number> {
  const { data: stale } = await supabase.rpc('get_stale_facilities', { p_limit: limit })
  if (!stale?.length) { console.log('  古い施設なし'); return 0 }

  for (const s of stale as Array<{ facility_id: string }>) {
    await supabase.from('crawl_schedule')
      .update({ status: 'pending', data_complete: false, priority: 3 })
      .eq('facility_id', s.facility_id)
  }
  console.log(`♻️  再クロール: ${stale.length}件を pending 化（90日以上未更新）`)
  return stale.length
}

if (process.argv[1]?.includes('recrawl-scheduler')) {
  scheduleRecrawls().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1) })
}
