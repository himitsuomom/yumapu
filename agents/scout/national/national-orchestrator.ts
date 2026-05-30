/**
 * National Orchestrator — 47都道府県を順次処理するメインスクリプト。
 *
 * 実行: npx tsx scout/national/national-orchestrator.ts
 * 再開: npx tsx scout/national/national-orchestrator.ts --resume
 * 単一: npx tsx scout/national/national-orchestrator.ts --prefecture 沖縄県
 * ソース: npx tsx scout/national/national-orchestrator.ts --source osm
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'
import { PREFECTURES } from './prefectures.js'
import { collectOsm } from './osm-collector.js'
import { collectHere } from './here-collector.js'
import { collectGoogle } from './google-collector.js'
import { promoteAll } from './promoter.js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

type Source = 'osm' | 'here' | 'google'
const ALL_SOURCES: Source[] = ['osm', 'here', 'google']

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

async function updateProgress(
  prefecture: string,
  source: Source,
  status: string,
  extra: Record<string, unknown> = {}
) {
  const { error } = await supabase
    .from('coverage_progress')
    .update({ status, ...extra })
    .eq('prefecture', prefecture)
    .eq('source', source)

  if (error) console.warn(`  [Progress] 更新失敗 ${prefecture}/${source}: ${error.message}`)
}

async function collectForSource(
  pref: typeof PREFECTURES[0],
  source: Source
): Promise<number> {
  await updateProgress(pref.name, source, 'in_progress', { started_at: new Date().toISOString() })

  try {
    let count = 0
    if (source === 'osm') count = await collectOsm(pref)
    else if (source === 'here') count = await collectHere(pref)
    else count = await collectGoogle(pref)

    await updateProgress(pref.name, source, 'done', {
      candidates_found: count,
      completed_at: new Date().toISOString(),
    })
    return count
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    await updateProgress(pref.name, source, 'error', { last_error: msg })
    throw err
  }
}

async function main() {
  const args = process.argv.slice(2)
  const prefName = args.includes('--prefecture')
    ? args[args.indexOf('--prefecture') + 1]
    : undefined
  const sourceArg = args.includes('--source')
    ? (args[args.indexOf('--source') + 1] as Source)
    : undefined
  const isResume = args.includes('--resume')

  // 対象都道府県を決定
  let targets = prefName ? PREFECTURES.filter(p => p.name === prefName) : PREFECTURES

  // --resume: pending/error のみ
  if (isResume && !prefName) {
    const { data: pending } = await supabase
      .from('coverage_progress')
      .select('prefecture, source')
      .in('status', ['pending', 'error'])

    if (pending?.length) {
      const pendingPrefs = new Set(pending.map(r => r.prefecture))
      targets = PREFECTURES.filter(p => pendingPrefs.has(p.name))
    } else {
      console.log('✅ 全都道府県完了済み（resumeする項目なし）')
      process.exit(0)
    }
  }

  const sources = sourceArg ? [sourceArg] : ALL_SOURCES

  console.log(`\n🗾 全国施設収集 開始`)
  console.log(`   対象: ${targets.length}件 | ソース: ${sources.join(', ')}\n`)

  let totalCandidates = 0

  for (const pref of targets) {
    console.log(`\n▶ ${pref.name}`)

    for (const source of sources) {
      console.log(`  → ${source}`)
      try {
        const count = await collectForSource(pref, source)
        totalCandidates += count
        console.log(`     ${count} 件収集`)
        await sleep(1000)
      } catch (err) {
        console.error(`  ❌ ${source}: ${err instanceof Error ? err.message : err}`)
      }
    }

    // 都道府県ごとに昇格
    console.log(`  → 昇格処理`)
    const result = await promoteAll(pref.name)
    console.log(`     promoted=${result.promoted} dup=${result.duplicate} rejected=${result.rejected}`)
  }

  console.log(`\n✅ 全処理完了: candidates=${totalCandidates}`)
  process.exit(0)
}

main().catch(err => {
  console.error('Fatal:', err instanceof Error ? err.message : err)
  process.exit(1)
})
