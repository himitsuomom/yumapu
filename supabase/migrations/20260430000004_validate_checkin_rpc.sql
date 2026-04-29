-- Wave 2: validate_checkin RPC（PostGIS ST_DWithin によるサーバー側 GPS 距離検証）
-- GPS 改竄バイパスを防ぐため、距離判定をクライアントではなく DB で行う

CREATE OR REPLACE FUNCTION validate_checkin(
  p_facility_id UUID,
  p_user_lat    DOUBLE PRECISION,
  p_user_lon    DOUBLE PRECISION,
  p_max_meters  DOUBLE PRECISION DEFAULT 100.0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_facility_location GEOGRAPHY;
  v_distance          DOUBLE PRECISION;
BEGIN
  SELECT location INTO v_facility_location
  FROM facilities
  WHERE id = p_facility_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'allowed', false,
      'reason', 'facility_not_found'
    );
  END IF;

  IF ST_DWithin(
    v_facility_location,
    ST_SetSRID(ST_MakePoint(p_user_lon, p_user_lat), 4326)::geography,
    p_max_meters
  ) THEN
    RETURN json_build_object(
      'allowed', true,
      'distance_meters', ST_Distance(
        v_facility_location,
        ST_SetSRID(ST_MakePoint(p_user_lon, p_user_lat), 4326)::geography
      )
    );
  ELSE
    v_distance := ST_Distance(
      v_facility_location,
      ST_SetSRID(ST_MakePoint(p_user_lon, p_user_lat), 4326)::geography
    );
    RETURN json_build_object(
      'allowed', false,
      'reason', 'too_far',
      'distance_meters', v_distance,
      'max_meters', p_max_meters
    );
  END IF;
END;
$$;

-- PUBLIC の実行権限を剥奪し、ログイン済みユーザーにのみ付与
REVOKE ALL ON FUNCTION validate_checkin(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION validate_checkin(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
