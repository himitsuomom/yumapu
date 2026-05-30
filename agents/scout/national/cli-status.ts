/**
 * CLI Status — 進捗確認ツール
 *
 * 実行: npx tsx scout/national/cli-status.ts
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

async function main() {
  console.log('\n📊 YuMap 全国施設収集 進捗レポート\n')

  // coverage_progress 全件
  const { data: progress, error: progError } = await supabase
    .from('coverage_progress')
    .select('*')
    .order('prefecture')
    .order('source')

  if (progError) {
    console.error('coverage_progress 取得エラー:', progError.message)
    process.exit(1)
  }

  // ステータス別集計
  const statusCount: Record<string, number> = {}
  for (const row of progress ?? []) {
    statusCount[row.status] = (statusCount[row.status] ?? 0) + 1
  }

  console.log('■ coverage_progress サマリー')
  for (const [status, count] of Object.entries(statusCount).sort()) {
    const icon = status === 'done' ? '✅' : status === 'in_progress' ? '🔄' : status === 'error' ? '❌' : '⏳'
    console.log(`  ${icon} ${status.padEnd(12)} ${count} 件`)
  }

  // エラー行を表示
  const errors = (progress ?? []).filter(r => r.status === 'error')
  if (errors.length > 0) {
    console.log('\n⚠️  エラー詳細:')
    for (const e of errors.slice(0, 10)) {
      console.log(`  ${e.prefecture} / ${e.source}: ${e.last_error?.slice(0, 80)}`)
    }
  }

  // facility_candidates 統計
  const { data: candStats, error: candError } = await supabase
    .from('facility_candidates')
    .select('status')

  if (!candError && candStats) {
    const candCount: Record<string, number> = {}
    for (const row of candStats) {
      candCount[row.status] = (candCount[row.status] ?? 0) + 1
    }

    console.log('\n■ facility_candidates')
    for (const [status, count] of Object.entries(candCount).sort()) {
      const icon = status === 'promoted' ? '✅' : status === 'pending' ? '⏳' : status === 'duplicate' ? '🔁' : '❌'
      console.log(`  ${icon} ${status.padEnd(12)} ${count.toLocaleString()} 件`)
    }
    console.log(`  合計: ${candStats.length.toLocaleString()} 件`)
  }

  // facilities 総数
  const { count: facilityCount, error: facError } = await supabase
    .from('facilities')
    .select('*', { count: 'exact', head: true })
    .is('merged_into', null)

  if (!facError) {
    console.log(`\n■ facilities (有効): ${(facilityCount ?? 0).toLocaleString()} 件`)
  }

  // 都道府県×ソース マトリクス（doneのみ要約）
  const donePrefs = (progress ?? []).filter(r => r.status === 'done')
  if (donePrefs.length > 0) {
    console.log(`\n■ 完了済み (done): ${donePrefs.length} 件`)
    const byPref: Record<string, string[]> = {}
    for (const row of donePrefs) {
      byPref[row.prefecture] = byPref[row.prefecture] ?? []
      byPref[row.prefecture].push(row.source)
    }
    const prefList = Object.entries(byPref)
      .map(([pref, sources]) => `${pref}(${sources.join('/')})`)
      .slice(0, 20)
    console.log(`  ${prefList.join(', ')}${Object.keys(byPref).length > 20 ? ' ...' : ''}`)
  }

  console.log('')
  process.exit(0)
}

main().catch(err => {
  console.error('Fatal:', err instanceof Error ? err.message : err)
  process.exit(1)
})
