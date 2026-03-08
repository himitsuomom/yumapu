# Playbook: Database Migration

**Use when:** Adding or modifying database tables, columns, indexes, RLS policies, or PostgreSQL functions.

**Approval gate:** ALL schema changes require explicit user approval before implementation.

---

## Steps

### 1. Confirm approval

- Summarize the proposed schema change in plain language.
- Explain what tables/columns/policies are affected.
- Explain the risk (data loss, breaking changes, etc.).
- Wait for explicit approval before proceeding.

### 2. Create the migration file

- Location: `yu_map/supabase/migrations/`.
- Naming: `YYYYMMDDHHMMSS_description.sql` (e.g., `20240315120000_add_favorites_table.sql`).
- Reference: `20240209000000_initial_schema.sql` for conventions.

### 3. Follow schema conventions

- UUID primary keys: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
- Timestamps: `created_at TIMESTAMPTZ DEFAULT NOW()`.
- Location data: `GEOGRAPHY(POINT, 4326)`.
- JSONB for flexible structured data.
- Foreign keys with `ON DELETE CASCADE` where appropriate.
- Enable RLS: `ALTER TABLE <name> ENABLE ROW LEVEL SECURITY;`.
- Add appropriate indexes.

### 4. Add RLS policies

- Public SELECT for generally readable data.
- User-scoped writes using `auth.uid() = user_id`.
- Follow existing policy naming: `"Description of policy" ON table FOR action`.

### 5. If adding PostgreSQL functions

- Use `CREATE OR REPLACE FUNCTION`.
- Use `plpgsql` language.
- Follow existing function patterns from `initial_schema.sql`.

### 6. Update Dart entities if needed

- Add or update entity in `yu_map/lib/domain/entities/`.
- Update `fromJson` factory to handle new columns.
- Update `props` list for Equatable.

### 7. Update services if needed

- Update query `select()` calls to include new columns.
- Follow incremental query building pattern.

### 8. Verify

- Run `flutter analyze` from `yu_map/`.
- Run `flutter test` from `yu_map/`.
- Confirm migration SQL is syntactically valid.

### 9. Create PR

- Target branch: `main`.
- Clearly document the schema change in the PR description.
- Include rollback instructions (e.g., `DROP TABLE`, `ALTER TABLE DROP COLUMN`).

## Safety Rules

- Never drop tables or columns without explicit approval.
- Never weaken RLS policies without explicit approval.
- Never modify `total_points` GENERATED column logic without approval.
- Always include rollback path in PR description.
