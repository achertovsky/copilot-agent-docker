#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
    echo "Missing .env. Copy .env.example to .env and set PROJECT_PATH."
    exit 1
fi

export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"

exec docker compose run --rm --entrypoint /bin/bash copilot
