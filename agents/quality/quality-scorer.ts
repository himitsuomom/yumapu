import { validateRawData } from './validators.ts'

export interface ScoreInput {
  price_adult: number | null
  hours: string | null
  holiday: string | null
  phone: string | null
  amenities: string[]
  photos: string[]
}

export function scoreQuality(d: ScoreInput): number {
  const fields = [d.price_adult, d.hours, d.holiday, d.phone]
  const fillRate = fields.filter(f => f !== null).length / fields.length

  let bonus = 0
  if (d.amenities.length >= 3) bonus += 0.05
  if (d.photos.length >= 1) bonus += 0.05

  const v = validateRawData({ price_adult: d.price_adult, hours: d.hours, phone: d.phone })
  const penalty = v.issues.length * 0.1

  return Math.max(0, Math.min(1, fillRate * 0.9 + bonus - penalty))
}
