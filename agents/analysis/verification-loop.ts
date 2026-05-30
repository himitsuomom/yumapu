/**
 * Verification Loop — 多ソース矛盾検出・信頼スコアマージ
 * OAuth動作・コストゼロ（外部API呼び出しなし）
 */

import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

// 信頼スコア（DB の source_trust_scores と同期）
const TRUST: Record<string, Record<string, number>> = {
  official_site: { price: 0.95, hours: 0.90, phone: 0.99, holiday: 0.88, amenities: 0.75 },
  jalan:         { price: 0.80, hours: 0.82, phone: 0.70, holiday: 0.75, amenities: 0.70 },
  nifty:         { price: 0.72, hours: 0.75, phone: 0.65, holiday: 0.70, amenities: 0.68 },
  pdf_analysis:  { price: 0.20, hours: 0.15, amenities: 0.90, spring_type: 0.99 },
  osm:           { price: 0.50, hours: 0.70, phone: 0.60, holiday: 0.40, amenities: 0.65 },
  user_report:   { price: 0.70, hours: 0.75, phone: 0.65, holiday: 0.70 },
}

type NumericField = 'price_adult' | 'price_child'
type TextFields   = 'hours' | 'holiday' | 'phone' | 'spring_type'
type ArrayField   = 'amenities'

interface ConflictInfo {
  field:     string
  values:    Array<{ source: string; value: unknown }>
  deviation: number   // 0〜1
  severity:  'low' | 'medium' | 'high'
}

interface MergedData {
  price_adult:  number | null
  price_child:  number | null
  hours:        string | null
  holiday:      string | null
  phone:        string | null
  amenities:    string[]
  spring_type:  string | null
  photos:       string[]
}

function getDeviation(values: number[]): number {
  if (values.length < 2) return 0
  const min = Math.min(...values)
  const max = Math.max(...values)
  return max === 0 ? 0 : (max - min) / max
}

function getSeverity(deviation: number): 'low' | 'medium' | 'high' {
  if (deviation >= 0.4) return 'high'   // 40%以上乖離 = 要確認
  if (deviation >= 0.15) return 'medium'
  return 'low'
}

function pickByTrust<T>(
  candidates: Array<{ source: string; value: T }>,
  field: string
): T | null {
  if (!candidates.length) return null
  return candidates.sort((a, b) =>
    (TRUST[b.source]?.[field] ?? 0) - (TRUST[a.source]?.[field] ?? 0)
  )[0].value
}

