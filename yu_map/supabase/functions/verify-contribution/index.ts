// supabase/functions/verify-contribution/index.ts
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  // Verify Authorization header
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Missing authorization header' }),
      { status: 401, headers: CORS_HEADERS }
    )
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Verify the JWT token and extract user info
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: CORS_HEADERS }
      )
    }

    const { facility_id, amenity_id, reported_value } = await req.json()

    // Validate required fields
    if (!facility_id || !amenity_id || reported_value === undefined) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: facility_id, amenity_id, reported_value' }),
        { status: 400, headers: CORS_HEADERS }
      )
    }

    const user_id = user.id

    // Check existing amenity data
    const { data: existing, error: fetchError } = await supabase
      .from('facility_amenities')
      .select('*')
      .eq('facility_id', facility_id)
      .eq('amenity_id', amenity_id)
      .maybeSingle()

    if (fetchError) {
      throw new Error(`Failed to fetch existing data: ${fetchError.message}`)
    }

    let action: string

    if (!existing) {
      // New contribution - create with base confidence
      const { error: insertError } = await supabase
        .from('facility_amenities')
        .insert({
          facility_id,
          amenity_id,
          value: reported_value,
          confidence_score: 50,
          contributed_by: user_id,
          verification_count: 1
        })

      if (insertError) {
        throw new Error(`Failed to insert contribution: ${insertError.message}`)
      }
      action = 'created'

    } else if (existing.value === reported_value) {
      // Verification matches - increase confidence
      const newConfidence = Math.min(100, existing.confidence_score + 10)
      const { error: updateError } = await supabase
        .from('facility_amenities')
        .update({
          confidence_score: newConfidence,
          verification_count: existing.verification_count + 1,
          verified_at: new Date().toISOString()
        })
        .eq('id', existing.id)

      if (updateError) {
        throw new Error(`Failed to update verification: ${updateError.message}`)
      }
      action = 'verified'

    } else {
      // Conflicting data - decrease confidence and log conflict
      const newConfidence = Math.max(0, existing.confidence_score - 5)
      const { error: conflictError } = await supabase
        .from('facility_amenities')
        .update({ confidence_score: newConfidence })
        .eq('id', existing.id)

      if (conflictError) {
        throw new Error(`Failed to update conflict: ${conflictError.message}`)
      }

      // Log the conflict for manual review
      await supabase.from('facility_reports').insert({
        facility_id,
        amenity_id,
        reported_value: String(reported_value),
        user_id,
        status: 'pending'
      })

      action = 'conflicted'
    }

    return new Response(
      JSON.stringify({ success: true, action }),
      { headers: CORS_HEADERS }
    )
  } catch (error) {
    console.error('verify-contribution error:', error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: CORS_HEADERS }
    )
  }
})
