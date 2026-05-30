/**
 * Multi-Source URL Enricher
 * Yahoo! ローカルサーチ（YOLP）+ HERE Platform で施設の公式サイトURLを補完する
 *
 * Yahoo! YOLP 業種コード（gc）:
 *   0418001 = 銭湯 / 0418002 = スーパー銭湯 / 0418003 = 健康ランド
 *   0418004 = 温泉浴場 / 0418005 = 岩盤浴 / 0418006 = サウナ
 *
 * HERE Platform 無料枠: 250,000件/月（全11,018件を1日で処理可能）
 * キー取得: https://platform.here.com/ → 無料アカウント作成 → API Key 発行
 *
 * 実行前に .env に以下を追加:
 *   YAHOO_APP_ID=あなたのYahoo Client ID
 *   HERE_API_KEY=あなたのHERE API Key
 *
 * 実行: npx tsx scout/url-enricher-multi.ts
 * テスト: npx tsx scout/url-enricher-multi.ts --test --limit 20
 * 再開:   npx tsx scout/url-enricher-multi.ts --offset 1000
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

const YAHOO_APP_ID = process.env.YAHOO_APP_ID ?? ''
const HERE_API_KEY = process.env.HERE_API_KEY ?? ''

const BATCH_SIZE  = parseInt(process.env.ENRICH_BATCH ?? '1000')
const YAHOO_DELAY = 250   // Yahoo: 4req/sec 以内
const HERE_DELAY  = 100   // HERE: 無料枠でも十分速い

// YuMap 対象業種コード（温泉・銭湯・スパ・サウナ全種）
const YAHOO_GC_CODES = ['0418001', '0418002', '0418003', '0418004', '0418005', '0418006']

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

function normalizeName(name: string): string {
  return name
    .replace(/[（(][^）)]*[）)]/g, '')
    .replace(/[:：;；]/g, ' ')
    .trim()
}

// ── Yahoo! ローカルサーチ（YOLP） ────────────────────────────────────────────

async function yahooSearch(name: string, lat: number, lng: number): Promise<string | null> {
  if (!YAHOO_APP_ID) return null

  // 業種コードを順番に試す
  for (const gc of YAHOO_GC_CODES) {
    const params = new URLSearchParams({
      appid:   YAHOO_APP_ID,
      query:   normalizeName(name),
      lat:     String(lat),
      lon:     String(lng),
      dist:    '1',
      results: '5',
      gc,
      output:  'json',
    })

    try {
      const res = await fetch(
        `https://map.yahooapis.jp/search/local/V1/localSearch?${params}`,
        {
          headers: { 'User-Agent': 'YuMapBot/1.0 (https://yumap.app/bot)' },
          signal: AbortSignal.timeout(10000),
        }
      )
      if (res.status === 403) throw new Error('YAHOO_KEY_INVALID')
      if (!res.ok) continue

      const json = await res.json() as {
        Feature?: Array<{ Property?: { Url?: string } }>
      }
      for (const f of json.Feature ?? []) {
        const url = f.Property?.Url
        if (url?.startsWith('http')) return url
      }
    } catch (err: unknown) {
      if (err instanceof Error && err.message === 'YAHOO_KEY_INVALID') throw err
    }
    await sleep(YAHOO_DELAY)
  }

  // 業種コードなし・フォールバック
  const params = new URLSearchParams({
    appid: YAHOO_APP_ID, query: normalizeName(name),
    lat: String(lat), lon: String(lng), dist: '1', results: '3', output: 'json',
  })
  try {
    const res = await fetch(
      `https://map.yahooapis.jp/search/local/V1/localSearch?${params}`,
      { headers: { 'User-Agent': 'YuMapBot/1.0' }, signal: AbortSignal.timeout(10000) }
    )
    if (!res.ok) return null
    const json = await res.json() as { Feature?: Array<{ Property?: { Url?: string } }> }
    for (const f of json.Feature ?? []) {
      const url = f.Property?.Url
      if (url?.startsWith('http')) return url
    }
  } catch { /* ignore */ }

  return null
}

// ── HERE Platform Discover Search ───────────────────────────────────────────

