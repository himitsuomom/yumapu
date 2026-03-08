# Knowledge: Yu-Map Continuous Improvement

**Trigger:** Use when completing larger tasks, encountering repeated confusion or failures, or when knowledge/playbooks need refinement.

---

## Update Documentation When

- The same clarification is needed more than once.
- The same failure pattern appears more than once.
- Repo commands or paths change.
- A playbook repeatedly causes avoidable back-and-forth.
- A new safety rule becomes necessary.
- New patterns are established (e.g., UI layer patterns once screens are added).

## Do Not Update For

- One-off local noise.
- Speculative process changes.
- Temporary issues with no reuse value.

## Retrospective Rule

After a complex or retry-heavy task, summarize:
- What slowed the task down.
- What was missing from the instructions.
- What should be added to knowledge files.
- What should become a reusable playbook step.

Use the template at `docs/devin-sessions/RETROSPECTIVE_TEMPLATE.md`.

## Promotion Rule

- Put repo-wide reusable facts into `.devin/knowledge/`.
- Put repeatable task procedures into `.devin/playbooks/`.
- Put top-level agent entry-point info into `AGENTS.md`.

## Yu-Map Growth Areas

As the project matures, documentation should expand to cover:
- UI layer patterns and widget conventions (once screens are added).
- State management patterns (Riverpod providers).
- Navigation and routing conventions.
- Integration test patterns.
- CI/CD pipeline configuration.
- Deployment procedures.
