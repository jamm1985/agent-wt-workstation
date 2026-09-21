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

Exiting that outer shell stops and removes the container. Workspace files and
named volumes persist; tmux sessions end when the container stops.

The workstation is ready. Next, create a task directory with worktrees
for the repositories involved.

## Worktree workflow

Organize work around tasks. Each task gets a directory with a Git worktree for
every repository it needs. The original checkouts keep their branches and local
changes, while the task worktrees share their repositories' Git history.
The editor, agent and shell use the same files inside the container.

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
        ├── repo-1/  # feat/task-31337
        ├── repo-2/  # feat/task-31337
        └── repo-3/  # detached at origin/master
```

### Prepare the task

The examples assume existing clones with up-to-date `origin/master` refs;
use `origin/main` if appropriate. Run these commands on the host, from this
template's directory:

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

`--no-track` creates each task branch without setting `origin/master` as its
upstream. The same branch name belongs to two independent repositories.
`--detach` checks out the current `origin/master` commit without a new branch.
It does not prevent writes: treat `repo-3` as context-only.

The `WORK_ROOT=${HOME}/git` setting above mounts the whole common root so that
`--relative-paths` links remain valid between the original repositories and
worktrees when `~/git` becomes `/workspace`.

Edit the task's `AGENTS.md` to describe the goal, allow changes in `repo-1` and
`repo-2`, and mark `repo-3` as context-only. Include instructions to read each
repository's own `AGENTS.md` before working in it.

### Work inside the task

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
containing all three repositories. The task directory is not a Git repository.
Review changes per repository, then commit and push from its worktree on the
host.

Use other tmux windows for Vim, a shell and project tools. Run tools from the
relevant worktree, using its own environment. For example, in a Python 3.12
project with `uv.lock` and Ruff and pytest declared as dependencies:

```bash
cd /workspace/tasks/task-31337/repo-1
uv sync --locked --python 3.12
uv run python --version
uv run ruff check .
uv run ruff format --check .
uv run pytest
```

Repeat environment setup and validation for each Python repository you change.
Each worktree keeps its own `.venv`.

### Detached agent sessions

To keep agents running after you close the host terminal, start a container
in the background. After preparing the task, run these commands on the host
from this template's directory:

```bash
docker compose run --rm -d --name task-31337 agent sleep infinity

docker exec task-31337 tmux new-session -d -s agents -n codex \
  -c /workspace/tasks/task-31337 'codex --sandbox danger-full-access'
docker exec task-31337 tmux new-window -d -t agents -n gemini \
  -c /workspace/tasks/task-31337 'gemini'

docker exec -it task-31337 tmux attach -t agents
```

Use `Ctrl-b w` to switch windows and `Ctrl-b d` to detach. Repeat the last
command to reconnect. Agents keep running while the container is running;
stop it with `docker stop task-31337`.

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
