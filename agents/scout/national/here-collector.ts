/**
 * HERE Collector — HERE Discover API で都道府県の施設を収集し
 * facility_candidates にINSERT する。
 *
 * 実行: npx tsx scout/national/here-collector.ts --prefecture 沖縄県
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'
import type { Prefecture } from './prefectures.js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

const HERE_API_KEY = process.env.HERE_API_KEY ?? ''
const REQUEST_DELAY = 500

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

interface HereItem {
  id?: string
  title?: string
  position?: { lat: number; lng: number }
  address?: { label?: string }
  contacts?: Array<{
    www?: Array<{ value?: string }>
    phone?: Array<{ value?: string }>
  }>
}

interface HereResponse {
  items?: HereItem[]
}

const SEARCH_QUERIES = ['温泉', '銭湯', 'サウナ', '健康ランド', '日帰り温泉']

export async function collectHere(pref: Prefecture): Promise<number> {
  if (!HERE_API_KEY) throw new Error('HERE_API_KEY が未設定です')

  const { lat, lng } = pref.center
  const radiusM = pref.searchRadiusKm * 1000
  let totalInserted = 0

  for (const query of SEARCH_QUERIES) {
    const params = new URLSearchParams({
      at: `${lat},${lng}`,
      in: `circle:${lat},${lng};r=${radiusM}`,
      q: query,
      limit: '100',
      lang: 'ja',
      apiKey: HERE_API_KEY,
    })

    try {
      const res = await fetch(
        `https://discover.search.hereapi.com/v1/discover?${params}`,
        {
          headers: { 'User-Agent': 'YuMapBot/1.0 (https://yumap.app/bot)' },
          signal: AbortSignal.timeout(15000),
        }
      )

      if (res.status === 401) throw new Error('HERE_KEY_INVALID')
      if (!res.ok) {
        console.warn(`  [HERE] HTTP ${res.status} for query "${query}"`)
        await sleep(REQUEST_DELAY)
        continue
      }

      const data = await res.json() as HereResponse
      const items = data.items ?? []

      if (items.length === 0) {
        await sleep(REQUEST_DELAY)
        continue
      }

      const rows = items
        .map(item => {
          if (!item.position || !item.title || !item.id) return null
          return {
            name: item.title,
            latitude: Math.round(item.position.lat * 1e6) / 1e6,
            longitude: Math.round(item.position.lng * 1e6) / 1e6,
            prefecture: pref.name,
            address: item.address?.label ?? null,
            website: item.contacts?.[0]?.www?.[0]?.value ?? null,
            phone: item.contacts?.[0]?.phone?.[0]?.value ?? null,
            facility_type: query === 'サウナ' ? 'sauna' : query === '温泉' || query === '日帰り温泉' ? 'onsen' : 'public_bath',
            source: 'here' as const,
            source_id: item.id,
            raw_json: item,
          }
        })
        .filter((r): r is NonNullable<typeof r> => r !== null)

      if (rows.length > 0) {
        const { error } = await supabase
          .from('facility_candidates')
          .upsert(rows, { onConflict: 'source,source_id', ignoreDuplicates: true })

        if (error) {
          console.error(`  [HERE] INSERT エラー (${query}): ${error.message}`)
        } else {
          totalInserted += rows.length
        }
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      if (msg === 'HERE_KEY_INVALID') throw new Error('HERE_KEY_INVALID')
      console.warn(`  [HERE] エラー (${query}): ${msg}`)
    }

    await sleep(REQUEST_DELAY)
  }

  return totalInserted
}

// スタンドアロン実行
if (process.argv[1]?.includes('here-collector')) {
  const { PREFECTURES } = await import('./prefectures.js')
  const prefName = process.argv[process.argv.indexOf('--prefecture') + 1]
  const targets = prefName ? PREFECTURES.filter(p => p.name === prefName) : PREFECTURES

  for (const pref of targets) {
    try {
      const n = await collectHere(pref)
      console.log(`✅ ${pref.name}: ${n} 件 INSERT`)
    } catch (err) {
      console.error(`❌ ${pref.name}: ${err instanceof Error ? err.message : err}`)
    }
  }
  process.exit(0)
}
