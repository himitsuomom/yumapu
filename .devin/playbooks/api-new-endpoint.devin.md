# Playbook: Add a New API Endpoint (Edge Function)

**Use when:** Adding a new Supabase Edge Function or extending an existing one.

---

## Prerequisites

- Confirm the endpoint's purpose and expected behavior with the user.
- If the endpoint touches auth, permissions, or user data, get explicit approval.

## Steps

### 1. Plan the endpoint

- Identify the input parameters and expected response.
- Identify which tables are read or written.
- Identify whether RLS policies need changes (approval-gated).

### 2. Create the edge function

- Create `yu_map/supabase/functions/<name>/index.ts`.
- Follow the existing pattern from `calculate-ranking/index.ts` or `verify-contribution/index.ts`:
  - Import `serve` from Deno std.
  - Import `createClient` from Supabase JS.
  - Create client using `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` env vars.
  - Return JSON with `Content-Type: application/json`.

### 3. If a Dart service is needed

- Add or update a service in `yu_map/lib/services/`.
- Follow the constructor-injection pattern from `facility_service.dart`.
- Use incremental PostgREST query building.

### 4. If schema changes are needed

- This is approval-gated. Stop and ask.
- Follow the `db-migration.devin.md` playbook.

### 5. Add tests

- Add unit tests in `yu_map/test/` mirroring the service file path.
- Follow the mock pattern from `facility_service_test.dart`.

### 6. Verify

- Run `flutter analyze` from `yu_map/`.
- Run `flutter test` from `yu_map/`.

### 7. Create PR

- Target branch: `main`.
- Follow PR summary structure from `04-pr-guidelines.md`.
