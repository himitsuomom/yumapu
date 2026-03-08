# Knowledge: Yu-Map Coding Standards

**Trigger:** Use when creating or editing code, naming files/functions, or structuring changes.

---

## Core Principles

- Follow existing repository patterns before inventing new ones.
- Keep changes minimal and review-friendly.
- Prefer explicitness over cleverness.
- Preserve local consistency with nearby code.
- Do not add speculative abstractions.

## Dart / Flutter Conventions

### Entities (`yu_map/lib/domain/entities/`)
- Extend `Equatable`.
- Use `const` constructors.
- Include `fromJson(Map<String, dynamic>)` factory constructor.
- JSON keys use snake_case (matching Supabase column names).
- List relevant fields in `props` for equality.
- No Flutter or data-layer dependencies in entity files.

### Services (`yu_map/lib/services/`)
- Constructor-inject `SupabaseClient` (or other dependencies).
- Use private `_cache` fields with public unmodifiable getters (`Map.unmodifiable`).
- Build PostgREST queries incrementally using `var query = ...` then chaining `.eq()`, `.ilike()`, `.contains()` etc.
- Do not reassign queries in a way that drops previously applied filters.

### General Dart
- Imports at the top of files, never nested.
- Prefer `final` for local variables.
- Use named parameters with `required` where appropriate.
- Follow `flutter_lints` rules (configured in `pubspec.yaml`).

## TypeScript / Deno (Edge Functions)

- Located at `yu_map/supabase/functions/<name>/index.ts`.
- Use `serve()` from Deno std library.
- Create Supabase client using env vars `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- Return JSON responses with `Content-Type: application/json`.

## SQL (Migrations)

- Located at `yu_map/supabase/migrations/`.
- File naming: `YYYYMMDDHHMMSS_description.sql`.
- All tables use UUID primary keys (`gen_random_uuid()`).
- Enable RLS on all tables.
- Use PostGIS `GEOGRAPHY(POINT, 4326)` for location data.
- JSONB for flexible structured data (business_hours, price_info, amenities).
- Include appropriate indexes.

## Naming

| Area | Convention | Example |
|---|---|---|
| Dart files | snake_case | `facility_service.dart` |
| Dart classes | PascalCase | `FacilityService` |
| Dart fields | camelCase | `explorerPoints` |
| JSON keys | snake_case | `explorer_points` |
| SQL tables | snake_case | `facility_amenities` |
| SQL columns | snake_case | `confidence_score` |
| Edge functions | kebab-case dirs | `calculate-ranking/` |
| Branches | prefix/description | `feature/map-display`, `fix/query-chain` |
| Migrations | timestamp_description | `20240209000000_initial_schema.sql` |

## Error Handling

- Preserve useful error context.
- Follow existing patterns (e.g., `try/catch` returning `false` in `isPremiumUser`).
- Do not expose secrets or internal details in error messages.
- Use `debugPrint()` for development logging in Flutter, not `print()`.

## Comments

- Explain *why*, not *what*.
- Document business rules, edge cases, and workarounds.
- Do not add comments that repeat the code.

## Refactor Rule

If the task is not explicitly a refactor, only refactor what is necessary to complete the change safely.
