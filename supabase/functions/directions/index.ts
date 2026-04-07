// supabase/functions/directions/index.ts
//
// Google Directions API のプロキシ Edge Function。
// クライアント側でAPIキーを直接扱わないためにここで中継します。
//
// 環境変数（Supabase Dashboard > Settings > Secrets で設定）:
//   GOOGLE_DIRECTIONS_API_KEY — Directions API 専用キー
//
// 呼び出し例（クライアント側）:
//   POST https://<project>.supabase.co/functions/v1/directions
//   Authorization: Bearer <SUPABASE_ANON_KEY>
//   Content-Type: application/json
//   Body: { "originLat": 35.68, "originLng": 139.77,
//            "destLat": 35.71, "destLng": 139.80 }
//
// レスポンスはGoogle Directions APIのレスポンスをそのまま返します。

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const DIRECTIONS_API_URL =
  'https://maps.googleapis.com/maps/api/directions/json'

serve(async (req: Request) => {
  // CORS プリフライトに対応（開発中のフラッターWebデバッグ用）
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers':
          'Authorization, Content-Type, apikey',
      },
    })
  }

  // POST のみ受け付ける
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // リクエストボディのパース
  let body: {
    originLat: number
    originLng: number
    destLat: number
    destLng: number
    mode?: string
  }

  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { originLat, originLng, destLat, destLng, mode = 'driving' } = body

  if (
    typeof originLat !== 'number' ||
    typeof originLng !== 'number' ||
    typeof destLat !== 'number' ||
    typeof destLng !== 'number'
  ) {
    return new Response(
      JSON.stringify({
        error: 'originLat, originLng, destLat, destLng は数値で渡してください',
      }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // Supabase Secrets から APIキーを取得
  // （Deno.env.get はサーバー側でのみ実行されるため安全）
  const apiKey = Deno.env.get('GOOGLE_DIRECTIONS_API_KEY') ?? ''
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: 'API key is not configured on the server' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // Google Directions API へのリクエストを組み立てる
  const params = new URLSearchParams({
    origin: `${originLat},${originLng}`,
    destination: `${destLat},${destLng}`,
    mode,
    language: 'ja',
    key: apiKey,
  })

  const googleUrl = `${DIRECTIONS_API_URL}?${params.toString()}`

  try {
    const googleResponse = await fetch(googleUrl)
    const data = await googleResponse.json()

    return new Response(JSON.stringify(data), {
      status: googleResponse.status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Google API fetch failed: ${err}` }),
      { status: 502, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
