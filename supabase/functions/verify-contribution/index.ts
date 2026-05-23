// supabase/functions/verify-contribution/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // JWT 認証チェック — 未認証リクエストを拒否する
  const authHeader = req.headers.get('Authorization')
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Missing or invalid Authorization header' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Anon key クライアント（ユーザーのJWTで認証）
  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  // 認証済みユーザーを取得
  const { data: { user }, error: authError } = await supabaseUser.auth.getUser()
  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const { facility_id, amenity_id, reported_value } = await req.json()

  // user_id はリクエストボディからではなく、認証済みJWTから取得する
  const userId = user.id

  if (!facility_id || !amenity_id || reported_value === undefined) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: facility_id, amenity_id, reported_value' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // SERVICE_ROLE_KEY クライアント（RLSバイパスでDB操作）
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Check existing amenity data
  const { data: existing } = await supabase
    .from('facility_amenities')
    .select('*')
    .eq('facility_id', facility_id)
    .eq('amenity_id', amenity_id)
    .single()

  if (!existing) {
    // New contribution - create with base confidence
    await supabase.from('facility_amenities').insert({
      facility_id,
      amenity_id,
      value: reported_value,
      confidence_score: 50,
      contributed_by: userId,
      verification_count: 1
    })
  } else if (existing.value === reported_value) {
    // Verification matches - increase confidence
    const newConfidence = Math.min(100, existing.confidence_score + 10)
    await supabase.from('facility_amenities')
      .update({
        confidence_score: newConfidence,
        verification_count: existing.verification_count + 1,
        verified_at: new Date().toISOString()
      })
      .eq('id', existing.id)
  } else {
    // Conflicting data - decrease confidence or flag for review
    const newConfidence = Math.max(0, existing.confidence_score - 5)
    await supabase.from('facility_amenities')
      .update({ confidence_score: newConfidence })
      .eq('id', existing.id)
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
})
