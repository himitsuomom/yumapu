# Knowledge: Yu-Map PR Guidelines

**Trigger:** Use when preparing work for review, summarizing completed work, or responding to review comments.

---

## Target Branch

`main`

## Branch Naming

Use the pattern: `devin/$(date +%s)-description`

For non-Devin branches, follow existing conventions:
- `feature/description`
- `fix/description`
- `chore/description`

## PR Summary Structure

Use this structure for every PR description:

### What
Describe the change clearly.

### Why
Explain the problem or goal.

### How Tested
List the checks run and their results:
- `flutter analyze` result
- `flutter test` result
- Any manual verification performed

### Risks
List behavior, rollout, or data risks in plain language.

### Rollback
Explain how to back out safely if relevant.

## Review Readiness Checklist

Before calling work complete:
- [ ] Diff stays in scope — no unrelated changes.
- [ ] `flutter analyze` passes (from `yu_map/`).
- [ ] `flutter test` passes (from `yu_map/`).
- [ ] Risks are disclosed.
- [ ] No secrets present in the diff.
- [ ] No unrelated files modified.
- [ ] PR description follows the summary structure above.

## Reference PRs

- **Bug fix pattern**: PR #8 (`feature/yu-map-fixes`) — query chaining fix, memory leak fix, contains() fix, code quality cleanup.

## Responding to Review Feedback

1. Classify the comment (scope fix, behavior change, style, question).
2. Fix safe in-scope issues directly.
3. Ask before making behavior-changing or scope-expanding changes.
4. Summarize what was changed in response.

## CI

No CI is currently configured. Run `flutter analyze` and `flutter test` locally before creating the PR.
