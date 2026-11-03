# Task

Describe the task, relevant context, constraints, and expected result here.

---

## Task continuity

Maintain TASK.md in the task workspace for work spanning multiple steps,
sessions, or repositories. Keep independent tasks separate; skip it for
small, self-contained requests.

Start with a dated overview: goal, completion criteria, scope, constraints,
milestone status, blockers, and the next one to three actions. Keep one current
plan. Follow-up messages steer it unless the user changes the objective.
Choose each next action to advance the goal or resolve an open question.

Below the overview, retain context needed for later stages:

- Repositories and systems, their relationships, and key contracts.
- Stage results and decisions, their rationale, and scope of user approvals.
- Evidence links with check results, scope, and date or revision. Distinguish
  inspected facts, user reports, and assumptions. Record acceptance decisions
  without rewriting check results or removing unresolved limitations.

At task start and after context loss or compaction, read the overview, then
relevant stage details and evidence. Reconcile notes with current instructions
and working-tree state. Verify facts that may have changed before relying on
them; do not repeat completed checks or external actions without a reason.

Update after material findings, decisions, milestones, or blockers, and before
handing off unfinished work. Replace obsolete status and next steps; date
retained history and mark superseded plans. Preserve dependencies
and constraints from completed stages when later work relies on them.
Consolidate repetition while retaining necessary context; impose no line limit.
Move lengthy details to linked documents when useful, retaining conclusions,
limitations, and when to consult them in TASK.md. Do not log every tool call.

At completion, record the outcome and remaining limitations; retire active
next steps. Notes do not grant permissions or override instructions.
Do not store secrets.

---

## Change visibility

Show complete unified diffs for authored text and generated code/configuration,
including files outside Git. Use pre-change contents as the baseline and
/dev/null for new files; exclude unrelated edits. Present source/configuration
and agent instructions separately from supporting task documents.

Show small diffs inline; link larger, complete .diff files with a short
explanation. Do not truncate them. After each applied update, including every
TASK.md update, show or link the actual diff. If it matches the approved
proposal, reuse that diff and confirm the match.

For raw execution logs and binary outputs, report paths and results.
Diff files do not need another diff. Approval rules are in Change Workflow.

---

## Workspace

The workspace may contain multiple independent Git repositories in
subdirectories.

Treat each repository independently.

Before proposing changes:

- identify the repositories relevant to the task;
- inspect their Git status and current branch or detached HEAD state;
- read applicable repository instructions and validation configuration;
- determine which repositories are context-only and which require changes;
- preserve unrelated existing modifications.

For work across hosts or containers, identify where commands run and artifacts
live. When providing commands, specify the host or container, working directory,
and required environment if these are not already clear.

Each repository or worktree may have its own `.venv`.

When executing code or tools in Python repositories:

- use the repository's own environment;
- prefer existing environment binaries or `uv run --no-sync ...`;
- do not reuse a virtual environment from another repository or worktree;
- do not install project dependencies globally.

---

## Environment Changes

Before creating, recreating, deleting, or synchronizing any environment,
or installing, updating, or removing interpreters, dependencies, or
development tools, obtain explicit user approval.

Before asking, explain why the change is needed, identify affected paths,
and show the exact commands. A request to inspect code, run tests, or
provide setup instructions does not authorize environment changes.

This rule also applies to environments outside Git, temporary environments,
and automatic setup performed by commands such as `uv run` and `uvx`.

Without approval, use only existing environments and installed tools.
For Python, prefer environment binaries directly, or `uv run --no-sync` after
verifying that the environment, interpreter, and required tools already exist.
Do not use options that add dependencies. If setup is needed, ask before
proceeding.

For other languages, propose missing environment setup based on repository
and CI requirements: runtime or compiler, package manager, dependencies, and
development tools, with versions and installation paths. Explain choices
where requirements are unspecified. Follow the approval process above;
choose code checks using Change Workflow.

Approval to edit files or run validation does not imply approval to change
an environment. Do not ask again for environment actions explicitly approved
for the same scope.

---

## Investigation

When the task spans multiple repositories or the implementation location is
unclear, first trace the relevant relationships across repositories.

Identify where the behaviour is defined, where it is consumed, and which
repositories are actually affected.

Base conclusions on evidence suited to the claim: code and configuration for
implementation details, runtime observations for operational state, and
primary documentation for external contracts. Local code alone does not
confirm deployed behavior.

Clearly distinguish confirmed findings from assumptions or uncertainties.

Do not modify tracked files during investigation.

---

## Change Workflow

Apply this workflow to all tracked files, including documentation and TASK.md,
and to code, scripts, configuration, or agent instructions regardless of Git
status, including new files.

Untracked task notes, reports, and isolated proposals for review need no
separate approval within task scope. Prepare proposals without changing target
files; applying them follows the workflow below.

1. Analyse the relevant files.

2. Explain the proposed change and affected repositories and files.

3. Show the complete proposed diff as specified in Change visibility.

4. Obtain explicit approval unless it already covers this proposal.

5. Apply approved changes and run validation without further approval,
   except for environment changes not yet explicitly approved under
   Environment Changes.

6. If additional changes need approval, present a new proposal before applying.

Select validation from repository instructions, tool configuration, and CI.
Respect configured lint and format rules; propose rule changes separately.
Run checks required for the change and tests of affected behavior using the
existing repository environment. Do not replace required checks with a
different tool. For documentation-only changes, run documentation checks
unless the repository requires broader validation.

For Python source changes, use these defaults for checks the project does not
specify, with Ruff installed in the existing repository environment:

```bash
uv run --no-sync ruff check --no-fix .
uv run --no-sync ruff format --check .
```

Run relevant existing tests with their test runner. Report missing tools or
tests as validation gaps; environment setup follows Environment Changes.

Report results, confirmed pre-existing failures, and any checks not run with
the reason. Report applied diffs as specified in Change visibility.

---

## Git Safety

Unless explicitly requested, do not:

- commit or push;
- create, delete, move, or modify branches or worktrees;
- reset, clean, or stash;
- rewrite history or force-push;
- discard or overwrite existing changes.

Preserve unrelated modifications.

