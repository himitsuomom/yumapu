import 'dotenv/config'

export interface Prefecture {
  name: string
  bbox: [number, number, number, number]  // [south, west, north, east]
  center: { lat: number; lng: number }
  searchRadiusKm: number
}

export const PREFECTURES: Prefecture[] = [
  { name: '北海道', bbox: [41.35, 139.33, 45.55, 148.89], center: { lat: 43.5, lng: 142.5 }, searchRadiusKm: 250 },
  { name: '青森県', bbox: [40.20, 139.76, 41.56, 141.68], center: { lat: 40.82, lng: 140.74 }, searchRadiusKm: 80 },
  { name: '岩手県', bbox: [38.74, 140.66, 40.45, 141.84], center: { lat: 39.70, lng: 141.13 }, searchRadiusKm: 100 },
  { name: '宮城県', bbox: [37.77, 140.27, 38.97, 141.68], center: { lat: 38.27, lng: 140.87 }, searchRadiusKm: 70 },
  { name: '秋田県', bbox: [39.00, 139.72, 40.52, 141.07], center: { lat: 39.72, lng: 140.10 }, searchRadiusKm: 80 },
  { name: '山形県', bbox: [37.73, 139.53, 39.00, 140.72], center: { lat: 38.42, lng: 140.36 }, searchRadiusKm: 70 },
  { name: '福島県', bbox: [36.78, 139.09, 37.97, 141.02], center: { lat: 37.37, lng: 140.39 }, searchRadiusKm: 90 },
  { name: '茨城県', bbox: [35.73, 139.68, 36.80, 140.85], center: { lat: 36.34, lng: 140.45 }, searchRadiusKm: 70 },
  { name: '栃木県', bbox: [36.20, 139.32, 37.16, 140.29], center: { lat: 36.56, lng: 139.88 }, searchRadiusKm: 60 },
  { name: '群馬県', bbox: [36.12, 138.43, 37.01, 139.73], center: { lat: 36.39, lng: 139.06 }, searchRadiusKm: 70 },
  { name: '埼玉県', bbox: [35.74, 138.71, 36.29, 139.95], center: { lat: 35.86, lng: 139.65 }, searchRadiusKm: 60 },
  { name: '千葉県', bbox: [35.01, 139.73, 35.98, 140.87], center: { lat: 35.61, lng: 140.12 }, searchRadiusKm: 60 },
  { name: '東京都', bbox: [24.00, 136.07, 35.90, 139.91], center: { lat: 35.69, lng: 139.69 }, searchRadiusKm: 50 },
  { name: '神奈川県', bbox: [35.13, 138.94, 35.67, 139.78], center: { lat: 35.45, lng: 139.64 }, searchRadiusKm: 50 },
  { name: '新潟県', bbox: [36.77, 137.62, 38.57, 139.98], center: { lat: 37.90, lng: 138.95 }, searchRadiusKm: 100 },
  { name: '富山県', bbox: [36.30, 136.78, 36.97, 137.82], center: { lat: 36.70, lng: 137.21 }, searchRadiusKm: 60 },
  { name: '石川県', bbox: [36.15, 136.35, 37.54, 137.36], center: { lat: 36.59, lng: 136.63 }, searchRadiusKm: 70 },
  { name: '福井県', bbox: [35.44, 135.43, 36.30, 136.47], center: { lat: 35.85, lng: 136.22 }, searchRadiusKm: 60 },
  { name: '山梨県', bbox: [35.22, 138.36, 35.87, 138.98], center: { lat: 35.66, lng: 138.57 }, searchRadiusKm: 60 },
  { name: '長野県', bbox: [35.22, 137.35, 37.04, 138.70], center: { lat: 36.65, lng: 138.18 }, searchRadiusKm: 100 },
  { name: '岐阜県', bbox: [35.09, 136.23, 36.57, 137.72], center: { lat: 35.39, lng: 136.72 }, searchRadiusKm: 90 },
  { name: '静岡県', bbox: [34.56, 137.47, 35.67, 139.18], center: { lat: 34.98, lng: 138.38 }, searchRadiusKm: 80 },
  { name: '愛知県', bbox: [34.57, 136.67, 35.43, 137.90], center: { lat: 35.18, lng: 137.10 }, searchRadiusKm: 70 },
  { name: '三重県', bbox: [33.73, 135.78, 35.08, 136.97], center: { lat: 34.73, lng: 136.51 }, searchRadiusKm: 80 },
  { name: '滋賀県', bbox: [34.84, 135.74, 35.58, 136.56], center: { lat: 35.00, lng: 135.87 }, searchRadiusKm: 55 },
  { name: '京都府', bbox: [34.71, 135.04, 35.79, 135.89], center: { lat: 35.02, lng: 135.77 }, searchRadiusKm: 60 },
  { name: '大阪府', bbox: [34.27, 135.08, 34.97, 135.78], center: { lat: 34.69, lng: 135.50 }, searchRadiusKm: 50 },
  { name: '兵庫県', bbox: [34.22, 134.28, 35.67, 135.72], center: { lat: 34.69, lng: 134.69 }, searchRadiusKm: 80 },
  { name: '奈良県', bbox: [33.86, 135.56, 34.82, 136.22], center: { lat: 34.69, lng: 135.83 }, searchRadiusKm: 60 },
  { name: '和歌山県', bbox: [33.44, 135.19, 34.25, 136.00], center: { lat: 33.94, lng: 135.32 }, searchRadiusKm: 70 },
  { name: '鳥取県', bbox: [35.04, 133.14, 35.59, 134.50], center: { lat: 35.50, lng: 133.10 }, searchRadiusKm: 65 },
  { name: '島根県', bbox: [34.28, 131.67, 35.79, 133.33], center: { lat: 35.47, lng: 132.56 }, searchRadiusKm: 80 },
  { name: '岡山県', bbox: [34.47, 133.23, 35.33, 134.50], center: { lat: 34.66, lng: 133.94 }, searchRadiusKm: 70 },
  { name: '広島県', bbox: [34.05, 132.03, 35.18, 133.39], center: { lat: 34.40, lng: 132.46 }, searchRadiusKm: 75 },
  { name: '山口県', bbox: [33.73, 130.90, 34.68, 132.46], center: { lat: 34.19, lng: 131.47 }, searchRadiusKm: 75 },
  { name: '徳島県', bbox: [33.52, 133.64, 34.26, 134.87], center: { lat: 34.07, lng: 134.56 }, searchRadiusKm: 65 },
  { name: '香川県', bbox: [34.05, 133.43, 34.49, 134.38], center: { lat: 34.34, lng: 134.04 }, searchRadiusKm: 50 },
  { name: '愛媛県', bbox: [32.95, 132.06, 34.17, 133.70], center: { lat: 33.84, lng: 132.77 }, searchRadiusKm: 75 },
  { name: '高知県', bbox: [32.69, 132.54, 33.87, 134.27], center: { lat: 33.56, lng: 133.53 }, searchRadiusKm: 80 },
  { name: '福岡県', bbox: [33.06, 130.08, 33.89, 131.21], center: { lat: 33.60, lng: 130.42 }, searchRadiusKm: 65 },
  { name: '佐賀県', bbox: [33.10, 129.58, 33.55, 130.35], center: { lat: 33.25, lng: 130.30 }, searchRadiusKm: 50 },
  { name: '長崎県', bbox: [32.59, 128.37, 34.73, 130.46], center: { lat: 32.74, lng: 129.87 }, searchRadiusKm: 75 },
  { name: '熊本県', bbox: [32.06, 130.05, 33.18, 131.35], center: { lat: 32.79, lng: 130.74 }, searchRadiusKm: 70 },
  { name: '大分県', bbox: [32.75, 130.75, 33.78, 131.92], center: { lat: 33.24, lng: 131.61 }, searchRadiusKm: 65 },
  { name: '宮崎県', bbox: [31.35, 130.53, 32.75, 131.76], center: { lat: 31.91, lng: 131.42 }, searchRadiusKm: 75 },
  { name: '鹿児島県', bbox: [27.03, 128.26, 32.26, 131.00], center: { lat: 31.56, lng: 130.56 }, searchRadiusKm: 100 },
  { name: '沖縄県', bbox: [24.05, 122.93, 27.09, 131.33], center: { lat: 26.21, lng: 127.68 }, searchRadiusKm: 80 },
]
