# Task

Describe the task, relevant context, constraints, and expected result here.

---

## Workspace

The workspace may contain multiple independent Git repositories in
subdirectories.

Treat each repository independently.

Before proposing changes:

- identify the repositories relevant to the task;
- inspect their Git status and current branch or detached HEAD state;
- determine which repositories are context-only and which require changes;
- preserve unrelated existing modifications.

Each repository or worktree may have its own `.venv`.

When executing Python code or project tools:

- use the repository's own environment;
- prefer `uv run ...` where appropriate;
- do not reuse a virtual environment from another repository or worktree;
- do not install project dependencies globally.

---

## Investigation

When the task spans multiple repositories or the implementation location is
unclear, first trace the relevant relationships across repositories.

Identify where the behaviour is defined, where it is consumed, and which
repositories are actually affected.

Base conclusions on inspected code and configuration.

Clearly distinguish confirmed findings from assumptions or uncertainties.

Do not modify tracked files during investigation.

---

## Change Workflow

1. Analyse the relevant code.

2. Explain the proposed change, including affected repositories and files.

3. Generate the complete proposed change as a unified diff.

4. Ask for explicit approval before modifying tracked files.

5. After approval, apply the approved changes and run validation without
   further approval.

For modified Python repositories, at minimum run:

```bash
uv run ruff check .
uv run ruff format --check .
```

Also run relevant project-specific tests or validation commands when appropriate.

6. If validation or further investigation requires additional tracked-file
   changes, return to step 1 and produce a new diff for approval.

Do not silently make unapproved source or configuration changes.

---

## Git Safety

Unless explicitly requested, do not:

- commit or push;
- create, delete, move, or modify branches or worktrees;
- reset, clean, or stash;
- rewrite history or force-push;
- discard or overwrite existing changes.

Preserve unrelated modifications.

