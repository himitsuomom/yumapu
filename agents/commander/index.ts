/**
 * YuMap Commander — 情報収集エージェント部隊 司令官
 *
 * OAuth動作（ANTHROPIC_API_KEY不要）:
 *   claude -p "タスク" がClaudeCodeのOAuthサブスクリプションを使用
 *
 * 起動:
 *   npx tsx commander/index.ts
 *   npx tsx commander/index.ts --mode maintenance   # 1日1回モード
 *   npx tsx commander/index.ts --mode aggressive    # 全施設完了まで30分毎
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'
import { exec } from 'child_process'
import { promisify } from 'util'
import { chromium } from 'playwright'
import { isAllowed, contentHash } from '../scout/utils/robots.ts'
import { extractFromPage } from '../scout/extractors/official-site.ts'

const execAsync = promisify(exec)

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

type OperationMode = 'aggressive' | 'maintenance'

const MODE: OperationMode = (process.argv.find(a => a.startsWith('--mode='))?.split('=')[1]
  ?? process.argv[process.argv.indexOf('--mode') + 1]
  ?? process.env.OPERATION_MODE
  ?? 'aggressive') as OperationMode

const BATCH_SIZE = parseInt(process.env.BATCH_SIZE ?? '50')
const POLL_INTERVAL_MS = MODE === 'maintenance' ? 86_400_000 : 1_800_000  // 24h or 30min

async function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)) }

async function getProgress(): Promise<{ total: number; complete: number; pending: number }> {
  const { count: total }    = await supabase.from('crawl_schedule').select('*', { count: 'exact', head: true })
  const { count: complete } = await supabase.from('crawl_schedule').select('*', { count: 'exact', head: true }).eq('data_complete', true)
  const pending = (total ?? 0) - (complete ?? 0)
  return { total: total ?? 0, complete: complete ?? 0, pending }
}

async function getNextBatch(limit: number) {
  const { data } = await supabase
    .from('crawl_schedule')
    .select('facility_id, official_site_url, priority, facilities(name)')
    .eq('data_complete', false)
    .eq('status', 'pending')
    .not('official_site_url', 'is', null)
    .order('priority', { ascending: true })
    .limit(limit)
  return data ?? []
}

const REQUEST_DELAY = parseInt(process.env.REQUEST_DELAY ?? '3000')
const SUB_PAGE_PATTERNS = ['/price', '/ryoukin', '/ryokin', '/fee', '/access', '/info', '/detail', '/facility', '/setubi']

function normalizeUrl(url: string): string {
  const trimmed = url.trim()
  return /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`
}

async function scoutOne(
  facilityId: string,
  rawUrl: string,
  browser: import('playwright').Browser
): Promise<boolean> {
  const siteUrl = normalizeUrl(rawUrl)
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (compatible; YuMapBot/1.0; +https://yumap.app/bot)',
    extraHTTPHeaders: { 'Accept-Language': 'ja,en;q=0.9' },
  })
  const page = await context.newPage()

  try {
    if (!(await isAllowed(siteUrl))) {
      await context.close()
      return false
    }
    await page.goto(siteUrl, { waitUntil: 'networkidle', timeout: 20000 })
    await sleep(REQUEST_DELAY)

    const topData = await extractFromPage(page, siteUrl)
    const hash = contentHash(await page.content())

    // サブページ探索
    const subUrls = await page.evaluate((patterns) => {
      return Array.from(document.querySelectorAll('a[href]'))
        .map(a => { try { return (a as HTMLAnchorElement).href || '' } catch { return '' } })
        .filter((href): href is string => typeof href === 'string' && patterns.some(p => href.includes(p)))
        .slice(0, 4)
    }, SUB_PAGE_PATTERNS).catch(() => [] as string[])

    for (const subUrl of subUrls) {
      try {
        if (!(await isAllowed(subUrl))) continue
        await page.goto(subUrl, { waitUntil: 'networkidle', timeout: 15000 })
        await sleep(REQUEST_DELAY)
        const sub = await extractFromPage(page, subUrl)
        if (!topData.price_adult && sub.price_adult) topData.price_adult = sub.price_adult
        if (!topData.hours     && sub.hours)         topData.hours = sub.hours
        if (!topData.holiday   && sub.holiday)       topData.holiday = sub.holiday
        if (!topData.phone     && sub.phone)         topData.phone = sub.phone
        if (sub.amenities.length > topData.amenities.length) topData.amenities = sub.amenities
      } catch { /* サブページ失敗は無視 */ }
    }

    topData.photos = [...new Set(topData.photos)].slice(0, 10)
    const filledFields = [topData.price_adult, topData.hours, topData.holiday, topData.phone].filter(f => f !== null).length
    topData.confidence = filledFields / 4

    await supabase.from('raw_facility_data').insert({
      facility_id: facilityId, source: 'official_site',
      raw_json: { ...topData, scraped_url: siteUrl },
      content_hash: hash, status: 'pending',
    })
    await supabase.from('crawl_schedule')
      .update({ status: 'done', last_crawled_at: new Date().toISOString(), content_hash: hash, error_count: 0, last_error: null })
      .eq('facility_id', facilityId)

    console.log(`    ✅ ${facilityId.slice(0, 8)} — 信頼度:${Math.round(topData.confidence * 100)}% 料金:${topData.price_adult ?? 'null'}`)
    try { await context.close() } catch { /* ignore */ }
    return true

  } catch (err: unknown) {
    const msg = (err instanceof Error ? err.message : String(err)).slice(0, 200)
    console.log(`    ❌ ${facilityId.slice(0, 8)} — ${msg}`)
    try { await supabase.from('crawl_schedule').update({ status: 'error', last_error: msg }).eq('facility_id', facilityId) } catch { /* ignore */ }
    try { await context.close() } catch { /* ignore */ }
    return false
  }
}

