# Knowledge: Yu-Map Error Patterns and Recovery

**Trigger:** Use when setup fails, tests fail, lint fails, build fails, migrations fail, or dependency install fails.

---

## Standard Recovery Flow

1. Capture the full error.
2. Identify the failing command.
3. Determine whether the issue is local, CI-only, or both.
4. Determine whether it is pre-existing.
5. Inspect repository config and nearby patterns.
6. Apply the smallest safe fix.
7. Re-run the most relevant check first.
8. Broaden verification after the local issue is resolved.

## Yu-Map-Specific Patterns

### Flutter Setup
- All Flutter commands run from `yu_map/`, not repo root.
- `flutter pub get` must succeed before `flutter test` or `flutter analyze`.
- If `flutter` is not available, it needs to be installed. This is an environment issue, not a repo issue.

### Supabase Query Issues
- PostgREST queries must be chained without reassignment that drops filters.
- `.contains()` is for JSONB columns. For joined tables, use `.filter()`.
- Reference: `facility_service.dart` for correct query chaining pattern.

### Entity Deserialization
- `Facility.fromJson` uses `json['lat']` and `json['lng']` (from `get_facilities_in_bounds` RPC).
- Direct table queries return `latitude` and `longitude` column names.
- Be aware of this mapping difference when working with facility data.

### Edge Function Errors
- Edge functions use Deno runtime. TypeScript errors in this workspace may be due to missing Deno environment, not actual bugs.
- Verify edge function changes against Supabase Edge Function patterns, not local TS compilation.

### Dependency Issues
- `pubspec.yaml` uses caret ranges (e.g., `^2.4.0`). Version conflicts surface during `flutter pub get`.
- Check `pubspec.yaml` for existing versions before adding dependencies.

## Three-Strike Rule

If the same blocking problem is hit 3 times:
1. Stop.
2. Summarize what was tried.
3. Explain the current likely cause.
4. Ask for direction only if needed.

## Blocker Report Format

### Problem
[plain-language summary]

### What Was Checked
[list]

### Current Likely Cause
[short explanation]

### Recommended Next Step
[short recommendation]
