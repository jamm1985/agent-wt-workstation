# agent-wt-workstation

<!-- vim-markdown-toc GFM -->

* [Requirements](#requirements)
* [Getting started](#getting-started)
  * [1. Configure the workspace](#1-configure-the-workspace)
  * [2. Build and sign in](#2-build-and-sign-in)
  * [3. Start a session](#3-start-a-session)
* [Worktree workflow](#worktree-workflow)
  * [Prepare the task](#prepare-the-task)
  * [Work inside the task](#work-inside-the-task)
  * [Detached agent sessions](#detached-agent-sessions)
* [Updating the workstation](#updating-the-workstation)
* [Related projects](#related-projects)

<!-- vim-markdown-toc -->

A containerized terminal workstation for coding agents, Git worktrees, and
multi-repo development

Run coding agents across multiple repositories without installing the
development environment on your host. You and the agent share a container
with the editor, shell and project tools, using tmux for sessions and Git
worktrees to keep task changes separate.

The example setup uses Python and uv. The workflow applies to any language
or stack with isolated project environments; install the required tools in
the container.

| Location | Responsibilities |
| --- | --- |
| Host | Clone, fetch, manage branches and worktrees, commit and push. |
| Container | Edit code, run agents and project tools in tmux. |

## Requirements

- Docker Engine 27.0+ with a compatible Compose plugin (v2 or newer).
- Git 2.48+ on the host and in the container for `--relative-paths`.

The image targets `linux/amd64`. Host examples use a POSIX shell.
The editor, agents, tmux and language tools are installed in the container.

## Getting started

Build one workstation image and reuse it across tasks. Each run starts a
container with the same mounted workspace and persistent agent volumes.
The editor, agents, shell and tools run inside the container.

Run the setup commands on the host, from the root of a fresh copy of this
repository.

### 1. Configure the workspace

Copy the local configuration files and prepare a workspace for your
repositories:

```bash
cp env.dist .env
cp zshrc.dist .zshrc
cp tmux.conf.dist .tmux.conf
cp vimrc.dist .vimrc
cp coc-settings.json.dist .coc-settings.json

mkdir -p ~/git
```

Edit these values in `.env`, keeping the other settings:

```dotenv
COMPOSE_PROJECT_NAME=my-workstation
WORK_ROOT=${HOME}/git
DOCKER_HOST_UID=1000
DOCKER_HOST_GID=1000
```

On Linux, use the output of `id -u` and `id -g` for the UID and GID.
Choose a distinct project name for each workstation instance.

`~/git` is mounted at `/workspace`. Keep repositories and their worktrees under
this common root; for example, `~/git/repo-1` becomes `/workspace/repo-1`.

### 2. Build and sign in

```bash
docker compose build
docker compose run --rm agent codex login --device-auth
```

Follow the Codex login instructions. The `codex-auth` and `gemini-auth` volumes
store each agent's credentials and state across tasks. Compose reattaches them
when containers are recreated with the same `COMPOSE_PROJECT_NAME`.

### 3. Start a session

On the host, from this repository's directory:

```bash
docker compose run --rm agent
```

Inside the container, start tmux:

```bash
tmux new-session -A -s workstation
```

Run the editor, agents and project commands in tmux windows. Use `Ctrl-b c`
to open a window and `Ctrl-b d` to return to the container shell. Reattach
with `tmux attach -t workstation`.

In zsh, press `Ctrl-X Ctrl-E` to edit the current command in Vim.

Exiting that outer shell stops and removes the container. Workspace files and
named volumes persist; tmux sessions end when the container stops.

The workstation is ready. Next, create a task directory with worktrees
for the repositories involved.

## Worktree workflow

Organize work around tasks. Each task gets a directory with a Git worktree for
every repository it needs. The original checkouts keep their branches and local
changes, while the task worktrees share their repositories' Git history.
The editor, agent and shell use the same files inside the container.

The task directory is not a Git repository. Its `AGENTS.md` holds the goal and
working rules. For work across multiple steps, sessions or repositories, the
agent also maintains `TASK.md` with the goal, scope, current plan, decisions,
dated check results and next steps. Small, self-contained requests can skip it.

The agent updates these notes as work progresses and reads them at task start
and after context loss or compaction. Before continuing, it checks the notes
against current instructions and repository state.

For `task-31337`, use `repo-1` and `repo-2` for changes, and `repo-3` for
context:

```text
~/git/
├── repo-1/
├── repo-2/
├── repo-3/
└── tasks/
    └── task-31337/
        ├── AGENTS.md
        ├── TASK.md
        ├── repo-1/  # feat/task-31337
        ├── repo-2/  # feat/task-31337
        └── repo-3/  # detached at origin/master
```

### Prepare the task

The examples assume existing clones with up-to-date `origin/master` refs;
use `origin/main` if appropriate.

`--no-track` creates each task branch without setting `origin/master` as its
upstream. The same branch name belongs to two independent repositories.
`--detach` checks out the current `origin/master` commit without a new branch.
It does not prevent writes: treat `repo-3` as context-only.

Keep the original repositories and worktrees under `WORK_ROOT`. This makes
the `--relative-paths` links valid both on the host and under `/workspace`.

Run these commands on the host, from this template's directory:

```bash
mkdir -p ~/git/tasks/task-31337

git -C ~/git/repo-1 worktree add \
  --relative-paths \
  --no-track \
  -b feat/task-31337 \
  ~/git/tasks/task-31337/repo-1 \
  origin/master

git -C ~/git/repo-2 worktree add \
  --relative-paths \
  --no-track \
  -b feat/task-31337 \
  ~/git/tasks/task-31337/repo-2 \
  origin/master

git -C ~/git/repo-3 worktree add \
  --relative-paths \
  --detach \
  ~/git/tasks/task-31337/repo-3 \
  origin/master

cp -n AGENTS-dist.md ~/git/tasks/task-31337/AGENTS.md
```

Edit the task's `AGENTS.md` to describe the goal, allow changes in `repo-1` and
`repo-2`, and mark `repo-3` as context-only. Include instructions to read each
repository's own `AGENTS.md` before working in it.

### Work inside the task

The [task instructions](AGENTS-dist.md) require the agent to show a complete
diff and get your approval before editing project files. Existing approval
for the same changes still applies. After editing, it reports the applied
diff and check results. Untracked task notes need no separate approval, but
their diffs are shown too.

Start a container from this template's directory on the host:

```bash
docker compose run --rm agent
```

Inside the container, start tmux:

```bash
tmux new-session -A -s workstation
```

In a tmux window, open the task:

```bash
cd /workspace/tasks/task-31337
codex --sandbox danger-full-access
```

The agent has write access to the mounted workspace.

Starting here loads the task's `AGENTS.md` and gives the agent one directory
containing all three repositories. Review changes per repository, then commit
and push from its worktree on the host.

Use other tmux windows for Vim, a shell and project tools. Run tools from the
relevant worktree, using its own environment. Choose checks from the
repository's instructions and CI configuration.

Environment setup needs separate approval. Before creating or syncing an
environment or installing tools, the agent must explain why, show the commands
and affected paths, and get your approval.

For a Python 3.12 project with `uv.lock`, Ruff and pytest declared as
dependencies, prepare the environment yourself or approve the agent running:

```bash
cd /workspace/tasks/task-31337/repo-1
uv sync --locked --python 3.12
```

Once the environment, interpreter and tools are available, run the checks
from the same worktree without syncing the environment:

```bash
uv run --no-sync python --version
uv run --no-sync ruff check --no-fix .
uv run --no-sync ruff format --check .
uv run --no-sync pytest
```

Each worktree keeps its own `.venv`. Repeat setup only where needed and run
the required checks for each repository you change.

### Detached agent sessions

Run tmux as the container's main process so sessions stay alive after you
disconnect. After preparing the task, run these commands on the host from
this template's directory:

```bash
docker compose run --rm -d --name task-31337 agent tmux -D

docker exec -it task-31337 tmux new -A -s agents_threads \
  -c /workspace/tasks/task-31337
```

Inside tmux, run `codex --sandbox danger-full-access` or `gemini`. Use
`Ctrl-b c` to create windows, `Ctrl-b w` to switch and `Ctrl-b d` to detach.

Reconnect from the host:

```bash
docker exec -it task-31337 tmux attach -t agents_threads
```

Stop the container with `docker stop task-31337`.

## Updating the workstation

Merge the relevant `*.dist` changes into your local configuration files,
preserving your settings. Changes to `.zshrc`, `.tmux.conf`, `.vimrc` or
`.coc-settings.json` require rebuilding the image and starting a new container.

Stop the old container, then run on the host from this repository's directory:

```bash
docker compose build
docker compose run --rm agent
```

In a tmux window inside the new container, resume Codex from your task
directory:

```bash
cd /workspace/tasks/task-31337
codex --sandbox danger-full-access resume
```

Update each task's `AGENTS.md` separately from `AGENTS-dist.md`, preserving
its goal and scope.

## Related projects

These projects take different approaches to separating agent work from a
personal machine. The approaches can be combined.

- **Development environments.** [Dev Containers][devcontainers] describe a
  reusable container environment. With VS Code, the editor UI stays on the
  host while terminals and project tools run in the container. Other editors
  and the Dev Container CLI also support the format.
- **An isolated agent session.** [yolobox][yolobox] runs coding agents and
  tools in a container; [Docker Sandboxes][docker-sandboxes] uses microVMs
  with their own Docker daemon. You interact with the agent in that
  environment and choose which host files to share.
- **Environments controlled through an API.** [OpenSandbox][opensandbox]
  and [E2B][e2b] let a program create sandboxes, manage files and execute
  commands through an SDK. The controller can run on the host or a server.
  OpenSandbox supports Docker and Kubernetes; E2B provides Linux VMs.
- **Restricted host processes.** [Anthropic Sandbox Runtime][srt] applies
  filesystem and network rules to processes running on the host. It uses
  existing host tools, without providing a separate development image.

This template puts the human and agent in the same container: editor,
shell and project tools share tmux sessions and a workspace with multiple
repositories and worktrees. Commands run directly in that environment.

Containers and VMs provide different isolation boundaries. In either case,
shared files, supplied credentials and allowed network access determine
what the agent can reach.

For broader collections, see [awesome-AI-sandbox][awesome-ai-sandbox] and
[awesome-agent-sandboxes][awesome-agent-sandboxes].

[devcontainers]: https://containers.dev/supporting
[yolobox]: https://yolobox.dev
[docker-sandboxes]: https://docs.docker.com/ai/sandboxes/
[opensandbox]: https://github.com/opensandbox-group/OpenSandbox
[e2b]: https://docs.e2b.dev/
[srt]: https://github.com/anthropics/sandbox-runtime
[awesome-ai-sandbox]: https://github.com/webcoyote/awesome-AI-sandbox
[awesome-agent-sandboxes]: https://github.com/dloss/awesome-agent-sandboxes
