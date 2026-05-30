export function validatePrice(price: number | null): { ok: boolean; reason?: string } {
  if (price === null) return { ok: true }
  if (price < 0 || price > 5000) return { ok: false, reason: 'price_out_of_range' }
  return { ok: true }
}

export function validatePhone(phone: string | null): { ok: boolean; reason?: string } {
  if (phone === null) return { ok: true }
  if (!/^0\d{1,4}-\d{1,4}-\d{3,4}$/.test(phone)) return { ok: false, reason: 'phone_format_invalid' }
  return { ok: true }
}

export function validateHours(hours: string | null): { ok: boolean; reason?: string } {
  if (hours === null) return { ok: true }
  if (!/\d/.test(hours)) return { ok: false, reason: 'hours_no_digits' }
  return { ok: true }
}

export interface ValidationResult {
  ok: boolean
  issues: string[]
}

export function validateRawData(raw: {
  price_adult?: number | null
  phone?: string | null
  hours?: string | null
}): ValidationResult {
  const issues: string[] = []
  const p = validatePrice(raw.price_adult ?? null); if (!p.ok && p.reason) issues.push(p.reason)
  const ph = validatePhone(raw.phone ?? null); if (!ph.ok && ph.reason) issues.push(ph.reason)
  const h = validateHours(raw.hours ?? null); if (!h.ok && h.reason) issues.push(h.reason)
  return { ok: issues.length === 0, issues }
}
