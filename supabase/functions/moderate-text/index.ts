// supabase/functions/moderate-text/index.ts
//
// レビュー本文のテキストモデレーション。
// MODERATION_TEXT_PROVIDER 環境変数で切替:
//   'mock'              → 日本語NGワードリストで判定（API不要・開発用）
//   'openai_moderation' → OpenAI Moderation API で判定

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// 日本語 NGワードリスト（mock プロバイダー用）
const NG_WORDS = [
  '詐欺', '死ね', '殺す', '殺せ', 'クソ', 'バカ', 'アホ',
  'スパム', '出会い系', '無料で稼ぐ', 'クリック', '副業',
];

interface ModerateTextRequest {
  text: string;
  context?: 'review' | 'post' | 'comment';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  // JWT 認証チェック
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return errorResponse('UNAUTHORIZED', '認証が必要です', 401);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return errorResponse('UNAUTHORIZED', '認証が必要です', 401);
  }

  let body: ModerateTextRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse('INVALID_INPUT', 'リクエスト形式が不正です', 400);
  }

  if (!body.text || typeof body.text !== 'string') {
    return errorResponse('INVALID_INPUT', 'text フィールドが必要です', 400);
  }

  const provider = Deno.env.get('MODERATION_TEXT_PROVIDER') ?? 'mock';

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    let result: { passed: boolean; categories: string[]; confidence: number; reason?: string };

    if (provider === 'openai_moderation') {
      result = await moderateWithOpenAI(body.text, controller.signal);
    } else {
      result = moderateWithMock(body.text);
    }

    clearTimeout(timeoutId);

    return new Response(
      JSON.stringify({ ...result, provider }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    if ((err as Error).name === 'AbortError') {
      // タイムアウト → 安全側フォールバック（blocked）
      return new Response(
        JSON.stringify({ passed: false, categories: ['timeout'], confidence: 1.0, reason: 'timeout', provider }),
        { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }
    return errorResponse('PROVIDER_ERROR', 'モデレーションサービスで問題が発生しました', 500);
  }
});

function moderateWithMock(text: string): { passed: boolean; categories: string[]; confidence: number; reason?: string } {
  const found = NG_WORDS.filter((w) => text.includes(w));
  if (found.length > 0) {
    return { passed: false, categories: ['harassment', 'spam'], confidence: 0.95, reason: 'ng_word_matched' };
  }
  return { passed: true, categories: [], confidence: 0.0 };
}

async function moderateWithOpenAI(
  text: string,
  signal: AbortSignal,
): Promise<{ passed: boolean; categories: string[]; confidence: number; reason?: string }> {
  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) throw new Error('OPENAI_API_KEY not set');

  const res = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ input: text }),
    signal,
  });

  if (!res.ok) throw new Error(`OpenAI API error: ${res.status}`);

  const data = await res.json();
  const result = data.results[0];
  const flagged: string[] = Object.entries(result.categories as Record<string, boolean>)
    .filter(([, v]) => v)
    .map(([k]) => k);

  return {
    passed: !result.flagged,
    categories: flagged,
    confidence: Math.max(0, ...Object.values(result.category_scores as Record<string, number>)),
    reason: result.flagged ? 'openai_flagged' : undefined,
  };
}

function errorResponse(code: string, message: string, status: number): Response {
  return new Response(
    JSON.stringify({ error: message, code }),
    { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
  );
}
