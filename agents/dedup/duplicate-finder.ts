import 'dotenv/config'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!)

export async function findDuplicatesForAll(limit = 1000): Promise<void> {
  const { data: facilities } = await supabase
    .from('facilities')
    .select('id, name, latitude, longitude')
    .is('merged_into', null)
    .not('latitude', 'is', null)
    .limit(limit)

  const seen = new Set<string>()
  let groups = 0
  for (const f of facilities ?? []) {
    if (seen.has(f.id)) continue
    const { data: dups } = await supabase.rpc('find_duplicate_facilities', {
      p_name: f.name, p_lat: f.latitude, p_lng: f.longitude, p_exclude_id: f.id,
    })
    if (dups?.length) {
      groups++
      console.log(`\n🔁 候補グループ #${groups}: ${f.name} (${f.id.slice(0, 8)})`)
      for (const d of dups as Array<{ facility_id: string; name: string; distance_m: number; name_similarity: number }>) {
        console.log(`   ↔ ${d.name} (${d.facility_id.slice(0, 8)}) dist=${Math.round(d.distance_m)}m sim=${d.name_similarity.toFixed(2)}`)
        seen.add(d.facility_id)
      }
      seen.add(f.id)
    }
  }
  console.log(`\n📊 重複候補: ${groups}グループ検出`)
}

export async function mergePair(sourceId: string, targetId: string): Promise<void> {
  const { error } = await supabase.rpc('merge_facility', { p_source_id: sourceId, p_target_id: targetId })
  if (error) throw error
  console.log(`✅ ${sourceId.slice(0, 8)} → ${targetId.slice(0, 8)} に統合`)
}

if (process.argv[1]?.includes('duplicate-finder')) {
  const mergeIdx = process.argv.indexOf('--merge')
  if (mergeIdx >= 0) {
    const [src, tgt] = [process.argv[mergeIdx + 1], process.argv[mergeIdx + 2]]
    mergePair(src, tgt).then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1) })
  } else {
    findDuplicatesForAll().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1) })
  }
}
