# Playbook: PR Review Autofix

**Use when:** Responding to review comments on a Yu-Map PR that request code changes.

---

## Steps

### 1. Read all review comments

- Classify each comment:
  - **Safe in-scope fix**: Style, typo, small logic fix within the PR's scope.
  - **Behavior change**: Alters product behavior beyond the original PR intent.
  - **Scope expansion**: Requests work outside the original PR scope.
  - **Question/clarification**: Needs a response, not a code change.

### 2. Handle safe in-scope fixes

- Apply the fix directly.
- Do not ask for approval on obvious improvements within scope.

### 3. Handle behavior changes

- Stop and ask the user before making behavior-changing fixes.
- Summarize what the reviewer requested and what the impact would be.

### 4. Handle scope expansion

- Stop and ask the user whether to expand the PR or defer to a follow-up.
- Recommend deferring if the expansion is non-trivial.

### 5. Handle questions

- Respond to the reviewer's question directly on the PR.
- If the question reveals a real issue, fix it.

### 6. After applying fixes

- Run `flutter analyze` from `yu_map/`.
- Run `flutter test` from `yu_map/`.
- Push a new commit (do not amend or force push).
- Summarize what was changed in response to each comment.

### 7. Update PR description

- If new changes materially affect the PR scope, update the PR description.

## Rules

- Never force push to fix review comments.
- Never amend commits.
- Never delete or weaken tests in response to review feedback.
- Keep each fix in a separate commit for easy review.
