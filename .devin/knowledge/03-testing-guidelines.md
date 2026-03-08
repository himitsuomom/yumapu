# Knowledge: Yu-Map Testing Guidelines

**Trigger:** Use when implementing behavior changes, fixing bugs, adding endpoints, or updating dependencies.

---

## Available Commands

| Action | Command | Working directory |
|---|---|---|
| Run all tests | `flutter test` | `yu_map/` |
| Run single test | `flutter test test/<file>.dart` | `yu_map/` |
| Static analysis | `flutter analyze` | `yu_map/` |

There is no repo-wide build command established. Do not invent one.

## Test Structure

- Tests live in `yu_map/test/`, mirroring the `lib/` structure.
- Use `group()` for logical grouping, `test()` for individual cases.
- Current test: `test/facility_service_test.dart` — tests query building and caching.

## Test Patterns

### Mock Classes
- Manual mock classes implementing Supabase interfaces (e.g., `MockSupabaseClient`, `MockPostgrestClient`, `MockPostgrestFilterBuilder`).
- `mocktail` is available as a dev dependency for mock generation.
- Track method calls and filter applications via mock fields (e.g., `lastQueryHasILike`, `lastQueryHadPrefectureFilter`).

### Test Structure Example
```dart
group('ServiceName Tests', () {
  late ServiceType service;
  late MockDependency mockDep;

  setUp(() {
    mockDep = MockDependency();
    service = ServiceType(mockDep);
  });

  test('should do expected thing', () async {
    // Arrange
    // Act
    // Assert
  });
});
```

## Testing By Task Type

### Bug Fix
- Reproduce the bug scenario in a test if practical.
- Confirm the failure scenario now passes.
- Add a regression test.

### New Feature
- Cover the happy path.
- Cover key validation, auth, and failure paths.

### Refactor
- Run existing tests around the changed area.
- Add protection if the area is weakly tested.

### Dependency Update
- Run `flutter test` and `flutter analyze`.
- Test affected usage paths if the dependency is widely used.

## Verification Checklist

Before calling work complete, run:
1. `flutter analyze` (from `yu_map/`) — must pass with no errors.
2. `flutter test` (from `yu_map/`) — must pass.

If a command does not exist or cannot run, report that explicitly.

## Rules

- Tests must be deterministic, focused, and readable.
- Do not weaken assertions to make tests pass.
- Do not delete tests to make a change pass.
- Do not pretend manual checks replace feasible automation.
