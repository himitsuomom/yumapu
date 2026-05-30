/**
 * Promoter — facility_candidates の pending 候補を facilities へ昇格する。
 * pendingが0になるまでループ（最大10回）。
 *
 * 実行: npx tsx scout/national/promoter.ts
 *       npx tsx scout/national/promoter.ts --prefecture 東京都
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

interface BatchResult {
  total: number
  promoted: number
  duplicate: number
  rejected: number
}

export async function promoteAll(prefecture?: string): Promise<BatchResult> {
  let grandTotal = 0, grandPromoted = 0, grandDuplicate = 0, grandRejected = 0
  const MAX_ROUNDS = 10

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    const { data, error } = await supabase.rpc('promote_candidates_batch', {
      p_prefecture: prefecture ?? null,
      p_limit: 500,
    })

    if (error) {
      console.error(`  [Promoter] RPC エラー (round ${round}): ${error.message}`)
      break
    }

    const result = (data as BatchResult[])[0] ?? { total: 0, promoted: 0, duplicate: 0, rejected: 0 }

    grandTotal    += result.total
    grandPromoted += result.promoted
    grandDuplicate += result.duplicate
    grandRejected  += result.rejected

    console.log(`  [Promoter] round ${round}: total=${result.total} promoted=${result.promoted} dup=${result.duplicate} rejected=${result.rejected}`)

    if (result.total === 0) break  // pending なし
  }

  return { total: grandTotal, promoted: grandPromoted, duplicate: grandDuplicate, rejected: grandRejected }
}

// スタンドアロン実行
if (process.argv[1]?.includes('promoter')) {
  const prefName = process.argv.includes('--prefecture')
    ? process.argv[process.argv.indexOf('--prefecture') + 1]
    : undefined

  console.log(`\n🚀 Promoter 起動${prefName ? ` (${prefName})` : ' (全都道府県)'}`)
  const result = await promoteAll(prefName)
  console.log(`\n📊 昇格完了: total=${result.total} promoted=${result.promoted} duplicate=${result.duplicate} rejected=${result.rejected}`)
  process.exit(0)
}
