import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'GET') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const url = new URL(req.url);
  const window = url.searchParams.get('window') ?? '7d';
  const limit = Math.min(Number(url.searchParams.get('limit') ?? '50'), 200);

  const orderColumn =
    window === '24h' ? 'mentions_24h' :
    window === '30d' ? 'mentions_30d' :
    'mentions_7d';

  const supabase = createClient(SUPABASE_URL, ANON_KEY);

  const { data, error } = await supabase
    .from('facility_trends')
    .select('facility_id, mentions_24h, mentions_7d, mentions_30d, last_mentioned_at, avg_score_7d, refreshed_at')
    .gt(orderColumn, 0)
    .order(orderColumn, { ascending: false })
    .limit(limit);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ window, count: data?.length ?? 0, items: data ?? [] }), {
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=300, s-maxage=300, stale-while-revalidate=60',
    },
  });
});
