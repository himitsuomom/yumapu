-- ============================================================
-- W2-精度評価: gold_annotations / eval_runs
-- ============================================================

CREATE TABLE IF NOT EXISTS gold_annotations (
  id              BIGSERIAL PRIMARY KEY,
  post_id         TEXT NOT NULL REFERENCES source_posts(id) ON DELETE CASCADE,
  entity_text     TEXT NOT NULL,
  entity_type     TEXT NOT NULL DEFAULT 'facility'
                    CHECK (entity_type IN ('facility','non_facility','ambiguous')),
  expected_facility_id UUID REFERENCES facilities(id) ON DELETE SET NULL,
  annotator       TEXT NOT NULL,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT gold_annotations_unique
    UNIQUE (post_id, entity_text, annotator)
);

CREATE INDEX IF NOT EXISTS idx_gold_annotations_post
  ON gold_annotations (post_id);
CREATE INDEX IF NOT EXISTS idx_gold_annotations_facility
  ON gold_annotations (expected_facility_id)
  WHERE expected_facility_id IS NOT NULL;

ALTER TABLE gold_annotations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "gold_annotations_read_auth"
  ON gold_annotations FOR SELECT TO authenticated USING (TRUE);

CREATE TABLE IF NOT EXISTS eval_runs (
  id              BIGSERIAL PRIMARY KEY,
  run_at          TIMESTAMPTZ DEFAULT NOW(),
  match_method    TEXT NOT NULL,
  tp              INT NOT NULL DEFAULT 0,
  fp              INT NOT NULL DEFAULT 0,
  fn              INT NOT NULL DEFAULT 0,
  precision_score REAL,
  recall_score    REAL,
  f1_score        REAL,
  sample_size     INT NOT NULL DEFAULT 0,
  git_sha         TEXT,
  notes           TEXT
);

CREATE INDEX IF NOT EXISTS idx_eval_runs_recent
  ON eval_runs (run_at DESC);

ALTER TABLE eval_runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "eval_runs_read_auth"
  ON eval_runs FOR SELECT TO authenticated USING (TRUE);

CREATE OR REPLACE FUNCTION compute_matching_metrics(
  p_match_method TEXT DEFAULT NULL
)
RETURNS TABLE (
  tp INT,
  fp INT,
  fn INT,
  precision_score REAL,
  recall_score REAL,
  f1_score REAL,
  sample_size INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tp INT;
  v_fp INT;
  v_fn INT;
  v_precision REAL;
  v_recall REAL;
  v_f1 REAL;
  v_sample INT;
BEGIN
  WITH evaluable_posts AS (
    SELECT DISTINCT post_id FROM gold_annotations
  ),
  system_predictions AS (
    SELECT fm.post_id, fm.facility_id
    FROM facility_mentions fm
    JOIN evaluable_posts ep ON ep.post_id = fm.post_id
    WHERE p_match_method IS NULL OR fm.match_method = p_match_method
  ),
  gold AS (
    SELECT ga.post_id, ga.expected_facility_id AS facility_id
    FROM gold_annotations ga
    WHERE ga.entity_type = 'facility' AND ga.expected_facility_id IS NOT NULL
  )
  SELECT
    COUNT(*) FILTER (WHERE g.facility_id IS NOT NULL AND s.facility_id IS NOT NULL),
    COUNT(*) FILTER (WHERE g.facility_id IS NULL AND s.facility_id IS NOT NULL),
    COUNT(*) FILTER (WHERE g.facility_id IS NOT NULL AND s.facility_id IS NULL),
    (SELECT COUNT(*) FROM evaluable_posts)
  INTO v_tp, v_fp, v_fn, v_sample
  FROM system_predictions s
  FULL OUTER JOIN gold g
    ON s.post_id = g.post_id AND s.facility_id = g.facility_id;

  v_precision := CASE WHEN (v_tp + v_fp) = 0 THEN NULL
                      ELSE v_tp::REAL / (v_tp + v_fp) END;
  v_recall    := CASE WHEN (v_tp + v_fn) = 0 THEN NULL
                      ELSE v_tp::REAL / (v_tp + v_fn) END;
  v_f1        := CASE WHEN v_precision IS NULL OR v_recall IS NULL OR (v_precision + v_recall) = 0
                      THEN NULL
                      ELSE 2 * v_precision * v_recall / (v_precision + v_recall) END;

  RETURN QUERY SELECT v_tp, v_fp, v_fn, v_precision, v_recall, v_f1, v_sample;
END;
$$;

COMMENT ON FUNCTION compute_matching_metrics IS
  'gold_annotations と facility_mentions を比較して precision/recall/F1 を計算。';
