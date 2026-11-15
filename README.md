# Notice

This is only human-written line.

# Copilot Agent in Docker

A self-contained Docker environment for running **GitHub Copilot CLI as an agent**.

The host only provides:

- Docker / Docker Compose
- the project directory you explicitly mount

Copilot, Git, GitHub CLI, Node.js, PHP, Composer, Go, Python and the other development tools run inside the container.

The project directory is the only host directory mounted into the container.

## Architecture

```text
host
 |
 +-- Docker
      |
      +-- copilot-agent container
           |
           +-- /workspace       -> your project directory
           +-- /home/agent/.copilot -> persistent Copilot state
           +-- /home/agent/.config/gh -> persistent GitHub CLI state
```

The Copilot and GitHub CLI state are Docker named volumes, so authentication and configuration survive container recreation.

## Requirements

Install:

1. Docker Engine
2. Docker Compose v2

Verify:

```bash
docker --version
docker compose version
```

You also need an active GitHub Copilot subscription. GitHub documents Copilot CLI as available with all Copilot plans, subject to organization policy where applicable.

## Installation

Clone/copy this directory somewhere convenient:

```text
copilot-agent-docker/
├── Dockerfile
├── compose.yaml
├── .env.example
├── start.sh
├── shell.sh
└── README.md
```

Make the scripts executable:

```bash
chmod +x start.sh shell.sh
```

Copy the configuration:

```bash
cp .env.example .env
```

Edit `.env`:

```dotenv
PROJECT_PATH=/home/alex/projects/my-project
```

That's the only path you normally need to configure.

The supplied `start.sh` automatically uses your current host UID/GID. This prevents normal file operations in the mounted project from producing root-owned files.

## First run

From this directory:

```bash
./start.sh
```

The first run builds the image.

You should end up inside Copilot CLI:

```text
/workspace $
```

Your project is available there.

For example:

```bash
git status
gh repo view
php --version
composer --version
go version
node --version
copilot
```

Copilot itself is already the container entrypoint, so normally you don't need to type `copilot`.

## Authenticate Copilot

For an interactive personal setup, authenticate from inside the container:

```text
/login
```

Copilot will use its device-code flow in a headless/container environment.

The authentication state is stored in the persistent `copilot-home` Docker volume.

You do not have to log in again every time the container is recreated.

## GitHub CLI authentication

If the agent needs `gh`, authenticate it inside the container:

```bash
gh auth login
```

The GitHub CLI configuration is stored in the persistent `gh-config` Docker volume.

Check it with:

```bash
gh auth status
```

Copilot CLI can also use an authenticated GitHub CLI token as a fallback when no higher-priority Copilot credential is configured.

## Non-interactive authentication

If you don't want OAuth state stored in the container, you can provide a token through `.env`:

```dotenv
COPILOT_GITHUB_TOKEN=github_pat_...
GH_TOKEN=github_pat_...
```

For Copilot, GitHub recommends a fine-grained personal access token with the **Copilot Requests** account permission for this kind of container/non-interactive environment.

Do not commit `.env`.

If you use this method, add:

```text
.env
```

to `.gitignore` if this directory itself is a Git repository.

## Running a shell instead of Copilot

Sometimes you want to inspect the environment:

```bash
./shell.sh
```

You'll get:

```text
agent@container:/workspace$
```

Everything you install manually there disappears when the container is removed unless it is written to a mounted volume.

If you need a tool permanently, add it to the `Dockerfile` and rebuild.

## Adding project-specific tools

The image intentionally contains a useful general development environment:

- Node.js 22
- npm
- Git
- GitHub CLI
- PHP CLI
- Composer
- Go
- Python 3
- GCC / G++
- curl
- jq
- ripgrep
- fd
- unzip / zip
- common shell utilities

For example, if your project needs PostgreSQL client tools, add them to the `apt-get install` list in the Dockerfile.

Then rebuild:

```bash
docker compose build --no-cache
```

## Persistent storage

There are two Docker volumes:

```text
copilot-home
gh-config
```

They contain:

```text
copilot-home
└── Copilot configuration
    ├── authentication
    ├── session/history data
    ├── settings
    ├── agents
    ├── hooks
    └── extensions

gh-config
└── GitHub CLI configuration/authentication
```

Your source code is **not** stored in these volumes.

It remains on your host at `PROJECT_PATH`.

List the volumes:

```bash
docker volume ls
```

Remove them if you deliberately want to reset authentication/configuration:

```bash
docker volume rm copilot-agent-docker_copilot-home
docker volume rm copilot-agent-docker_gh-config
```

The exact volume names can be checked with:

```bash
docker volume ls
```

## Security model

The important property of this setup is:

```text
Copilot
   |
   v
container
   |
   +-- /workspace -> explicitly mounted project
   |
   +-- container filesystem
```

Copilot can execute commands in the container, including installing packages and modifying files.

It cannot directly install software on your host.

It can modify the mounted project because that is explicitly shared with the container.

### Do NOT add this

Do not add:

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

unless you specifically want the agent to control the host Docker daemon.

That would substantially weaken the isolation.

## Docker commands from inside the agent

By default, Docker itself is deliberately unavailable inside the container.

This is intentional.

If a project needs Docker Compose for its own services, there are two choices:

### Option A — preferred

Run the project dependencies separately from this agent container.

For example:

```text
docker compose up postgres redis
```

on the host, while Copilot works against the mounted project.

### Option B — Docker-in-Docker

Add a Docker daemon/container setup explicitly if you really need the agent to create containers itself.

Do not solve this by mounting `/var/run/docker.sock` if your goal is host isolation.

## Multiple projects

You don't need another image.

Just change:

```dotenv
PROJECT_PATH=/home/alex/projects/project-a
```

to:

```dotenv
PROJECT_PATH=/home/alex/projects/project-b
```

and run:

```bash
./start.sh
```

The Copilot and GitHub CLI configuration remains persistent.

## Updating Copilot

Rebuild the image:

```bash
docker compose build --pull --no-cache
```

The Dockerfile installs the latest `@github/copilot` package at build time.

Your project and authentication volumes are unaffected.

## Completely reset everything

To remove the container/image and persistent authentication/configuration:

```bash
docker compose down
docker volume rm copilot-agent-docker_copilot-home copilot-agent-docker_gh-config
docker image rm copilot-agent:local
```

The project directory is not deleted.

## Typical workflow

```bash
cd ~/tools/copilot-agent-docker

# Set once
cp .env.example .env
$EDITOR .env

# Every time
./start.sh
```

Then just talk to Copilot:

```text
Implement the authentication feature.
Run the tests.
If dependencies are missing, install them.
Use git to inspect the existing implementation.
```

Those commands execute in the Docker environment.

## Important limitation

Docker isolates the **execution environment**, not the mounted project.

If:

```dotenv
PROJECT_PATH=/home/alex/projects/foo
```

then the container has write access to `/home/alex/projects/foo` through `/workspace`.

That is intentional: otherwise an agent couldn't actually modify your project.

For stronger isolation, mount a disposable copy/worktree of the repository instead of your primary working tree.
