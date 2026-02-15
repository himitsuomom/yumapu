-- Enable PostGIS
create extension if not exists postgis;

-- 1. PREFECTURES
CREATE TABLE prefectures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    name_en VARCHAR(50),
    region VARCHAR(50)
);

-- 2. FACILITY TYPES
CREATE TABLE facility_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name_ja VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL
);

-- 3. FACILITIES
CREATE TABLE facilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    name_kana VARCHAR(255),
    google_place_id VARCHAR(255) UNIQUE,
    prefecture_id UUID REFERENCES prefectures(id),
    facility_type_id UUID REFERENCES facility_types(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    -- Denormalized lat/lng for simpler client-side queries
    latitude DOUBLE PRECISION GENERATED ALWAYS AS (ST_Y(location::geometry)) STORED,
    longitude DOUBLE PRECISION GENERATED ALWAYS AS (ST_X(location::geometry)) STORED,
    address TEXT,
    phone VARCHAR(20),
    website VARCHAR(500),
    business_hours JSONB DEFAULT '{}',
    price_info JSONB DEFAULT '{}',
    amenities JSONB DEFAULT '{}',
    data_source VARCHAR(50) NOT NULL DEFAULT 'government',
    data_quality_score INT DEFAULT 1 CHECK (data_quality_score BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices for Facilities
CREATE INDEX idx_facilities_location ON facilities USING GIST (location);
CREATE INDEX idx_facilities_prefecture ON facilities (prefecture_id);
CREATE INDEX idx_facilities_type ON facilities (facility_type_id);
CREATE INDEX idx_facilities_google_place ON facilities (google_place_id);
CREATE INDEX idx_facilities_name ON facilities USING GIN (name gin_trgm_ops);
CREATE INDEX idx_facilities_amenities ON facilities USING GIN (amenities);

-- 4. AMENITIES
CREATE TABLE amenities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name_ja VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    value_type VARCHAR(20) NOT NULL DEFAULT 'boolean'
);

-- Seed Initial Amenities
INSERT INTO amenities (code, name_ja, name_en, category, value_type) VALUES
    ('tattoo_friendly', 'タトゥーOK', 'Tattoo Friendly', 'policy', 'boolean'),
    ('parking', '駐車場', 'Parking', 'facility', 'boolean'),
    ('outdoor_bath', '露天風呂', 'Outdoor Bath', 'bath', 'boolean'),
    ('cold_plunge', '水風呂', 'Cold Plunge', 'bath', 'boolean'),
    ('cold_plunge_temp', '水風呂温度', 'Cold Plunge Temp', 'bath', 'number'),
    ('mixed_bath', '混浴', 'Mixed Bath', 'bath', 'boolean'),
    ('stone_sauna', '岩盤浴', 'Stone Sauna', 'sauna', 'boolean'),
    ('lodging', '宿泊施設', 'Lodging', 'facility', 'boolean'),
    ('natural_hot_spring', '天然温泉', 'Natural Hot Springs', 'water', 'boolean'),
    ('sauna', 'サウナ', 'Sauna', 'sauna', 'boolean'),
    ('sauna_temp', 'サウナ温度', 'Sauna Temp', 'sauna', 'number');

-- 5. USERS (Extends Supabase Auth)
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255),
    username VARCHAR(50) UNIQUE,
    display_name VARCHAR(100),
    avatar_url TEXT,
    bio TEXT,
    is_premium BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_active_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. FACILITY AMENITIES (User Contributions)
CREATE TABLE facility_amenities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    amenity_id UUID NOT NULL REFERENCES amenities(id),
    value VARCHAR(100) NOT NULL,
    confidence_score INT DEFAULT 50 CHECK (confidence_score BETWEEN 0 AND 100),
    contributed_by UUID REFERENCES users(id),
    verification_count INT DEFAULT 1,
    verified_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (facility_id, amenity_id)
);

CREATE INDEX idx_facility_amenities_facility ON facility_amenities (facility_id);
CREATE INDEX idx_facility_amenities_confidence ON facility_amenities (confidence_score DESC);

-- 7. VISITS (with duplicate prevention per day)
CREATE TABLE visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    visited_at TIMESTAMPTZ DEFAULT NOW(),
    verified BOOLEAN DEFAULT FALSE,
    check_in_location GEOGRAPHY(POINT, 4326)
);

-- Prevent duplicate check-ins to the same facility on the same day
CREATE UNIQUE INDEX idx_visits_unique_daily
    ON visits (user_id, facility_id, (visited_at::date));

CREATE INDEX idx_visits_user ON visits (user_id);
CREATE INDEX idx_visits_facility ON visits (facility_id);

-- 8. REVIEWS
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    content TEXT,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    likes_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reviews_facility ON reviews (facility_id);
CREATE INDEX idx_reviews_user ON reviews (user_id);
CREATE INDEX idx_reviews_rating ON reviews (rating);

-- 9. PHOTOS
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    facility_id UUID REFERENCES facilities(id) ON DELETE CASCADE,
    review_id UUID REFERENCES reviews(id) ON DELETE CASCADE,
    visit_id UUID REFERENCES visits(id) ON DELETE CASCADE,
    storage_path VARCHAR(500) NOT NULL,
    thumbnail_path VARCHAR(500),
    has_logo_overlay BOOLEAN DEFAULT FALSE,
    likes_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_photos_facility ON photos (facility_id);