async function hereSearch(name: string, lat: number, lng: number): Promise<string | null> {
  if (!HERE_API_KEY) return null

  const params = new URLSearchParams({
    apiKey:  HERE_API_KEY,
    q:       normalizeName(name),
    at:      `${lat},${lng}`,
    limit:   '5',
    lang:    'ja',
    in:      `countryCode:JPN`,
  })

  try {
    const res = await fetch(
      `https://discover.search.hereapi.com/v1/discover?${params}`,
      {
        headers: { 'User-Agent': 'YuMapBot/1.0 (https://yumap.app/bot)' },
        signal: AbortSignal.timeout(10000),
      }
    )
    if (res.status === 401) throw new Error('HERE_KEY_INVALID')
    if (!res.ok) return null

    const json = await res.json() as {
      items?: Array<{
        title?: string
        contacts?: Array<{ www?: Array<{ value?: string }> }>
      }>
    }

    for (const item of json.items ?? []) {
      for (const contact of item.contacts ?? []) {
        for (const www of contact.www ?? []) {
          const url = www.value
          if (url?.startsWith('http')) return url
        }
      }
    }
  } catch (err: unknown) {
    if (err instanceof Error && err.message === 'HERE_KEY_INVALID') throw err
  }
  return null
}

// ── メイン ───────────────────────────────────────────────────────────────────

async function runEnricher() {
  const isTest = process.argv.includes('--test')
  const limit  = isTest
    ? parseInt(process.argv[process.argv.indexOf('--limit') + 1] ?? '20')
    : BATCH_SIZE
  const offset = process.argv.includes('--offset')
    ? parseInt(process.argv[process.argv.indexOf('--offset') + 1])
    : 0

  if (!YAHOO_APP_ID && !HERE_API_KEY) {
    console.error('❌ YAHOO_APP_ID または HERE_API_KEY を .env に設定してください')
    process.exit(1)
  }

  const sources = [YAHOO_APP_ID && 'Yahoo! YOLP (gc:0418)', HERE_API_KEY && 'HERE Platform']
    .filter(Boolean).join(' + ')
  console.log(`\n🔍 URL Enricher — ${sources}`)
  console.log(`   モード: ${isTest ? 'テスト' : '本番'} | バッチ: ${limit}件 | offset: ${offset}\n`)

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
    .range(offset, offset + limit - 1)

  if (error) { console.error('DB取得エラー:', error.message); process.exit(1) }
  if (!facilities?.length) { console.log('⭕ 対象施設なし（全件完了）'); return }

  const { count: total } = await supabase
    .from('crawl_schedule')
    .select('*', { count: 'exact', head: true })
    .is('official_site_url', null)

  console.log(`📋 対象: ${facilities.length}件 / 残${total}件\n`)

  let yahooHit = 0, hereHit = 0, notFound = 0, errors = 0

  for (let i = 0; i < facilities.length; i++) {
    const f = facilities[i]
    const lat = f.latitude as number
    const lng = f.longitude as number
    const progress = `[${offset + i + 1}/${offset + (total ?? 0)}]`

    try {
      let website: string | null = null
      let source = ''

      // 1. Yahoo! ローカルサーチ（業種コード指定）
      if (YAHOO_APP_ID) {
        website = await yahooSearch(f.name, lat, lng)
        if (website) { yahooHit++; source = 'Y' }
      }

      // 2. HERE Platform（Yahoo でヒットしなかった場合）
      if (!website && HERE_API_KEY) {
        website = await hereSearch(f.name, lat, lng)
        if (website) { hereHit++; source = 'H' }
        await sleep(HERE_DELAY)
      }

      if (website) {
        const { error: upErr } = await supabase
          .from('facilities')
          .update({ website })
          .eq('id', f.id)
        if (upErr) throw new Error(upErr.message)
        console.log(`  ✅ ${progress}[${source}] ${f.name.slice(0, 26).padEnd(26)} → ${website.slice(0, 50)}`)
      } else {
        if ((i + 1) % 50 === 0) process.stdout.write(`\n  ${progress} `)
        else process.stdout.write('.')
        notFound++
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      if (msg.includes('KEY_INVALID')) {
        console.error(`\n❌ APIキーエラー: ${msg}`)
        process.exit(1)
      }
      errors++
      process.stdout.write('x')
    }
  }

  const processed = yahooHit + hereHit + notFound + errors
  console.log(`\n\n📊 結果 (offset ${offset}〜${offset + processed - 1})`)
  console.log(`   Yahoo発見: ${yahooHit}件 / HERE発見: ${hereHit}件 / 未発見: ${notFound}件 / エラー: ${errors}件`)
  if (offset + processed < (total ?? 0)) {
    console.log(`\n▶  次のバッチ: npx tsx scout/url-enricher-multi.ts --offset ${offset + processed}`)
  } else {
    console.log(`\n✅ 全件処理完了`)
  }
  if (yahooHit + hereHit > 0) {
    console.log(`   Commander が新URLを自動検知してクロール開始します`)
  }
}

runEnricher()
  .catch(err => console.error('Fatal:', err instanceof Error ? err.message : err))
  .finally(() => process.exit(0))
