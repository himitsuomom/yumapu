/**
 * Photo Pipeline — 写真URL収集・分類・ライセンス管理
 * OAuth動作・コストゼロ（分類はルールベース）
 */

import 'dotenv/config'
import { chromium } from 'playwright'
import { createClient } from '@supabase/supabase-js'
import { isAllowed } from '../scout/utils/robots.ts'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
)

// 写真タイプ分類キーワード（alt/title/src/URL に含まれるキーワードで判定）
const TYPE_KEYWORDS: Record<string, string[]> = {
  outdoor_bath: ['露天', 'outdoor', 'rotenburo', 'roten', 'テラス', 'garden'],
  sauna:        ['サウナ', 'sauna', 'steam', 'スチーム'],
  bath:         ['大浴場', 'bath', 'baths', '浴場', 'onsen', '内風呂', 'indoor'],
  exterior:     ['外観', 'exterior', 'outside', 'building', '建物', 'entrance', '入口'],
  interior:     ['内装', 'lobby', 'ロビー', 'interior', 'lounge', '休憩'],
  food:         ['料理', 'food', 'meal', 'restaurant', '食事', 'dining'],
}

type PhotoType = 'exterior' | 'interior' | 'bath' | 'outdoor_bath' | 'sauna' | 'food' | 'other'

interface PhotoResult {
  url:         string
  source:      string
  photo_type:  PhotoType
  license:     string
  attribution: string | null
  is_primary:  boolean
  width:       number
  height:      number
}

function classifyPhoto(url: string, alt: string, title: string): PhotoType {
  const combined = [url, alt, title].join(' ').toLowerCase()
  for (const [type, keywords] of Object.entries(TYPE_KEYWORDS)) {
    if (keywords.some(kw => combined.includes(kw.toLowerCase()))) {
      return type as PhotoType
    }
  }
  return 'other'
}

function detectLicense(html: string, imgUrl: string): { license: string; attribution: string | null } {
  // Creative Commons ライセンス検出
  if (html.includes('cc-by') || html.includes('CC BY') || html.includes('クリエイティブ・コモンズ')) {
    const matchName = html.match(/©\s*([^\n<]{1,50})/)
    return { license: 'cc_by', attribution: matchName?.[1]?.trim() ?? null }
  }
  if (html.includes('CC0') || html.includes('パブリックドメイン')) {
    return { license: 'cc0', attribution: null }
  }
  // 施設公式サイトの場合は facility_owned
  if (imgUrl.includes(new URL(imgUrl).hostname)) {
    return { license: 'facility_owned', attribution: null }
  }
  return { license: 'unknown', attribution: null }
}

export async function collectPhotos(
  facilityId: string,
  officialSiteUrl: string
): Promise<PhotoResult[]> {
  if (!(await isAllowed(officialSiteUrl))) {
    console.log(`  ⚠️  写真収集 robots.txt 禁止: ${officialSiteUrl}`)
    return []
  }

  const browser = await chromium.launch({ headless: true })
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (compatible; YuMapBot/1.0; +https://yumap.app/bot)',
  })
  const page = await context.newPage()

  const results: PhotoResult[] = []

  try {
    await page.goto(officialSiteUrl, { waitUntil: 'networkidle', timeout: 20000 })
    const html = await page.content()

    const photos = await page.evaluate((base) => {
      return Array.from(document.querySelectorAll('img'))
        .map(img => ({
          src:    img.src || (img as HTMLImageElement).currentSrc || '',
          alt:    img.alt ?? '',
          title:  img.title ?? '',
          width:  img.naturalWidth || img.width || 0,
          height: img.naturalHeight || img.height || 0,
        }))
        .filter(img => img.src && img.width >= 200 && img.height >= 150)
        .map(img => ({
          ...img,
          src: (() => { try { return new URL(img.src, base).href } catch { return '' } })()
        }))
        .filter(img => img.src && !img.src.includes('logo') && !img.src.includes('icon') && !img.src.includes('banner'))
        .slice(0, 12)
    }, officialSiteUrl)

    let isPrimary = true
    for (const photo of photos) {
      if (!photo.src) continue

      // 人物写真の除外（alt に「人」「スタッフ」「お客様」が含まれる場合）
      if (['人物', 'スタッフ', 'お客様', 'customer', 'staff', 'people'].some(k =>
        photo.alt.includes(k) || photo.title.includes(k))) continue

      const photoType = classifyPhoto(photo.src, photo.alt, photo.title)
      const { license, attribution } = detectLicense(html, photo.src)

      results.push({
        url:        photo.src,
        source:     'official_site',
        photo_type: photoType,
        license,
        attribution,
        is_primary: isPrimary,
        width:      photo.width,
        height:     photo.height,
      })
      isPrimary = false
    }

    // Supabase に保存
    if (results.length > 0) {
      const { error } = await supabase
        .from('facility_photos')
        .upsert(
          results.map(r => ({ facility_id: facilityId, ...r })),
          { onConflict: 'facility_id,photo_url' }
        )
      if (error) console.warn(`  写真保存エラー: ${error.message}`)
    }

    console.log(`  📸 ${facilityId.slice(0, 8)} — ${results.length}枚収集 (タイプ: ${[...new Set(results.map(r => r.photo_type))].join(',')})`)

  } catch (err: unknown) {
    console.error(`  ❌ 写真収集エラー: ${err instanceof Error ? err.message : String(err)}`)
  } finally {
    await context.close()
    await browser.close()
  }

  return results
}

export async function runPhotoCollection(limit = 10) {
  const { data: schedule } = await supabase
    .from('crawl_schedule')
    .select('facility_id, official_site_url')
    .eq('data_complete', true)  // Scout完了済み施設のみ
    .is('official_site_url', 'not.null')
    .limit(limit)

  if (!schedule?.length) {
    console.log('写真収集対象なし')
    return
  }

  console.log(`\n📸 Photo Pipeline — ${schedule.length}施設\n`)
  for (const row of schedule) {
    if (!row.official_site_url) continue
    await collectPhotos(row.facility_id, row.official_site_url)
    await new Promise(r => setTimeout(r, 3000))  // 3秒待機
  }
}