async function runScoutBatch(batch: Array<{ facility_id: string; official_site_url: string }>) {
  console.log(`\n  🔍 Scout開始: ${batch.length}施設`)
  let browser = await chromium.launch({ headless: true })
  let success = 0, failed = 0

  for (const row of batch) {
    if (!row.official_site_url) continue
    if (!browser.isConnected()) {
      try { await browser.close() } catch { /* ignore */ }
      browser = await chromium.launch({ headless: true })
    }
    await supabase.from('crawl_schedule').update({ status: 'in_progress' }).eq('facility_id', row.facility_id)
    try {
      const ok = await scoutOne(row.facility_id, row.official_site_url, browser)
      ok ? success++ : failed++
    } catch (err: unknown) {
      console.log(`    💥 ${row.facility_id.slice(0, 8)} — 予期しないエラー`)
      failed++
    }
  }

  try { await browser.close() } catch { /* ignore */ }
  console.log(`\n  📊 Scout バッチ完了: ✅${success}件 / ❌${failed}件`)
  return true
}

async function runVerification() {
  console.log('\n  🔄 Verification Loop 実行')
  try {
    await execAsync(
      'cd /Users/yangdaniel/Projects/yumap/app/agents && npx tsx analysis/verification-loop.ts',
      { timeout: 120_000, env: { ...process.env } }
    )
    return true
  } catch (err: unknown) {
    console.error('  Verification エラー:', err instanceof Error ? err.message.slice(0, 200) : String(err))
    return false
  }
}

async function notifyCompletion(progress: { total: number; complete: number }) {
  console.log('\n🎉 全施設収集完了!')
  console.log(`   総施設数: ${progress.total} / 完了: ${progress.complete}`)
  console.log('   --mode maintenance で1日1回モードに切り替えてください')

  // Supabase に完了ログを記録
  await supabase.from('agent_queue').insert({
    task_type: 'batch_crawl',
    status:    'done',
    result:    { event: 'all_complete', ...progress, timestamp: new Date().toISOString() },
    payload:   { mode: 'aggressive', message: '全施設収集完了。maintenanceモードへ切り替え推奨' },
  })
}

async function logToWiki(cycleNum: number, progress: { total: number; complete: number; pending: number }, success: boolean) {
  // llm-wiki への記録は Claude Code プロセス経由で呼ぶ（OAuth使用）
  const msg = `YuMap収集サイクル${cycleNum}: ${progress.complete}/${progress.total}施設完了 (${success?'✅':'❌'})`
  console.log(`  📝 ${msg}`)
}

async function commanderLoop() {
  console.log(`\n🎖️  YuMap Commander 起動`)
  console.log(`   モード: ${MODE} | バッチ: ${BATCH_SIZE}件 | 間隔: ${MODE==='aggressive'?'30分':'24時間'}`)
  console.log(`   認証: OAuth (Claude Code サブスクリプション)`)
  console.log(`   ────────────────────────────────────────\n`)

  let cycleNum = 0

  while (true) {
    cycleNum++
    const progress = await getProgress()

    console.log(`\n[Cycle ${cycleNum}] ${new Date().toLocaleString('ja-JP')}`)
    console.log(`  進捗: ${progress.complete}/${progress.total} (残${progress.pending}件)`)

    // 全完了チェック
    if (progress.pending === 0) {
      await notifyCompletion(progress)
      if (MODE === 'aggressive') {
        console.log('\n⏸️  aggressive モード終了。maintenanceモードで再起動してください。')
        process.exit(0)
      }
      await sleep(POLL_INTERVAL_MS)
      continue
    }

    // キュー確認（pg_cronが積んだタスク）
    const { data: queueTask } = await supabase
      .from('agent_queue')
      .select('id')
      .eq('status', 'pending')
      .eq('task_type', 'batch_crawl')
      .order('created_at', { ascending: true })
      .limit(1)
      .single()

    // aggressive モードはキューに関係なく30分毎に実行
    const shouldRun = MODE === 'aggressive' || !!queueTask

    if (shouldRun) {
      if (queueTask) {
        await supabase.from('agent_queue').update({ status: 'processing' }).eq('id', queueTask.id)
      }

      // バッチ取得
      const batch = await getNextBatch(BATCH_SIZE)
      if (batch.length === 0) {
        console.log('  バッチなし（URL未設定施設のみ残存）')
      } else {
        // Scout 実行
        const scoutOk = await runScoutBatch(batch as Array<{ facility_id: string; official_site_url: string }>)

        // Verification 実行
        if (scoutOk) await runVerification()

        await logToWiki(cycleNum, progress, scoutOk)

        if (queueTask) {
          await supabase.from('agent_queue')
            .update({ status: 'done', processed_at: new Date().toISOString() })
            .eq('id', queueTask.id)
        }
      }
    } else {
      console.log(`  待機中... (次回チェック: ${new Date(Date.now() + 30_000).toLocaleTimeString('ja-JP')})`)
    }

    await sleep(MODE === 'aggressive' ? POLL_INTERVAL_MS : 30_000)
  }
}

commanderLoop().catch(err => {
  console.error('Commander Fatal Error:', err)
  process.exit(1)
})
