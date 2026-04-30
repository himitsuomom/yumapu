/**
 * 湯マップ MCP サーバー（Supabase Edge Function）
 *
 * デプロイ:
 *   supabase functions deploy mcp-server --no-verify-jwt
 *
 * Claude Code への接続:
 *   claude mcp add --transport http yumap \
 *     https://<project-ref>.supabase.co/functions/v1/mcp-server
 *
 * 提供ツール:
 *   search_baths     — 名前・位置で施設を検索
 *   get_bath         — 施設詳細 + 最新SNS言及
 *   search_mentions  — キーワードで言及投稿を全文検索
 *
 * プロトコル: MCP 2024-11-05 / JSON-RPC 2.0 over HTTP
 * SDK非依存実装 — Deno Runtime で確実に動作する
 */

import { createClient } from 'npm:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// ------------------------------------------------------------------ types

interface JsonRpcRequest {
  jsonrpc: '2.0';
  id: string | number | null;
  method: string;
  params?: Record<string, unknown>;
}

interface JsonRpcResponse {
  jsonrpc: '2.0';
  id: string | number | null;
  result?: unknown;
  error?: { code: number; message: string; data?: unknown };
}

function ok(id: string | number | null, result: unknown): JsonRpcResponse {
  return { jsonrpc: '2.0', id, result };
}
function err(id: string | number | null, code: number, message: string): JsonRpcResponse {
  return { jsonrpc: '2.0', id, error: { code, message } };
}

// ------------------------------------------------------------------ tool definitions

const TOOLS = [
  {
    name: 'search_baths',
    description: '施設名・住所キーワード、または緯度経度半径で温泉・銭湯・サウナを検索する',
    inputSchema: {
      type: 'object',
      properties: {
        query:    { type: 'string',  description: '施設名や地名キーワード（省略可）' },
        lat:      { type: 'number',  description: '中心緯度（省略可）' },
        lng:      { type: 'number',  description: '中心経度（省略可）' },
        radius_m: { type: 'number',  description: '半径メートル（デフォルト 5000）' },
        limit:    { type: 'integer', description: '最大件数（デフォルト 20）' },
      },
    },
  },
  {
    name: 'get_bath',
    description: '施設IDで詳細情報と最新SNS言及を取得する',
    inputSchema: {
      type: 'object',
      required: ['facility_id'],
      properties: {
        facility_id:   { type: 'string',  description: '施設UUID' },
        mention_limit: { type: 'integer', description: '取得する言及件数（デフォルト 10）' },
      },
    },
  },
  {
    name: 'search_mentions',
    description: 'SNS・ブログ投稿をキーワードで全文検索する',
    inputSchema: {
      type: 'object',
      required: ['query'],
      properties: {
        query:    { type: 'string',  description: '検索キーワード' },
        platform: { type: 'string',  description: 'misskey | mastodon | youtube | rss（省略=全て）' },
        limit:    { type: 'integer', description: '最大件数（デフォルト 20）' },
      },
    },
  },
];

// ------------------------------------------------------------------ tool execution

async function callTool(name: string, args: Record<string, unknown>): Promise<{ content: Array<{ type: string; text: string }>; isError?: boolean }> {
  try {
    if (name === 'search_baths') {
      const { query, lat, lng, limit = 20 } = args as {
        query?: string; lat?: number; lng?: number; limit?: number;
      };

      if (lat != null && lng != null) {
        const { data, error } = await supabase.rpc('get_facilities_in_bounds', {
          min_lat: lat - 0.05, max_lat: lat + 0.05,
          min_lng: lng - 0.07, max_lng: lng + 0.07,
        });
        if (error) return mcpErr(error.message);
        return mcpText((data ?? []).slice(0, limit));
      }
      if (query) {
        const { data, error } = await supabase
          .from('facilities')
          .select('id, name, facility_type, address, latitude, longitude')
          .ilike('name', `%${query}%`)
          .limit(Number(limit));
        if (error) return mcpErr(error.message);
        return mcpText(data ?? []);
      }
      return mcpErr('query か lat/lng を指定してください');
    }

    if (name === 'get_bath') {
      const { facility_id, mention_limit = 10 } = args as { facility_id: string; mention_limit?: number };
      const [fRes, mRes] = await Promise.all([
        supabase.from('facilities').select('*').eq('id', facility_id).single(),
        supabase
          .from('facility_mentions')
          .select('excerpt, match_method, created_at, source_posts(platform, source_handle, url, title, thumbnail_url)')
          .eq('facility_id', facility_id)
          .order('created_at', { ascending: false })
          .limit(Number(mention_limit)),
      ]);
      if (fRes.error) return mcpErr(fRes.error.message);
      return mcpText({ facility: fRes.data, recent_mentions: mRes.data ?? [] });
    }

    if (name === 'search_mentions') {
      const { query, platform, limit = 20 } = args as { query: string; platform?: string; limit?: number };
      let q = supabase
        .from('source_posts')
        .select('id, platform, source_handle, url, title, content_text, thumbnail_url, published_at')
        .ilike('content_text', `%${query}%`)
        .order('published_at', { ascending: false })
        .limit(Number(limit));
      if (platform) q = q.eq('platform', platform);
      const { data, error } = await q;
      if (error) return mcpErr(error.message);
      return mcpText(data ?? []);
    }

    return mcpErr(`不明なツール: ${name}`);
  } catch (e) {
    return mcpErr(String(e));
  }
}

function mcpText(data: unknown) {
  return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
}
function mcpErr(msg: string) {
  return { content: [{ type: 'text', text: `エラー: ${msg}` }], isError: true as const };
}

// ------------------------------------------------------------------ JSON-RPC dispatcher

async function dispatch(req: JsonRpcRequest): Promise<JsonRpcResponse> {
  const { id, method, params = {} } = req;

  switch (method) {
    case 'initialize':
      return ok(id, {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'yumap-mcp', version: '1.0.0' },
      });

    case 'notifications/initialized':
      // 通知は応答不要だが、id=null なので ok で返す
      return ok(null, {});

    case 'tools/list':
      return ok(id, { tools: TOOLS });

    case 'tools/call': {
      const name = String(params.name ?? '');
      const args = (params.arguments ?? {}) as Record<string, unknown>;
      const result = await callTool(name, args);
      return ok(id, result);
    }

    default:
      return err(id, -32601, `Method not found: ${method}`);
  }
}

// ------------------------------------------------------------------ HTTP handler

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }

  if (req.method !== 'POST') {
    return new Response('MCP server — POST only', { status: 405, headers: CORS });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }, 400);
  }

  // バッチ対応
  if (Array.isArray(body)) {
    const responses = await Promise.all(body.map((r) => dispatch(r as JsonRpcRequest)));
    return json(responses.filter((r) => r.id !== null));
  }

  const response = await dispatch(body as JsonRpcRequest);
  // 通知（id=null）は 204 で返す
  if (response.id === null && !response.error) {
    return new Response(null, { status: 204, headers: CORS });
  }
  return json(response);
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
