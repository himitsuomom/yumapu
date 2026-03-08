# Playbook: Bug Fix Triage

**Use when:** Fixing a reported bug in Yu-Map.

---

## Steps

### 1. Understand the bug

- Read the bug report or user description.
- Identify the expected vs actual behavior.
- Identify the likely affected area (entity, service, edge function, schema, UI).

### 2. Locate the root cause

- Search the relevant source files.
- Check recent changes (use `git log` for the affected files).
- Reference PR #8 (`feature/yu-map-fixes`) for examples of common bug patterns:
  - Query filter reassignment dropping filters.
  - Memory leaks from unassigned stream subscriptions.
  - Incorrect `.contains()` usage on joined tables.
  - Redundant null coalescing.
  - Encapsulation violations (direct cache access).

### 3. Reproduce if practical

- Write a test that demonstrates the failure.
- If the bug is in a service, use the mock pattern from `facility_service_test.dart`.

### 4. Fix the root cause

- Apply the smallest safe fix.
- Do not expand into unrelated refactoring.
- Preserve existing behavior outside the bug scope.

### 5. Add regression test

- Add a test that would have caught the bug.
- Confirm it fails without the fix and passes with it.

### 6. Verify

- Run `flutter analyze` from `yu_map/`.
- Run `flutter test` from `yu_map/`.

### 7. Create PR

- Target branch: `main`.
- Follow PR summary structure from `04-pr-guidelines.md`.
- Clearly explain the root cause and fix in the PR description.

## Common Bug Areas in Yu-Map

| Area | Common Issue | Reference |
|---|---|---|
| `facility_service.dart` | Query filters dropped on chaining | PR #8 |
| `subscription_service.dart` | Stream subscription not assigned | PR #8 |
| `supabase_service.dart` | `.contains()` misuse on joins | PR #8 |
| `map_clustering_service.dart` | Cache encapsulation violation | PR #8 |
| `facility.dart` | `fromJson` field mapping (`lat`/`lng` vs `latitude`/`longitude`) | Entity source |
