/**
 * OSM URL Enricher
 * OpenStreetMap Overpass API を使い施設の公式サイトURLを補完する
 *
 * 全施設が lat/lng を持つため、座標 + 施設名で OSM を検索し
 * website タグが見つかれば facilities.website に書き込む。
 * DBトリガーが crawl_schedule を自動更新 → Commander がクロール開始。
 *
 * 実行: npx tsx scout/url-enricher-osm.ts
 * テスト: npx tsx scout/url-enricher-osm.ts --test --limit 10
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

const BATCH_SIZE    = parseInt(process.env.ENRICH_BATCH ?? '500')
const REQUEST_DELAY = 1200   // Nominatim: 1秒以上の間隔が必須
const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

/** 施設名を OSM 検索用に正規化（記号・ブランド名のカッコ書きを除去） */
function normalizeName(name: string): string {
  return name
    .replace(/[（(][^）)]*[）)]/g, '')  // カッコ内除去
    .replace(/[:：]/g, '')
    .trim()
}

/** Nominatim で施設名 + 日本を検索し website タグを返す */
async function fetchOsmWebsite(lat: number, lng: number, facilityName: string): Promise<string | null> {
  const targetName = normalizeName(facilityName)

  // 施設名で検索、座標の viewbox で絞り込み（±0.05度 ≒ 5km）
  const params = new URLSearchParams({
    q:           targetName,
    countrycodes: 'jp',
    format:      'jsonv2',
    extratags:   '1',
    limit:       '5',
    viewbox:     `${lng - 0.05},${lat + 0.05},${lng + 0.05},${lat - 0.05}`,
    bounded:     '1',
  })

  const res = await fetch(`${NOMINATIM_URL}?${params}`, {
    headers: { 'User-Agent': 'YuMapBot/1.0 (https://yumap.app/bot)', 'Accept': 'application/json' },
    signal:  AbortSignal.timeout(15000),
  })

  if (!res.ok) throw new Error(`Nominatim HTTP ${res.status}`)

  type NominatimResult = { display_name: string; extratags?: Record<string, string> }
  const results = await res.json() as NominatimResult[]

  for (const r of results) {
    const website = r.extratags?.website || r.extratags?.['contact:website'] || r.extratags?.url
    if (website) return website.startsWith('http') ? website : `https://${website}`
  }

  // viewbox 内に結果なし → 日本全体で再検索（website ありのみ）
  const params2 = new URLSearchParams({
    q:           targetName,
    countrycodes: 'jp',
    format:      'jsonv2',
    extratags:   '1',
    limit:       '3',
  })
  const res2 = await fetch(`${NOMINATIM_URL}?${params2}`, {
    headers: { 'User-Agent': 'YuMapBot/1.0 (https://yumap.app/bot)', 'Accept': 'application/json' },
    signal:  AbortSignal.timeout(15000),
  })
  if (!res2.ok) return null

  const results2 = await res2.json() as NominatimResult[]
  for (const r of results2) {
    const website = r.extratags?.website || r.extratags?.['contact:website'] || r.extratags?.url
    if (website) return website.startsWith('http') ? website : `https://${website}`
  }
  return null
}

async function runEnricher() {
  const isTest = process.argv.includes('--test')
  const limit  = isTest
    ? parseInt(process.argv[process.argv.indexOf('--limit') + 1] ?? '10')
    : BATCH_SIZE

  console.log(`\n🗺️  OSM URL Enricher 起動 — ${isTest ? 'テスト' : '本番'}モード (${limit}件)\n`)

  // URL未設定 & 座標あり の施設を取得
  const { data: facilities, error } = await supabase
    .from('facilities')
    .select(`
      id, name, latitude, longitude,
      crawl_schedule!inner(official_site_url)
    `)
    .is('website', null)
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .is('crawl_schedule.official_site_url', null)
    .limit(limit)

  if (error) { console.error('DB取得エラー:', error.message); process.exit(1) }
  if (!facilities?.length) { console.log('⭕ 対象施設なし'); return }

  console.log(`📋 対象: ${facilities.length}件\n`)

  let found = 0, notFound = 0, errors = 0

  for (const f of facilities) {
    const lat = f.latitude as number
    const lng = f.longitude as number

    try {
      const website = await fetchOsmWebsite(lat, lng, f.name)

      if (website) {
        // facilities.website を更新 → DBトリガーが crawl_schedule + agent_queue を自動更新
        const { error: upErr } = await supabase
          .from('facilities')
          .update({ website })
          .eq('id', f.id)

        if (upErr) throw new Error(upErr.message)
        console.log(`  ✅ ${f.name.slice(0, 30).padEnd(30)} → ${website}`)
        found++
      } else {
        process.stdout.write('.')
        notFound++
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message.slice(0, 80) : String(err)
      console.log(`  ❌ ${f.name.slice(0, 30)} — ${msg}`)
      errors++
    }

    await sleep(REQUEST_DELAY)
  }

  console.log(`\n\n📊 完了: ✅発見${found}件 / ⭕未発見${notFound}件 / ❌エラー${errors}件`)
  console.log(`   → Commander が新しいURLを自動検知してクロール開始します`)
}

runEnricher()
  .catch(err => console.error('Fatal:', err instanceof Error ? err.message : err))
  .finally(() => process.exit(0))
