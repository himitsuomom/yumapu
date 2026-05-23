import type { Page } from 'playwright'

export interface ExtractedData {
  price_adult:  number | null
  price_child:  number | null
  hours:        string | null
  holiday:      string | null
  phone:        string | null
  amenities:    string[]
  spring_type:  string | null
  photos:       string[]
  confidence:   number
}

// 料金パターン（大人・一般・入浴料）
const PRICE_PATTERNS = [
  /(?:大人|一般|おとな)[^\d]*(\d{3,4})\s*円/,
  /入浴料[^\d]*(\d{3,4})\s*円/,
  /大人.*?(\d{3,4})\s*円/,
  /(\d{3,4})\s*円.*(?:大人|一般)/,
]

// 営業時間パターン
const HOURS_PATTERNS = [
  /(\d{1,2}[:：]\d{2})\s*[〜～~\-–]\s*(\d{1,2}[:：]\d{2})/,
  /営業時間[^0-9]*(\d{1,2}[:：]\d{2})[^0-9]*[〜～~\-–][^0-9]*(\d{1,2}[:：]\d{2})/,
  /(\d{1,2})時\s*[〜～~\-–]\s*(\d{1,2})時/,
]

// 定休日パターン
const HOLIDAY_PATTERNS = [
  /定休日[：:]\s*([^\n。]+)/,
  /休館日[：:]\s*([^\n。]+)/,
  /休業日[：:]\s*([^\n。]+)/,
  /(?:毎週|毎月)[^\n]{0,20}(?:月|火|水|木|金|土|日)曜[^\n]{0,10}/,
]

// 電話番号パターン
const PHONE_PATTERN = /(?:電話|TEL|tel)[^\d]*(\d{2,4}[-\-]\d{2,4}[-\-]\d{4})/

// 泉質キーワード
const SPRING_TYPES = [
  '単純温泉', '塩化物泉', '炭酸水素塩泉', '硫酸塩泉',
  '二酸化炭素泉', '含鉄泉', '硫黄泉', '酸性泉', '放射能泉',
  'ナトリウム', 'カルシウム', 'アルカリ性'
]

// 設備キーワード → amenity コードマッピング
const AMENITY_MAP: Record<string, string> = {
  '露天': 'outdoor_bath', '露天風呂': 'outdoor_bath',
  'サウナ': 'sauna', '水風呂': 'cold_bath',
  '貸切': 'private_bath', '家族風呂': 'private_bath',
  '駐車場': 'parking', '食事': 'restaurant', 'レストラン': 'restaurant',
  'ジャグジー': 'jacuzzi', 'ジェット': 'jacuzzi',
  '岩盤浴': 'rock_sauna', 'スチーム': 'steam_sauna',
  'タオル': 'towel_rental', 'シャンプー': 'shampoo_provided',
}

function extractPrice(text: string): number | null {
  for (const pattern of PRICE_PATTERNS) {
    const m = text.match(pattern)
    if (m) {
      const price = parseInt(m[1])
      if (price >= 100 && price <= 15000) return price
    }
  }
  return null
}

function extractHours(text: string): string | null {
  for (const pattern of HOURS_PATTERNS) {
    const m = text.match(pattern)
    if (m) return `${m[1]}–${m[2]}`
  }
  return null
}

function extractHoliday(text: string): string | null {
  for (const pattern of HOLIDAY_PATTERNS) {
    const m = text.match(pattern)
    if (m) return m[0].slice(0, 50).trim()
  }
  return null
}

function extractPhone(text: string): string | null {
  const m = text.match(PHONE_PATTERN)
  return m ? m[1] : null
}

function extractAmenities(text: string): string[] {
  const found = new Set<string>()
  for (const [keyword, code] of Object.entries(AMENITY_MAP)) {
    if (text.includes(keyword)) found.add(code)
  }
  return [...found]
}

function extractSpringType(text: string): string | null {
  for (const st of SPRING_TYPES) {
    if (text.includes(st)) return st
  }
  return null
}

export async function extractFromPage(page: Page, baseUrl: string): Promise<ExtractedData> {
  const text = await page.evaluate(() => document.body?.innerText ?? '')
  const html = await page.content()

  // 写真 URL 収集（200px 以上の画像）
  const photos = await page.evaluate((base) => {
    return Array.from(document.querySelectorAll('img'))
      .filter(img => (img.naturalWidth || img.width) >= 200)
      .map(img => {
        const src = img.src || img.dataset.src || ''
        try { return new URL(src, base).href } catch { return '' }
      })
      .filter(u => u && !u.includes('logo') && !u.includes('icon'))
      .slice(0, 10)
  }, baseUrl)

  const price_adult = extractPrice(text)
  const hours       = extractHours(text)
  const holiday     = extractHoliday(text)
  const phone       = extractPhone(text)
  const amenities   = extractAmenities(text)
  const spring_type = extractSpringType(text)

  // 信頼度：取得できたフィールド数 / 全フィールド数
  const fields = [price_adult, hours, holiday, phone]
  const confidence = fields.filter(f => f !== null).length / fields.length

  return {
    price_adult, price_child: null, hours, holiday,
    phone, amenities, spring_type, photos,
    confidence: Math.round(confidence * 100) / 100,
  }
}
