// supabase/functions/calculate-ranking/index.ts
// cron-triggered バッチジョブ。CRON_SECRET で認証。
// 環境変数: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_SECRET

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      },
    })
  }

  // CRON_SECRET 認証（pg_cron から呼ばれる場合のみ通過）
  const cronSecret = Deno.env.get('CRON_SECRET')
  const authHeader = req.headers.get('Authorization')
  if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: users, error: usersError } = await supabase
    .from('users')
    .select('id')

  if (usersError) {
    console.error('Failed to fetch users:', usersError)
    return new Response(JSON.stringify({ error: usersError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let updatedCount = 0
  for (const user of users ?? []) {
    const [
      { count: visitCount },
      { count: contributionCount },
      { count: reviewCount },
      { data: likesData },
    ] = await Promise.all([
      supabase.from('visits').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
      supabase.from('facility_reports').select('*', { count: 'exact', head: true }).eq('user_id', user.id).eq('status', 'approved'),
      supabase.from('reviews').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
      supabase.from('reviews').select('likes_count').eq('user_id', user.id),
    ])

    const totalLikes = likesData?.reduce((sum, r) => sum + (r.likes_count ?? 0), 0) ?? 0
    const explorerPoints = (visitCount ?? 0) * 100 + (contributionCount ?? 0) * 50
    const socialPoints = (reviewCount ?? 0) * 30 + totalLikes * 10
    const totalPoints = explorerPoints + socialPoints

    await supabase.from('user_rankings').upsert({
      user_id: user.id,
      explorer_points: explorerPoints,
      social_points: socialPoints,
      visit_count: visitCount ?? 0,
      contribution_count: contributionCount ?? 0,
      review_count: reviewCount ?? 0,
      likes_received: totalLikes,
      current_title: getTitle(totalPoints),
      updated_at: new Date().toISOString(),
    })
    updatedCount++
  }

  const { error: rankError } = await supabase.rpc('update_rank_positions')
  if (rankError) {
    console.error('update_rank_positions failed:', rankError)
  }

  return new Response(JSON.stringify({ success: true, updated_count: updatedCount }), {
    headers: { 'Content-Type': 'application/json' },
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
