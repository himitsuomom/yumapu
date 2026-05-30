/**
 * OSM Collector — Overpass API で都道府県単位の温泉・銭湯・サウナを収集し
 * facility_candidates にINSERT する。
 *
 * 実行: npx tsx scout/national/osm-collector.ts --prefecture 沖縄県
 */

import 'dotenv/config'
import * as https from 'https'
import * as querystring from 'querystring'
import { createClient } from '@supabase/supabase-js'
import type { Prefecture } from './prefectures.js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

// lz4.overpass-api.de: User-Agent 付きネイティブ HTTPS で安定動作
const OVERPASS_HOST = 'lz4.overpass-api.de'
const OVERPASS_PATH = '/api/interpreter'
const REQUEST_DELAY = 3000  // Overpass 推奨: 3秒以上

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

/** Overpass API を node https モジュール経由で呼ぶ（fetch は一部環境で403/406になるため） */
function overpassQuery(query: string): Promise<OverpassResponse> {
  return new Promise((resolve, reject) => {
    const data = querystring.stringify({ data: query })
    const options: https.RequestOptions = {
      hostname: OVERPASS_HOST,
      path: OVERPASS_PATH,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(data),
        'User-Agent': 'YuMapBot/1.0 (yumap.app; contact: info@yumap.app)',
      },
    }
    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        res.resume()
        reject(new Error(`Overpass HTTP ${res.statusCode}`))
        return
      }
      let body = ''
      res.setEncoding('utf8')
      res.on('data', (chunk: string) => { body += chunk })
      res.on('end', () => {
        try { resolve(JSON.parse(body) as OverpassResponse) }
        catch (e) { reject(e) }
      })
    })
    req.on('error', reject)
    req.setTimeout(90000, () => { req.destroy(new Error('Overpass timeout')) })
    req.write(data)
    req.end()
  })
}

type FacilityType = 'onsen' | 'public_bath' | 'sauna' | 'spa' | 'unknown'

function detectFacilityType(tags: Record<string, string>): FacilityType {
  if (tags['leisure'] === 'sauna') return 'sauna'
  if (tags['leisure'] === 'hot_spring' || tags['bath:type'] === 'onsen') return 'onsen'
  if (tags['amenity'] === 'spa') return 'spa'
  if (tags['amenity'] === 'public_bath') return 'public_bath'
  return 'unknown'
}

interface OverpassElement {
  type: 'node' | 'way' | 'relation'
  id: number
  lat?: number
  lon?: number
  center?: { lat: number; lon: number }
  tags?: Record<string, string>
}

interface OverpassResponse {
  elements: OverpassElement[]
}

export async function collectOsm(pref: Prefecture): Promise<number> {
  const [S, W, N, E] = pref.bbox
  const query = `[out:json][timeout:60];
(
  node["amenity"="public_bath"](${S},${W},${N},${E});
  way["amenity"="public_bath"](${S},${W},${N},${E});
  node["leisure"="sauna"](${S},${W},${N},${E});
  way["leisure"="sauna"](${S},${W},${N},${E});
  node["amenity"="spa"](${S},${W},${N},${E});
  way["amenity"="spa"](${S},${W},${N},${E});
  node["leisure"="hot_spring"](${S},${W},${N},${E});
  way["leisure"="hot_spring"](${S},${W},${N},${E});
);
out center tags;`

  console.log(`  [OSM] Overpass クエリ送信... (${pref.name})`)

  const result = await overpassQuery(query)
  const elements = result.elements ?? []
  console.log(`  [OSM] ${elements.length} 件取得`)

  if (elements.length === 0) return 0

  // バッチINSERT（UPSERT で重複スキップ）
  const rows = elements
    .map(el => {
      const lat = el.lat ?? el.center?.lat
      const lon = el.lon ?? el.center?.lon
      if (!lat || !lon) return null

      const tags = el.tags ?? {}
      const name = tags['name'] ?? tags['name:ja'] ?? ''
      if (!name || name.length < 2) return null

      return {
        name,
        latitude: Math.round(lat * 1e6) / 1e6,
        longitude: Math.round(lon * 1e6) / 1e6,
        prefecture: pref.name,
        address: tags['addr:full'] ?? tags['addr:city'] ?? null,
        website: tags['website'] ?? tags['contact:website'] ?? tags['url'] ?? null,
        phone: tags['phone'] ?? tags['contact:phone'] ?? null,
        facility_type: detectFacilityType(tags),
        source: 'osm' as const,
        source_id: `${el.type}/${el.id}`,
        raw_json: tags,
      }
    })
    .filter((r): r is NonNullable<typeof r> => r !== null)

  if (rows.length === 0) return 0

  // 500件ずつ分割してINSERT
  let inserted = 0
  const CHUNK = 500
  for (let i = 0; i < rows.length; i += CHUNK) {
    const chunk = rows.slice(i, i + CHUNK)
    const { error } = await supabase
      .from('facility_candidates')
      .upsert(chunk, { onConflict: 'source,source_id', ignoreDuplicates: true })

    if (error) {
      console.error(`  [OSM] INSERT エラー: ${error.message}`)
    } else {
      inserted += chunk.length
    }
  }

  return inserted
}

// スタンドアロン実行
if (process.argv[1]?.includes('osm-collector')) {
  const { PREFECTURES } = await import('./prefectures.js')
  const prefName = process.argv[process.argv.indexOf('--prefecture') + 1]
  const targets = prefName ? PREFECTURES.filter(p => p.name === prefName) : PREFECTURES

  for (const pref of targets) {
    try {
      const n = await collectOsm(pref)
      console.log(`✅ ${pref.name}: ${n} 件 INSERT`)
      if (targets.indexOf(pref) < targets.length - 1) await sleep(REQUEST_DELAY)
    } catch (err) {
      console.error(`❌ ${pref.name}: ${err instanceof Error ? err.message : err}`)
    }
  }
  process.exit(0)
}
