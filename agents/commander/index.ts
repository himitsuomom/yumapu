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
import { execSync, exec } from 'child_process'
import { promisify } from 'util'
import { writeFileSync } from 'fs'

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

async function runScoutBatch(batch: Array<{ facility_id: string; official_site_url: string }>) {
  console.log(`\n  🔍 Scout開始: ${batch.length}施設`)

  // 施設IDリストをJSONファイルに書き出してScoutに渡す
  const batchFile = '/tmp/yumap-scout-batch.json'
  writeFileSync(batchFile, JSON.stringify(batch))

  // Scout Agent を同期実行（Node.js プロセスとして直接呼ぶ）
  try {
    const { stdout, stderr } = await execAsync(
      `cd /Users/yangdaniel/Projects/yumap/app/agents && npx tsx scout/index.ts --batch-file ${batchFile}`,
      { timeout: 300_000, env: { ...process.env } }
    )
    if (stdout) console.log(stdout.slice(0, 500))
    if (stderr && !stderr.includes('ExperimentalWarning')) console.warn(stderr.slice(0, 200))
    return true
  } catch (err: unknown) {
    console.error('  Scout エラー:', err instanceof Error ? err.message.slice(0, 200) : String(err))
    return false
  }
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
