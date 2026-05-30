import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!)

export async function printCoverage(): Promise<void> {
  const { data: summary } = await supabase.from('v_coverage_summary').select('*').single()
  const { data: pref } = await supabase.from('v_coverage_by_prefecture').select('*')

  console.log('\n📊 カバレッジサマリ')
  if (summary) {
    console.log(`  総数:${summary.total} / URLあり:${summary.with_url} (${summary.url_rate_pct}%) / 完了:${summary.complete}`)
    console.log(`  ソース別: official=${summary.src_official} yahoo=${summary.src_yahoo} here=${summary.src_here} user=${summary.src_user}`)
  }
  console.log('\n📍 都道府県別 (URL取得率ワースト10)')
  const worst = (pref ?? []).filter((p: { total_facilities: number }) => p.total_facilities > 0)
    .sort((a: { url_rate: number }, b: { url_rate: number }) => (a.url_rate ?? 0) - (b.url_rate ?? 0)).slice(0, 10)
  for (const p of worst) {
    console.log(`  ${String(p.prefecture_name).padEnd(6)} ${p.with_url}/${p.total_facilities} (${p.url_rate ?? 0}%)`)
  }
}

if (process.argv[1]?.includes('coverage-reporter')) {
  printCoverage().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1) })
}
