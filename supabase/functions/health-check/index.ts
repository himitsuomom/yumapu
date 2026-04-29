// supabase/functions/health-check/index.ts
//
// モデレーションプロバイダーの稼働状態を返す（認証不要・30秒キャッシュ）。
// Flutter 側が投稿前にこのエンドポイントを呼び出し、
// healthy: false の場合は投稿ボタンを disable にする。

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  const imageProvider = Deno.env.get('MODERATION_IMAGE_PROVIDER') ?? 'mock';
  const textProvider  = Deno.env.get('MODERATION_TEXT_PROVIDER') ?? 'mock';

  // mock プロバイダーは常に ok
  const imageStatus = imageProvider === 'mock' ? 'ok' : await checkProvider('image', imageProvider);
  const textStatus  = textProvider  === 'mock' ? 'ok' : await checkProvider('text', textProvider);

  const healthy = imageStatus !== 'down' && textStatus !== 'down';

  const body = JSON.stringify({
    healthy,
    providers: {
      image_moderation: imageStatus,
      text_moderation:  textStatus,
    },
    checked_at: new Date().toISOString(),
  });

  return new Response(body, {
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
      // 30秒キャッシュで頻繁なポーリングを抑制
      'Cache-Control': 'public, max-age=30',
    },
  });
});

async function checkProvider(
  _type: 'image' | 'text',
  provider: string,
): Promise<'ok' | 'degraded' | 'down'> {
  // 本番プロバイダーのヘルスチェックは ping で代替
  // 実際の疎通確認は簡易 HEAD リクエストで行う
  try {
    const urls: Record<string, string> = {
      aws_rekognition:    'https://rekognition.us-east-1.amazonaws.com',
      openai_moderation:  'https://api.openai.com',
      google_vision:      'https://vision.googleapis.com',
    };
    const url = urls[provider];
    if (!url) return 'degraded';

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);
    const res = await fetch(url, { method: 'HEAD', signal: controller.signal });
    clearTimeout(timeout);
    return res.ok || res.status < 500 ? 'ok' : 'degraded';
  } catch {
    return 'down';
  }
}
