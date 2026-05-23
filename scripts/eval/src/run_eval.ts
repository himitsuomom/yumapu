import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const gitSha = process.env.GIT_SHA ?? 'local';

if (!url || !key) {
  throw new Error('SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を環境変数に設定してください');
}

const supabase = createClient(url, key, { auth: { persistSession: false } });

const METHODS = ['all', 'regex_brackets', 'dict_aho'] as const;
type Method = typeof METHODS[number];

interface Metrics {
  tp: number;
  fp: number;
  fn: number;
  precision_score: number | null;
  recall_score: number | null;
  f1_score: number | null;
  sample_size: number;
}

async function evalOne(method: Method): Promise<void> {
  const rpcArg = method === 'all' ? null : method;

  const { data, error } = await supabase.rpc('compute_matching_metrics', {
    p_match_method: rpcArg,
  });
  if (error) throw new Error(`compute_matching_metrics(${method}): ${error.message}`);

  const m = (Array.isArray(data) ? data[0] : data) as Metrics | undefined;
  if (!m) {
    console.warn(`[eval] ${method}: メトリクス取得失敗`);
    return;
  }

  console.log(
    `[eval] ${method}: TP=${m.tp} FP=${m.fp} FN=${m.fn} ` +
    `P=${m.precision_score?.toFixed(3) ?? 'n/a'} ` +
    `R=${m.recall_score?.toFixed(3) ?? 'n/a'} ` +
    `F1=${m.f1_score?.toFixed(3) ?? 'n/a'} ` +
    `(n=${m.sample_size})`,
  );

  const { error: insErr } = await supabase.from('eval_runs').insert({
    match_method: method,
    tp: m.tp,
    fp: m.fp,
    fn: m.fn,
    precision_score: m.precision_score,
    recall_score: m.recall_score,
    f1_score: m.f1_score,
    sample_size: m.sample_size,
    git_sha: gitSha,
  });
  if (insErr) throw new Error(`eval_runs insert: ${insErr.message}`);
}

async function main() {
  console.log(`[eval] 開始 ${new Date().toISOString()} (sha=${gitSha})`);

  const { count, error: cntErr } = await supabase
    .from('gold_annotations')
    .select('*', { count: 'exact', head: true });
  if (cntErr) throw new Error(`gold count: ${cntErr.message}`);
  if (!count || count === 0) {
    console.warn('[eval] gold_annotations が空のためスキップします');
    return;
  }
  console.log(`[eval] gold_annotations: ${count}件`);

  for (const m of METHODS) {
    await evalOne(m);
  }

  console.log(`[eval] 完了 ${new Date().toISOString()}`);
}

main().catch((err) => {
  console.error('[eval] 致命的エラー:', err);
  process.exit(1);
});
