/**
 * YuMap Scout Agent
 * OAuth動作（ANTHROPIC_API_KEY不要）・コストゼロ
 *
 * 実行: npx tsx scout/index.ts
 * テスト: npx tsx scout/index.ts --test --limit 3
 */

import 'dotenv/config'
import { chromium } from 'playwright'
import { createClient } from '@supabase/supabase-js'
import { createHash } from 'crypto'
import { isAllowed, contentHash } from './utils/robots.ts'
import { extractFromPage } from './extractors/official-site.ts'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

const BATCH_SIZE = parseInt(process.env.BATCH_SIZE ?? '10')
const REQUEST_DELAY = parseInt(process.env.REQUEST_DELAY ?? '3000')
const MAX_PAGES_PER_SITE = 5

// 訪問するサブページのパスパターン
const SUB_PAGE_PATTERNS = [
  '/price', '/ryoukin', '/ryokin', '/fee',
  '/access', '/info', '/detail', '/about',
  '/facility', '/setubi', '/facilities',
]

async function sleep(ms: number) {
  return new Promise(r => setTimeout(r, ms))
}

async function findSubPages(page: import('playwright').Page, baseUrl: string): Promise<string[]> {
  const links = await page.evaluate((patterns) => {
    return Array.from(document.querySelectorAll('a[href]'))
      .map(a => (a as HTMLAnchorElement).href)
      .filter(href => patterns.some(p => href.includes(p)))
  }, SUB_PAGE_PATTERNS)

  return [...new Set(links)].slice(0, MAX_PAGES_PER_SITE - 1)
}

function normalizeUrl(url: string): string {
  const trimmed = url.trim()
  if (/^https?:\/\//i.test(trimmed)) return trimmed
  return `https://${trimmed}`
}

async function scoutFacility(
  facilityId: string,
  rawUrl: string,
  browser: import('playwright').Browser
): Promise<{ success: boolean; data?: object; error?: string }> {
  const siteUrl = normalizeUrl(rawUrl)
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (compatible; YuMapBot/1.0; +https://yumap.app/bot)',
    extraHTTPHeaders: { 'Accept-Language': 'ja,en;q=0.9' },
  })
  const page = await context.newPage()

  try {
    // robots.txt チェック
    if (!(await isAllowed(siteUrl))) {
      console.log(`  ⚠️  robots.txt 禁止: ${siteUrl}`)
      await context.close()
      return { success: false, error: 'robots_disallowed' }
    }

    // トップページ取得
    await page.goto(siteUrl, { waitUntil: 'networkidle', timeout: 20000 })
    await sleep(REQUEST_DELAY)
    const topData = await extractFromPage(page, siteUrl)
    const topHash = contentHash(await page.content())

    // サブページ（料金・設備）も確認
    const subUrls = await findSubPages(page, siteUrl)
    for (const subUrl of subUrls.slice(0, 4)) {
      if (!(await isAllowed(subUrl))) continue
      try {
        await page.goto(subUrl, { waitUntil: 'networkidle', timeout: 15000 })
        await sleep(REQUEST_DELAY)
        const sub = await extractFromPage(page, subUrl)
        // サブページで追加情報が取れた場合はマージ
        if (!topData.price_adult && sub.price_adult) topData.price_adult = sub.price_adult
        if (!topData.hours     && sub.hours)         topData.hours = sub.hours
        if (!topData.holiday   && sub.holiday)       topData.holiday = sub.holiday
        if (!topData.phone     && sub.phone)         topData.phone = sub.phone
        if (sub.amenities.length > topData.amenities.length) topData.amenities = sub.amenities
        if (!topData.spring_type && sub.spring_type) topData.spring_type = sub.spring_type
        topData.photos.push(...sub.photos)
        topData.confidence = Math.min(1, topData.confidence + 0.1)
      } catch { /* サブページ失敗は無視 */ }
    }

    // 重複写真除去
    topData.photos = [...new Set(topData.photos)].slice(0, 10)
    // 信頼度再計算
    const filledFields = [topData.price_adult, topData.hours, topData.holiday, topData.phone]
      .filter(f => f !== null).length
    topData.confidence = filledFields / 4

    // Supabase staging に INSERT
    const { error: dbErr } = await supabase
      .from('raw_facility_data')
      .insert({
        facility_id:  facilityId,
        source:       'official_site',
        raw_json:     { ...topData, scraped_url: siteUrl },
        content_hash: topHash,
        status:       'pending',
      })

    if (dbErr) throw new Error(dbErr.message)

    // crawl_schedule を更新
    await supabase
      .from('crawl_schedule')
      .update({
        status:          'done',
        last_crawled_at: new Date().toISOString(),
        content_hash:    topHash,
        error_count:     0,
        last_error:      null,
      })
      .eq('facility_id', facilityId)

    console.log(`  ✅ ${facilityId.slice(0, 8)} — 信頼度:${Math.round(topData.confidence * 100)}% 料金:${topData.price_adult ?? 'null'} 時間:${topData.hours ?? 'null'}`)
    await context.close()
    return { success: true, data: topData }

  } catch (err: unknown) {
    const msg = (err instanceof Error ? err.message : String(err)).slice(0, 200)
    console.error(`  ❌ ${facilityId.slice(0, 8)} — ${msg}`)

    try {
      await supabase
        .from('crawl_schedule')
        .update({ status: 'error', last_error: msg })
        .eq('facility_id', facilityId)
    } catch { /* DB更新失敗は無視 */ }

    try { await context.close() } catch { /* コンテキストクローズ失敗は無視 */ }
    return { success: false, error: msg }
  }
}