export async function verifyFacility(facilityId: string): Promise<{
  merged: MergedData
  conflicts: ConflictInfo[]
  needsReview: boolean
  qualityScore: number
}> {
  // 全ソースのステージングデータ取得
  const { data: rows } = await supabase
    .from('raw_facility_data')
    .select('source, raw_json')
    .eq('facility_id', facilityId)
    .eq('status', 'pending')

  if (!rows?.length) {
    return { merged: emptyMerged(), conflicts: [], needsReview: false, qualityScore: 1 }
  }

  const conflicts: ConflictInfo[] = []

  // ── 価格の矛盾チェック ──────────────────────────────
  const priceCandidates = rows
    .map(r => ({ source: r.source, value: r.raw_json.price_adult as number | null }))
    .filter(c => c.value !== null && c.value > 0) as Array<{ source: string; value: number }>

  let price_adult: number | null = null
  if (priceCandidates.length >= 2) {
    const deviation = getDeviation(priceCandidates.map(c => c.value))
    if (deviation > 0) {
      conflicts.push({
        field: 'price_adult',
        values: priceCandidates,
        deviation,
        severity: getSeverity(deviation),
      })
    }
  }
  price_adult = pickByTrust(priceCandidates, 'price') ?? null

  // ── 営業時間 ──────────────────────────────────────
  const hoursCandidates = rows
    .map(r => ({ source: r.source, value: r.raw_json.hours as string | null }))
    .filter(c => c.value)

  const hoursSet = new Set(hoursCandidates.map(c => c.value))
  if (hoursSet.size > 1) {
    conflicts.push({
      field: 'hours',
      values: hoursCandidates,
      deviation: 0.3,
      severity: 'medium',
    })
  }
  const hours = pickByTrust(hoursCandidates as Array<{ source: string; value: string }>, 'hours') ?? null

  // ── 定休日 ────────────────────────────────────────
  const holidayCandidates = rows
    .map(r => ({ source: r.source, value: r.raw_json.holiday as string | null }))
    .filter(c => c.value)
  const holiday = pickByTrust(holidayCandidates as Array<{ source: string; value: string }>, 'holiday') ?? null

  // ── 電話 ──────────────────────────────────────────
  const phoneCandidates = rows
    .map(r => ({ source: r.source, value: r.raw_json.phone as string | null }))
    .filter(c => c.value)
  const phone = pickByTrust(phoneCandidates as Array<{ source: string; value: string }>, 'phone') ?? null

  // ── アメニティ（全ソースをマージ）────────────────
  const allAmenities = new Set<string>()
  for (const r of rows) {
    for (const a of (r.raw_json.amenities ?? []) as string[]) allAmenities.add(a)
  }

  // ── 泉質（pdf_analysis 優先）─────────────────────
  const springCandidates = rows
    .map(r => ({ source: r.source, value: r.raw_json.spring_type as string | null }))
    .filter(c => c.value)
  const spring_type = pickByTrust(springCandidates as Array<{ source: string; value: string }>, 'spring_type') ?? null

  // ── 写真URL集約 ───────────────────────────────────
  const allPhotos = new Set<string>()
  for (const r of rows) {
    for (const p of (r.raw_json.photos ?? []) as string[]) allPhotos.add(p)
  }

  const merged: MergedData = {
    price_adult,
    price_child: null,
    hours,
    holiday,
    phone,
    amenities: [...allAmenities],
    spring_type,
    photos: [...allPhotos].slice(0, 10),
  }

  // 高リスク矛盾があれば人間確認フラグ
  const needsReview = conflicts.some(c => c.severity === 'high')

  // 品質スコア（1-5）
  const filledCount = [merged.price_adult, merged.hours, merged.holiday, merged.phone, merged.spring_type]
    .filter(f => f !== null).length
  const qualityScore = Math.max(1, Math.min(5, 1 + filledCount))

  return { merged, conflicts, needsReview, qualityScore }
}

function emptyMerged(): MergedData {
  return { price_adult: null, price_child: null, hours: null, holiday: null, phone: null, amenities: [], spring_type: null, photos: [] }
}

export async function mergeAllPending(): Promise<{ processed: number; flagged: number }> {
  // pending の施設ID一覧を取得
  const { data: pending } = await supabase
    .from('raw_facility_data')
    .select('facility_id')
    .eq('status', 'pending')

  const facilityIds = [...new Set(pending?.map(r => r.facility_id) ?? [])]
  console.log(`\n🔄 Verification Loop — ${facilityIds.length}施設を処理`)

  let processed = 0, flagged = 0

  for (const fid of facilityIds) {
    const { merged, conflicts, needsReview, qualityScore } = await verifyFacility(fid)

    // facilities テーブルを更新
    await supabase
      .from('facilities')
      .update({
        price:             merged.price_adult,
        hours:             merged.hours,
        holiday:           merged.holiday,
        spring_type:       merged.spring_type,
        data_quality_score: qualityScore,
        last_data_refresh: new Date().toISOString(),
      })
      .eq('id', fid)

    // raw_facility_data を merged に更新
    await supabase
      .from('raw_facility_data')
      .update({ status: needsReview ? 'flagged' : 'merged' })
      .eq('facility_id', fid)
      .eq('status', 'pending')

    // crawl_schedule にフラグ反映
    await supabase
      .from('crawl_schedule')
      .update({
        data_complete:       !needsReview && qualityScore >= 3,
        human_review_needed: needsReview,
        verified_at:         new Date().toISOString(),
        status:              needsReview ? 'done' : 'done',
      })
      .eq('facility_id', fid)

    processed++
    if (needsReview) {
      flagged++
      console.log(`  ⚠️  ${fid.slice(0, 8)} — 要確認 矛盾:${conflicts.map(c => c.field).join(',')}`)
    } else {
      console.log(`  ✅ ${fid.slice(0, 8)} — 品質スコア:${qualityScore} 料金:${merged.price_adult ?? 'null'}`)
    }
  }

  console.log(`\n📊 Verification 完了: 処理${processed}件 / 要確認${flagged}件`)
  return { processed, flagged }
}

// CLI 直接実行
if (process.argv[1]?.includes('verification-loop')) {
  mergeAllPending()
    .then(() => process.exit(0))
    .catch(err => { console.error(err); process.exit(1) })
}