CREATE INDEX idx_photos_user ON photos (user_id);

-- 10. FACILITY REPORTS (Contributions)
CREATE TABLE facility_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    amenity_id UUID REFERENCES amenities(id),
    reported_value VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    points_awarded INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_facility_reports_status ON facility_reports (status);

-- 11. USER RANKINGS
CREATE TABLE user_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    
    -- Explorer Points
    explorer_points INT DEFAULT 0,
    visit_count INT DEFAULT 0,
    contribution_count INT DEFAULT 0,
    
    -- Social Points
    social_points INT DEFAULT 0,
    review_count INT DEFAULT 0,
    photo_count INT DEFAULT 0,
    likes_received INT DEFAULT 0,
    
    -- Combined (computed column)
    total_points INT GENERATED ALWAYS AS (explorer_points + social_points) STORED,
    
    -- Metadata
    current_title VARCHAR(50) DEFAULT '湯めぐり初心者',
    rank_position INT,
    
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_rankings_total ON user_rankings (total_points DESC);
CREATE INDEX idx_user_rankings_explorer ON user_rankings (explorer_points DESC);
CREATE INDEX idx_user_rankings_social ON user_rankings (social_points DESC);

-- 12. BADGES
CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name_ja VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    description_ja TEXT,
    icon_url VARCHAR(500),
    category VARCHAR(50),
    requirements JSONB
);

-- 13. USER BADGES
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, badge_id)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_reports ENABLE ROW LEVEL SECURITY;

-- Public Read Access
CREATE POLICY "Facilities are viewable by everyone" ON facilities FOR SELECT USING (true);
CREATE POLICY "Reviews are viewable by everyone" ON reviews FOR SELECT USING (true);
CREATE POLICY "Photos are viewable by everyone" ON photos FOR SELECT USING (true);
CREATE POLICY "Amenities are viewable by everyone" ON amenities FOR SELECT USING (true);
CREATE POLICY "Facility amenities are viewable by everyone" ON facility_amenities FOR SELECT USING (true);
CREATE POLICY "User rankings are viewable by everyone" ON user_rankings FOR SELECT USING (true);

-- User Write Access
CREATE POLICY "Users can read own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can create own reviews" ON reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reviews" ON reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reviews" ON reviews FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Users can upload photos" ON photos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own photos" ON photos FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Users can create visits" ON visits FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view own visits" ON visits FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create facility reports" ON facility_reports FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function: Get Facilities in Viewport
CREATE OR REPLACE FUNCTION get_facilities_in_bounds(
    min_lat DOUBLE PRECISION,
    min_lng DOUBLE PRECISION,
    max_lat DOUBLE PRECISION,
    max_lng DOUBLE PRECISION,
    filter_amenities UUID[] DEFAULT NULL,
    facility_limit INT DEFAULT 500
)
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    facility_type VARCHAR,
    data_quality_score INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.id,
        f.name,
        ST_Y(f.location::geometry) as lat,
        ST_X(f.location::geometry) as lng,
        ft.code as facility_type,
        f.data_quality_score
    FROM facilities f
    JOIN facility_types ft ON f.facility_type_id = ft.id
    LEFT JOIN facility_amenities fa ON f.id = fa.facility_id
    WHERE ST_Within(
        f.location::geometry,
        ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
    )
    AND (
        filter_amenities IS NULL 
        OR fa.amenity_id = ANY(filter_amenities)
    )
    GROUP BY f.id, f.name, f.location, ft.code, f.data_quality_score
    ORDER BY f.data_quality_score DESC
    LIMIT facility_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Update Rank Positions
CREATE OR REPLACE FUNCTION update_rank_positions()
RETURNS void AS $$
BEGIN
    WITH ranked AS (
        SELECT 
            ur.id,
            ROW_NUMBER() OVER (ORDER BY ur.total_points DESC) as new_rank
        FROM user_rankings ur
    )
    UPDATE user_rankings ur
    SET rank_position = r.new_rank
    FROM ranked r
    WHERE ur.id = r.id;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Update Rank on Points Change
CREATE OR REPLACE FUNCTION trigger_ranking_update()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM update_rank_positions();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_ranking_change
    AFTER INSERT OR UPDATE ON user_rankings
    FOR EACH STATEMENT
    EXECUTE FUNCTION trigger_ranking_update();

-- Function: Validate Review Content
CREATE OR REPLACE FUNCTION validate_review_content()
RETURNS TRIGGER AS $$
BEGIN
    -- Sanitize content: strip HTML tags
    IF NEW.content IS NOT NULL THEN
        NEW.content = regexp_replace(NEW.content, '<[^>]*>', '', 'g');
    END IF;
    
    -- Check for spam patterns (short messages with URLs)
    IF NEW.content IS NOT NULL
       AND NEW.content ~ '(http|www\.)'
       AND char_length(NEW.content) < 100 THEN
        RAISE EXCEPTION 'Potential spam detected';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_review_content
    BEFORE INSERT OR UPDATE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION validate_review_content();

-- Trigger: Auto-update updated_at on facilities
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER facilities_updated_at
    BEFORE UPDATE ON facilities
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER reviews_updated_at
    BEFORE UPDATE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