async function runScoutBatch() {
  const isTest = process.argv.includes('--test')
  const limit  = isTest ? 3 : BATCH_SIZE

  console.log(`\n🔍 Scout Agent 起動 — ${isTest ? 'テストモード' : '本番モード'} (${limit}件/バッチ)\n`)

  // pending 施設を優先度順で取得
  const { data: schedule, error } = await supabase
    .from('crawl_schedule')
    .select('facility_id, official_site_url, priority')
    .eq('status', 'pending')
    .not('official_site_url', 'is', null)
    .order('priority', { ascending: true })
    .limit(limit)

  if (error) { console.error('DB取得エラー:', error.message); process.exit(1) }
  if (!schedule?.length) { console.log('⭕ 収集対象なし（全施設完了または URL 未設定）'); return }

  console.log(`📋 収集対象: ${schedule.length}件\n`)

  let browser = await chromium.launch({ headless: true })
  let success = 0, failed = 0

  for (const row of schedule) {
    if (!row.official_site_url) continue

    // ブラウザ死活チェック → 再起動
    if (!browser.isConnected()) {
      console.log('  🔄 ブラウザ再起動...')
      try { await browser.close() } catch { /* ignore */ }
      browser = await chromium.launch({ headless: true })
    }

    console.log(`\n→ ${row.official_site_url}`)

    // in_progress マーク
    await supabase
      .from('crawl_schedule')
      .update({ status: 'in_progress' })
      .eq('facility_id', row.facility_id)

    try {
      const result = await scoutFacility(row.facility_id, row.official_site_url, browser)
      result.success ? success++ : failed++
    } catch (err: unknown) {
      console.error(`  💥 ${row.facility_id.slice(0, 8)} — 予期しないエラー:`, err instanceof Error ? err.message.slice(0, 100) : String(err))
      failed++
    }
  }

  try { await browser.close() } catch { /* ignore */ }

  console.log(`\n📊 Scout バッチ完了: ✅${success}件 / ❌${failed}件`)
  return { success, failed, total: schedule.length }
}

runScoutBatch()
  .then(res => { if (res) console.log('\n✅ Scout Agent 終了') })
  .catch(err => { console.error('Scout 致命的エラー（処理は継続されました）:', err instanceof Error ? err.message : String(err)) })
  .finally(() => process.exit(0))
