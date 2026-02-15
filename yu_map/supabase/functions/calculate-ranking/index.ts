// supabase/functions/calculate-ranking/index.ts
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

    // Fetch all users
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id')

    if (usersError) {
      throw new Error(`Failed to fetch users: ${usersError.message}`)
    }

    let updatedCount = 0

    for (const user of users || []) {
      // Calculate explorer points
      const { count: visitCount } = await supabase
        .from('visits')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)

      const { count: contributionCount } = await supabase
        .from('facility_reports')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('status', 'approved')

      // Calculate social points
      const { count: reviewCount } = await supabase
        .from('reviews')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)

      const { data: likesData } = await supabase
        .from('reviews')
        .select('likes_count')
        .eq('user_id', user.id)

      const totalLikes = likesData?.reduce((sum: number, r: { likes_count: number }) => sum + (r.likes_count ?? 0), 0) ?? 0

      // Point calculation
      const explorerPoints = (visitCount ?? 0) * 100 + (contributionCount ?? 0) * 50
      const socialPoints = (reviewCount ?? 0) * 30 + totalLikes * 10
      const totalPoints = explorerPoints + socialPoints

      // Determine title based on total points
      const title = getTitle(totalPoints)

      // Upsert ranking (do NOT include total_points — it is a GENERATED ALWAYS column)
      const { error: upsertError } = await supabase
        .from('user_rankings')
        .upsert({
          user_id: user.id,
          explorer_points: explorerPoints,
          social_points: socialPoints,
          visit_count: visitCount ?? 0,
          contribution_count: contributionCount ?? 0,
          review_count: reviewCount ?? 0,
          likes_received: totalLikes,
          current_title: title,
          updated_at: new Date().toISOString()
        })

      if (upsertError) {
        console.error(`Failed to update ranking for user ${user.id}: ${upsertError.message}`)
      } else {
        updatedCount++
      }
    }

    // Update rank positions
    const { error: rpcError } = await supabase.rpc('update_rank_positions')
    if (rpcError) {
      console.error(`Failed to update rank positions: ${rpcError.message}`)
    }

    return new Response(
      JSON.stringify({ success: true, updated_users: updatedCount }),
      { headers: CORS_HEADERS }
    )
  } catch (error) {
    console.error('calculate-ranking error:', error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: CORS_HEADERS }
    )
  }
})

function getTitle(points: number): string {
  if (points >= 10000) return '\u6e6f\u30de\u30b9\u30bf\u30fc'
  if (points >= 5000) return '\u6e6f\u306e\u9054\u4eba'
  if (points >= 2000) return '\u6e6f\u3081\u3050\u308a\u540d\u4eba'
  if (points >= 1000) return '\u6e29\u6cc9\u611b\u597d\u5bb6'
  if (points >= 500) return '\u6e6f\u3081\u3050\u308a\u4e2d\u7d1a\u8005'
  return '\u6e6f\u3081\u3050\u308a\u521d\u5fc3\u8005'
}
