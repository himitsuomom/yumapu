/**
 * Google Collector — Google Places Text Search API で施設を収集し
 * facility_candidates にINSERT する。
 *
 * GOOGLE_MAPS_KEY_ANDROID は app/.env から読む。
 * 実行: npx tsx scout/national/google-collector.ts --prefecture 沖縄県
 */

import dotenv from 'dotenv'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
// agents/.env を先に読み、app/.env で GOOGLE_MAPS_KEY_ANDROID を上書き
dotenv.config({ path: path.join(__dirname, '../../.env') })
dotenv.config({ path: path.join(__dirname, '../../../.env') })

import { createClient } from '@supabase/supabase-js'
import type { Prefecture } from './prefectures.js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

const GOOGLE_MAPS_KEY = process.env.GOOGLE_MAPS_KEY_ANDROID ?? ''
const PAGE_DELAY = 2000   // nextPageToken が有効になるまで必要

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

interface PlaceResult {
  place_id?: string
  name?: string
  geometry?: { location?: { lat: number; lng: number } }
  formatted_address?: string
  formatted_phone_number?: string
  types?: string[]
}

interface PlacesResponse {
  results?: PlaceResult[]
  next_page_token?: string
  status?: string
}

function detectTypeFromQuery(query: string): 'onsen' | 'public_bath' | 'sauna' {
  if (query.includes('温泉')) return 'onsen'
  if (query.includes('サウナ')) return 'sauna'
  return 'public_bath'
}

async function fetchPlacesPage(
  query: string,
  lat: number,
  lng: number,
  radiusM: number,
  pageToken?: string
): Promise<PlacesResponse> {
  const params = new URLSearchParams({
    language: 'ja',
    key: GOOGLE_MAPS_KEY,
  })

  if (pageToken) {
    params.set('pagetoken', pageToken)
  } else {
    params.set('query', query)
    params.set('location', `${lat},${lng}`)
    params.set('radius', String(radiusM))
  }

  const res = await fetch(
    `https://maps.googleapis.com/maps/api/place/textsearch/json?${params}`,
    { signal: AbortSignal.timeout(15000) }
  )

  if (!res.ok) throw new Error(`Google Places HTTP ${res.status}`)
  return res.json() as Promise<PlacesResponse>
}

export async function collectGoogle(pref: Prefecture): Promise<number> {
  if (!GOOGLE_MAPS_KEY) throw new Error('GOOGLE_MAPS_KEY_ANDROID が未設定です')

  const { lat, lng } = pref.center
  const radiusM = pref.searchRadiusKm * 1000
  const queries = [`${pref.name}の温泉`, `${pref.name}の銭湯`, `${pref.name}のサウナ`]
  let totalInserted = 0

  for (const query of queries) {
    let pageToken: string | undefined = undefined
    let pageCount = 0

    do {
      try {
        if (pageToken) await sleep(PAGE_DELAY)  // nextPageToken が有効になるまで待機

        const data = await fetchPlacesPage(query, lat, lng, radiusM, pageToken)

        if (data.status === 'REQUEST_DENIED') throw new Error('GOOGLE_KEY_INVALID')
        if (data.status === 'ZERO_RESULTS' || !data.results?.length) break

        const rows = data.results
          .map(result => {
            if (!result.place_id || !result.name || !result.geometry?.location) return null
            return {
              name: result.name,
              latitude: Math.round(result.geometry.location.lat * 1e6) / 1e6,
              longitude: Math.round(result.geometry.location.lng * 1e6) / 1e6,
              prefecture: pref.name,
              address: result.formatted_address ?? null,
              website: null,   // Text Search API はwebsiteを返さない
              phone: null,
              facility_type: detectTypeFromQuery(query),
              source: 'google' as const,
              source_id: result.place_id,
              raw_json: result,
            }
          })
          .filter((r): r is NonNullable<typeof r> => r !== null)

        if (rows.length > 0) {
          const { error } = await supabase
            .from('facility_candidates')
            .upsert(rows, { onConflict: 'source,source_id', ignoreDuplicates: true })

          if (error) {
            console.error(`  [Google] INSERT エラー (${query}): ${error.message}`)
          } else {
            totalInserted += rows.length
          }
        }

        pageToken = data.next_page_token
        pageCount++
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err)
        if (msg === 'GOOGLE_KEY_INVALID') throw new Error('GOOGLE_KEY_INVALID')
        console.warn(`  [Google] エラー (${query} page ${pageCount}): ${msg}`)
        break
      }
    } while (pageToken && pageCount < 3)  // 最大3ページ（60件）
  }

  return totalInserted
}

// スタンドアロン実行
if (process.argv[1]?.includes('google-collector')) {
  const { PREFECTURES } = await import('./prefectures.js')
  const prefName = process.argv[process.argv.indexOf('--prefecture') + 1]
  const targets = prefName ? PREFECTURES.filter(p => p.name === prefName) : PREFECTURES

  for (const pref of targets) {
    try {
      const n = await collectGoogle(pref)
      console.log(`✅ ${pref.name}: ${n} 件 INSERT`)
    } catch (err) {
      console.error(`❌ ${pref.name}: ${err instanceof Error ? err.message : err}`)
    }
  }
  process.exit(0)
}
