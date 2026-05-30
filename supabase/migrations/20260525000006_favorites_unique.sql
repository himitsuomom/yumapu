-- お気に入りのユニーク制約追加
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'favorites_user_facility_unique'
  ) THEN
    -- 既存重複を先に削除
    DELETE FROM favorites a USING favorites b
      WHERE a.id > b.id AND a.user_id = b.user_id AND a.facility_id = b.facility_id;

    -- ユニーク制約追加
    ALTER TABLE favorites
      ADD CONSTRAINT favorites_user_facility_unique UNIQUE (user_id, facility_id);
  END IF;
END $$;
