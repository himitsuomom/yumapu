import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const DISCORD_WEBHOOK = Deno.env.get('DISCORD_SLA_WEBHOOK_URL')!;

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  // CRON_SECRET 認証
  const cronSecret = Deno.env.get('CRON_SECRET');
  const authHeader = req.headers.get('Authorization');
  if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  const { data: breaches, error } = await supabase.rpc('check_removal_sla_breach');
  if (error) {
    console.error('SLA check failed:', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  if (!breaches || breaches.length === 0) {
    return new Response(JSON.stringify({ message: 'no breaches', count: 0 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const embed = {
    title: `⚠️ GDPR 30日SLA期限警告: ${breaches.length}件`,
    color: 0xff6b6b,
    fields: (breaches as { request_id: string; request_type: string; days_remaining: number; erasure_deadline: string }[]).slice(0, 10).map((b) => ({
      name: `${b.request_type} / 残り ${b.days_remaining.toFixed(1)}日`,
      value: `ID: \`${b.request_id}\`\n期限: ${new Date(b.erasure_deadline).toISOString()}`,
      inline: false,
    })),
    timestamp: new Date().toISOString(),
  };

  const discordRes = await fetch(DISCORD_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ embeds: [embed] }),
  });

  if (!discordRes.ok) {
    console.error('Discord webhook failed:', await discordRes.text());
    return new Response(JSON.stringify({ error: 'discord webhook failed' }), { status: 502 });
  }

  const ids = (breaches as { request_id: string }[]).map((b) => b.request_id);
  const { error: updateError } = await supabase
    .from('removal_requests')
    .update({ sla_notified_at: new Date().toISOString() })
    .in('id', ids);

  if (updateError) {
    console.error('Failed to mark notified:', updateError);
  }

  return new Response(
    JSON.stringify({ notified_count: breaches.length, request_ids: ids }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
