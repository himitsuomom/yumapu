// supabase/functions/calculate-ranking/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Update all user rankings
  const { data: users, error } = await supabase
    .from('users')
    .select('id')

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

    const totalLikes = likesData?.reduce((sum, r) => sum + r.likes_count, 0) || 0

    // Point calculation
    const explorerPoints = (visitCount || 0) * 100 + (contributionCount || 0) * 50
    const socialPoints = (reviewCount || 0) * 30 + totalLikes * 10

    // Determine title based on total points
    const totalPoints = explorerPoints + socialPoints
    const title = getTitle(totalPoints)

    await supabase
      .from('user_rankings')
      .upsert({
        user_id: user.id,
        explorer_points: explorerPoints,
        social_points: socialPoints,
        visit_count: visitCount || 0,
        contribution_count: contributionCount || 0,
        review_count: reviewCount || 0,
        likes_received: totalLikes,
        current_title: title,
        updated_at: new Date().toISOString()
      })
  }

  // Update rank positions
  await supabase.rpc('update_rank_positions')

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})

function getTitle(points: number): string {
  if (points >= 10000) return '湯マスター'
  if (points >= 5000) return '湯の達人'
  if (points >= 2000) return '湯めぐり名人'
  if (points >= 1000) return '温泉愛好家'
  if (points >= 500) return '湯めぐり中級者'
  return '湯めぐり初心者'
}
