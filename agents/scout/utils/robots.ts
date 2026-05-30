import { createHash } from 'crypto'

const robotsCache = new Map<string, { rules: string[]; ts: number }>()
const CACHE_TTL = 3600_000  // 1時間

export async function isAllowed(url: string): Promise<boolean> {
  try {
    const u = new URL(url)
    const origin = `${u.protocol}//${u.hostname}`
    const now = Date.now()

    let cached = robotsCache.get(origin)
    if (!cached || now - cached.ts > CACHE_TTL) {
      const res = await fetch(`${origin}/robots.txt`, {
        headers: { 'User-Agent': 'YuMapBot/1.0 (+https://yumap.app/bot)' },
        signal: AbortSignal.timeout(5000),
      })
      const text = res.ok ? await res.text() : ''
      const disallowedPaths: string[] = []
      let inYuMapBot = false
      let inStar = false
      for (const line of text.split('\n')) {
        const trimmed = line.trim().toLowerCase()
        if (trimmed.startsWith('user-agent:')) {
          const agent = trimmed.replace('user-agent:', '').trim()
          inYuMapBot = agent === 'yumapbot'
          inStar = agent === '*'
        }
        if ((inYuMapBot || inStar) && trimmed.startsWith('disallow:')) {
          const path = trimmed.replace('disallow:', '').trim()
          if (path) disallowedPaths.push(path)
        }
      }
      cached = { rules: disallowedPaths, ts: now }
      robotsCache.set(origin, cached)
    }

    const path = u.pathname
    return !cached.rules.some(rule => rule !== '/' && path.startsWith(rule))
  } catch {
    return true  // robots.txt 取得失敗は許可扱い
  }
}

export function contentHash(text: string): string {
  return createHash('sha256').update(text).digest('hex').slice(0, 16)
}
