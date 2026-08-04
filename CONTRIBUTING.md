# Contributing to Fusion Pro V5

## Branch Policy

- Protect the primary branch from direct development work.
- Create one focused branch per approved task or Sprint scope.
- Use descriptive branch names such as `docs/repository-workflow` or `sprint4/contract-review`.
- Do not combine unrelated changes in one branch.
- Do not begin work for an unapproved Sprint.

## Commit Message Format

Use the following format:

```text
<type>(<scope>): <summary>
```

Common types are `docs`, `build`, `test`, `chore`, `fix`, and `feat`. The scope should identify the affected Sprint or repository area. Keep each commit limited to one coherent change.

Example:

```text
docs(repository): add contribution workflow
```

## Development Workflow

1. Confirm the authoritative baseline and approved task scope.
2. Update the local primary branch without rewriting shared history.
3. Create a focused working branch.
4. Make only the authorized changes.
5. Review the complete diff and repository status.
6. Collect the verification evidence required by the approved task.
7. Submit the branch for review without unrelated generated artifacts.

## Review Workflow

- Reviewers verify scope, ownership boundaries, behavioral impact, and supplied evidence.
- Requested changes remain on the same branch unless the review scope changes materially.
- Approval is required before merge.
- The primary branch must remain traceable to an authorized baseline.
- Releases and Sprint transitions require explicit project authorization.

