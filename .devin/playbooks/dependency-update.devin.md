# Playbook: Dependency Update

**Use when:** Updating, adding, or removing a Flutter/Dart dependency in `pubspec.yaml`.

---

## Prerequisites

- If adding a new external integration (new SDK, new API), get explicit approval first.
- If upgrading a major version, assess breaking change risk before proceeding.

## Steps

### 1. Check current state

- Read `yu_map/pubspec.yaml` for existing version constraints.
- Identify whether this is a patch, minor, or major version change.
- Check if other dependencies might be affected by the change.

### 2. Make the change

- Edit `yu_map/pubspec.yaml`.
- Use caret syntax (e.g., `^2.5.0`) consistent with existing entries.
- For dev dependencies, add under `dev_dependencies:`.

### 3. Resolve dependencies

- Run `flutter pub get` from `yu_map/`.
- If version conflicts occur, resolve by adjusting constraints minimally.

### 4. Check for breaking changes

- If the update is a major version bump, review the package changelog.
- Search for usage of the package across `lib/` and `test/`.
- Update any affected code to match new API.

### 5. Verify

- Run `flutter analyze` from `yu_map/`.
- Run `flutter test` from `yu_map/`.
- If the dependency is widely used (e.g., `supabase_flutter`, `flutter_riverpod`), run the full test suite.

### 6. Create PR

- Target branch: `main`.
- Follow PR summary structure from `04-pr-guidelines.md`.
- List the packages changed and their old/new versions.
- Note any code changes required by the update.

## Approval Gates

| Scenario | Requires Approval |
|---|---|
| Patch/minor update of existing dep | No |
| Major version update of existing dep | Yes, if breaking changes exist |
| Adding a new dependency | Yes, if it's a new external integration |
| Removing a dependency | Yes |

## Reference

- Current dependencies: `yu_map/pubspec.yaml`
- Dart SDK constraint: `>=3.2.0 <4.0.0`
