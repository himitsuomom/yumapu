// supabase/functions/verify-contribution/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { facility_id, amenity_id, reported_value, user_id } = await req.json()
  
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
      contributed_by: user_id,
      verification_count: 1
    })
    
    // Award explorer points (Assuming awardPoints helper or direct insert)
    // For simplicity in this mock, we skip awardPoints call as it's not defined in the plan snippet fully
    // In a real app, this would call a shared helper or another function
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
    
    // Log the conflict for manual review (assuming table exists or logging mechanism)
    /* 
    await supabase.from('contribution_conflicts').insert({
      facility_id,
      amenity_id,
      existing_value: existing.value,
      new_value: reported_value,
      reporter_id: user_id
    }) 
    */
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
