// supabase/functions/directions/index.ts
//
// Google Directions API プロキシ。認証済みユーザーのみ使用可能。
//
// 環境変数: GOOGLE_DIRECTIONS_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const DIRECTIONS_API_URL = 'https://maps.googleapis.com/maps/api/directions/json'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // JWT 認証チェック
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )
  const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

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
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
      JSON.stringify({ error: 'originLat, originLng, destLat, destLng must be numbers' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const apiKey = Deno.env.get('GOOGLE_DIRECTIONS_API_KEY') ?? ''
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: 'API key is not configured on the server' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const params = new URLSearchParams({
    origin: `${originLat},${originLng}`,
    destination: `${destLat},${destLng}`,
    mode,
    language: 'ja',
    key: apiKey,
  })

  try {
    const googleResponse = await fetch(`${DIRECTIONS_API_URL}?${params.toString()}`)
    const data = await googleResponse.json()
    return new Response(JSON.stringify(data), {
      status: googleResponse.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Google API fetch failed: ${err}` }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
