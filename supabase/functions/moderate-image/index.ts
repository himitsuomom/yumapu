// supabase/functions/moderate-image/index.ts
//
// 画像モデレーション。Supabase Storage の URL を受け取り判定する。
// MODERATION_IMAGE_PROVIDER 環境変数で切替:
//   'mock'           → URL末尾に 'nsfw' / 'blocked' を含む場合 blocked（テスト用）
//   'aws_rekognition' → AWS Rekognition DetectModerationLabels で判定

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ModerateImageRequest {
  image_url: string;
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

  let body: ModerateImageRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse('INVALID_INPUT', 'リクエスト形式が不正です', 400);
  }

  if (!body.image_url || typeof body.image_url !== 'string') {
    return errorResponse('INVALID_INPUT', 'image_url フィールドが必要です', 400);
  }

  const provider = Deno.env.get('MODERATION_IMAGE_PROVIDER') ?? 'mock';

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    let result: { passed: boolean; categories: string[]; confidence: number; reason?: string };

    if (provider === 'aws_rekognition') {
      result = await moderateWithRekognition(body.image_url, controller.signal);
    } else {
      result = moderateWithMock(body.image_url);
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

function moderateWithMock(imageUrl: string): { passed: boolean; categories: string[]; confidence: number; reason?: string } {
  // テスト用: URL に 'nsfw' または 'blocked' が含まれると blocked と判定
  const lower = imageUrl.toLowerCase();
  if (lower.includes('nsfw') || lower.includes('blocked')) {
    return { passed: false, categories: ['nsfw'], confidence: 0.99, reason: 'mock_blocked' };
  }
  return { passed: true, categories: [], confidence: 0.0 };
}

async function moderateWithRekognition(
  imageUrl: string,
  signal: AbortSignal,
): Promise<{ passed: boolean; categories: string[]; confidence: number; reason?: string }> {
  const accessKey = Deno.env.get('REKOGNITION_ACCESS_KEY');
  const secretKey = Deno.env.get('REKOGNITION_SECRET_KEY');
  const region    = Deno.env.get('REKOGNITION_REGION') ?? 'us-east-1';

  if (!accessKey || !secretKey) throw new Error('Rekognition credentials not set');

  // Rekognition は S3 URI または Base64 バイトを受け取る。
  // Supabase Storage の公開 URL から画像バイトを取得して渡す。
  const imgRes = await fetch(imageUrl, { signal });
  if (!imgRes.ok) throw new Error(`Failed to fetch image: ${imgRes.status}`);
  const imgBytes = await imgRes.arrayBuffer();
  const imgBase64 = btoa(String.fromCharCode(...new Uint8Array(imgBytes)));

  const endpoint = `https://rekognition.${region}.amazonaws.com/`;
  const payload = JSON.stringify({
    Image: { Bytes: imgBase64 },
    MinConfidence: 60,
  });

  // AWS Signature V4 署名（簡易版 - Deno 用）
  const signedHeaders = await signAwsRequest({
    method: 'POST',
    url: endpoint,
    service: 'rekognition',
    region,
    accessKey,
    secretKey,
    body: payload,
    amzTarget: 'RekognitionService.DetectModerationLabels',
  });

  const res = await fetch(endpoint, {
    method: 'POST',
    headers: signedHeaders,
    body: payload,
    signal,
  });

  if (!res.ok) throw new Error(`Rekognition error: ${res.status}`);

  const data = await res.json();
  const labels: Array<{ Name: string; Confidence: number }> = data.ModerationLabels ?? [];

  if (labels.length > 0) {
    const maxConf = Math.max(...labels.map((l) => l.Confidence / 100));
    return {
      passed: false,
      categories: labels.map((l) => l.Name.toLowerCase().replace(/ /g, '_')),
      confidence: maxConf,
      reason: 'rekognition_flagged',
    };
  }

  return { passed: true, categories: [], confidence: 0.0 };
}

// AWS Signature V4 署名ヘルパー（Deno 用簡易実装）
async function signAwsRequest(params: {
  method: string;
  url: string;
  service: string;
  region: string;
  accessKey: string;
  secretKey: string;
  body: string;
  amzTarget: string;
}): Promise<Record<string, string>> {
  const { method, url, service, region, accessKey, secretKey, body, amzTarget } = params;

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '').slice(0, 15) + 'Z';
  const dateStamp = amzDate.slice(0, 8);

  const bodyHash = await sha256Hex(body);
  const host = new URL(url).host;

  const headers: Record<string, string> = {
    'Content-Type': 'application/x-amz-json-1.1',
    'X-Amz-Date': amzDate,
    'X-Amz-Target': amzTarget,
    'Host': host,
  };

  const signedHeadersList = Object.keys(headers).map((k) => k.toLowerCase()).sort();
  const signedHeadersStr = signedHeadersList.join(';');
  const canonicalHeaders = signedHeadersList
    .map((k) => `${k}:${headers[Object.keys(headers).find((h) => h.toLowerCase() === k)!]}\n`)
    .join('');

  const canonicalRequest = [method, '/', '', canonicalHeaders, signedHeadersStr, bodyHash].join('\n');
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    'AWS4-HMAC-SHA256', amzDate, credentialScope, await sha256Hex(canonicalRequest),
  ].join('\n');

  const signingKey = await getSigningKey(secretKey, dateStamp, region, service);
  const signature = await hmacHex(signingKey, stringToSign);

  const authorization =
    `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, ` +
    `SignedHeaders=${signedHeadersStr}, Signature=${signature}`;

  return { ...headers, Authorization: authorization };
}

async function sha256Hex(data: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function hmacHex(key: ArrayBuffer | Uint8Array, data: string): Promise<string> {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', k, new TextEncoder().encode(data));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function hmacBytes(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return crypto.subtle.sign('HMAC', k, new TextEncoder().encode(data));
}

async function getSigningKey(
  secretKey: string, dateStamp: string, region: string, service: string,
): Promise<ArrayBuffer> {
  const kDate    = await hmacBytes(new TextEncoder().encode(`AWS4${secretKey}`), dateStamp);
  const kRegion  = await hmacBytes(kDate, region);
  const kService = await hmacBytes(kRegion, service);
  return hmacBytes(kService, 'aws4_request');
}

function errorResponse(code: string, message: string, status: number): Response {
  return new Response(
    JSON.stringify({ error: message, code }),
    { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
  );
}
